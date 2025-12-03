#!/usr/bin/env ruby
# frozen_string_literal: true

require 'webrick'
require 'json'

class TryZJITServer < WEBrick::HTTPServlet::AbstractServlet
  def do_POST(request, response)
    return unless request.path == '/execute'

    code = request.body

    timestamp = (Time.now.to_f * 1_000_000_000).to_i
    file_name = "#{timestamp}_#{Process.pid}.rb"
    file_path = File.join(Dir.tmpdir, file_name)

    File.write(file_path, code)

    pid = spawn(
      'ruby',
      '--zjit',
      '--zjit-call-threshold=2',
      '--zjit-dump-hir-iongraph',
      file_path
    )
    Process.wait(pid)

    output_dir = "/tmp/zjit-iongraph-#{pid}"
    functions = []

    if Dir.exist?(output_dir)
      Dir.foreach(output_dir) do |entry|
        next if entry == '.' || entry == '..'
        file_path = File.join(output_dir, entry)
        functions << File.read(file_path)
      end
    end

    result = {
      functions: functions.map { |f| JSON.parse(f) },
      version: 1
    }

    response.status = 200
    response['Content-Type'] = 'application/json'
    response.body = JSON.generate(result)
  rescue => e
    response.status = 500
    response['Content-Type'] = 'application/json'
    response.body = JSON.generate({ error: e.message })
  end
end

server = WEBrick::HTTPServer.new(
  Port: 3150,
  DocumentRoot: File.join(__dir__, 'static')
)

server.mount('/execute', TryZJITServer)

trap('INT') { server.shutdown }

puts "Listening on http://127.0.0.1:3000"
server.start
