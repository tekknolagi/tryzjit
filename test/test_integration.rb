require 'minitest/autorun'
require 'net/http'
require 'json'

DEFAULT_CODE = <<~RUBY
  def one
    1
  end

  def two
    2
  end

  def test
    one + two
  end

  30.times do
    test
  end
RUBY

class TestIntegration < Minitest::Test
  def setup
    @server_pid = spawn('ruby', 'website/server.rb', out: '/dev/null', err: '/dev/null')
    # Experimentally, 100 milliseconds seems to be enough to spin up
    sleep 0.1
  end

  def teardown
    Process.kill('INT', @server_pid)
    Process.wait(@server_pid)
  end

  def test_server_serves_index
    response = Net::HTTP.get_response(URI('http://localhost:8081/'))
    assert_equal '200', response.code
    assert_match(/html/, response['content-type'])
  end

  def test_server_executes_ruby_code
    uri = URI('http://localhost:8081/execute')
    response = Net::HTTP.post(uri, DEFAULT_CODE, { 'Content-Type' => 'text/plain' })
    assert_equal '200', response.code

    body = JSON.parse(response.body)
    assert body.key?('version')
    assert_equal body.dig('version'), 1 
    assert body.key?('functions')
    # `DEFAULT_CODE` should return a function in its JSON output
    assert body.dig('functions').length > 0
  end

  def test_server_returns_404_for_missing_file
    response = Net::HTTP.get_response(URI('http://localhost:8081/nonexistent.html'))
    assert_equal '404', response.code
  end
end
