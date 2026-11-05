#!/usr/bin/env ruby
# frozen_string_literal: true

require 'socket'
require 'json'
require 'tmpdir'
require 'fileutils'
require 'open3'

STATIC_DIR = File.join(__dir__)
RAILS_BOOT = File.join(__dir__, 'rails_boot.rb')
RAILS_GEMFILE = File.expand_path('../rails/Gemfile', __dir__)
RAILS_FRAMEWORK = %r{/((?:action|active)\w+|railties)/lib/}
# A Rails snippet compiles hundreds of framework methods; cap what we send.
MAX_RESPONSE_BYTES = 15 * 1024 * 1024

# "where@/app/rails/activerecord/lib/..." -> "where@activerecord/lib/..."
def short_name(name)
  name.sub(%r{@[^@]*?#{RAILS_FRAMEWORK}}) { "@#{$1}/lib/" }.sub(%r{@[^@]*/gems/}, '@')
end

def handle_execute(body)
  timestamp = (Time.now.to_f * 1_000_000_000).to_i
  file_name = "#{timestamp}_#{Process.pid}.rb"
  file_path = File.join("/tmp", file_name)

  parsed = JSON.parse(body)
  code = parsed['code']
  call_threshold = parsed['callThreshold'] || 2
  rails = parsed['rails'] == true

  puts "Writing body of request to #{file_path}"
  File.open(file_path, "w") do |file|
    file.puts(code)
  end

  # On /rails, boot Rails with ZJIT off; rails_boot.rb enables it afterwards.
  rails_args = rails ? ["--zjit-disable", "-r", RAILS_BOOT] : []
  rails_env = rails ? { 'BUNDLE_GEMFILE' => RAILS_GEMFILE } : {}
  raise "Rails is not set up; run rails/setup.sh" if rails && !Dir.exist?(File.join(File.dirname(RAILS_GEMFILE), 'src'))
  stdout_and_stderr_s, status = Open3.capture2e(
    rails_env,
    "ruby",
    "--zjit",
    "--zjit-call-threshold=#{call_threshold}",
    "--zjit-dump-hir-iongraph",
    *rails_args,
    file_path
  )

  if status.exitstatus != 0
    puts "Failed compile of #{file_path}, bailing"
    raise stdout_and_stderr_s
  end

  output_dir = "/tmp/zjit-iongraph-#{status.pid}"

  if !Dir.exist?(output_dir)
    raise "No output directory found"
  end

  functions = []

  Dir.foreach(output_dir) do |entry|
    next if entry == '.' || entry == '..'
    file_path = File.join(output_dir, entry)
    functions << File.read(file_path)
  end

  functions.map! { |f| JSON.parse(f) }
  # Sort user-defined functions first, then Rails; builtins and gem functions last
  functions.sort_by! do |func|
    name = func['name'] || ''
    name.include?(file_name) ? 0 : name.match?(RAILS_FRAMEWORK) ? 1 : 2
  end

  if rails
    functions.each { |func| func['name'] = short_name(func['name'] || '') }
    bytes = 0
    functions = functions.take_while.with_index do |func, i|
      bytes += JSON.generate(func).bytesize
      i.zero? || bytes <= MAX_RESPONSE_BYTES
    end
  end

  puts "Found #{output_dir} with #{functions.length} function(s)"

  result = {
    functions: functions,
    version: 1
  }

  puts "Cleaning up #{output_dir}, #{file_path}"
  FileUtils.rm_rf(output_dir)
  FileUtils.rm_rf(file_path)

  [200, { 'Content-Type' => 'application/json' }, JSON.generate(result)]
rescue => e
  [500, { 'Content-Type' => 'application/json' }, JSON.generate({ error: e.message })]
end

def serve_static_file(path)
  path = { '/' => 'index.html', '/rails' => 'rails.html' }.fetch(path, path)
  file_path = File.join(STATIC_DIR, path)

  return [404, { 'Content-Type' => 'text/plain' }, 'Not Found'] unless File.exist?(file_path)

  content = File.read(file_path)
  content_type = case File.extname(file_path)
  when '.html' then 'text/html'
  when '.js' then 'application/javascript'
  when '.css' then 'text/css'
  when '.json' then 'application/json'
  else 'application/octet-stream'
  end

  [200, { 'Content-Type' => content_type }, content]
rescue => e
  [500, { 'Content-Type' => 'text/plain' }, "Error: #{e.message}"]
end

def handle_request(request_line, headers, body)
  method, path, _ = request_line.split(' ')

  path = path.split('?').first

  if method == 'POST' && path == '/execute'
    handle_execute(body)
  elsif method == 'GET'
    serve_static_file(path)
  else
    [405, { 'Content-Type' => 'text/plain' }, 'Method Not Allowed']
  end
end

$shutdown = false
server = TCPServer.new('0.0.0.0', 8081)
puts "Listening on http://0.0.0.0:8081"

trap('INT') do
  puts "\nShutting down..."
  $shutdown = true
end

loop do
  break if $shutdown

  readable, = IO.select([server], nil, nil, 1)
  next unless readable

  client = server.accept

  Thread.new(client) do |conn|
    begin
      request_line = conn.gets
      next unless request_line

      headers = {}
      while (line = conn.gets) && line.strip != ''
        key, value = line.split(':', 2)
        headers[key.strip] = value.strip if key && value
      end

      headers = headers.transform_keys(&:downcase)

      body = ''
      if headers['content-length']
        body = conn.read(headers['content-length'].to_i)
      end

      status, response_headers, response_body = handle_request(request_line, headers, body)

      conn.print "HTTP/1.1 #{status} OK\r\n"
      response_headers.each do |key, value|
        conn.print "#{key}: #{value}\r\n"
      end
      conn.print "content-length: #{response_body.bytesize}\r\n"
      conn.print "\r\n"
      conn.print response_body
    rescue => e
      puts "Error handling request: #{e.message}"
      begin
        conn.print "HTTP/1.1 500 Internal Server Error\r\n\r\n#{e.message}"
      rescue
      end
    ensure
      conn.close
    end
  end
end
