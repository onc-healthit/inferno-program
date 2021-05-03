# frozen_string_literal: true

require File.expand_path '../test_helper.rb', __dir__

class LoggedRestClientTest < MiniTest::Test

  def setup
    WebMock.reset!
    Inferno::LoggedRestClient.clear_log
  end

  def url
    'http://www.example.com/stuff'
  end

  def last_logged_request
    Inferno::LoggedRestClient.requests.last
  end

  def test_logged_rest_client_get_correct_fields
    stub_request(:get, url)
      .to_return(status: 200, headers: {hi: 'there'}, body: 'BODY')

    response = Inferno::LoggedRestClient.get(url)

    assert last_logged_request[:direction] == :outbound
    assert last_logged_request.dig(:request, :url) == url
    assert last_logged_request.dig(:request, :method) == :get
    assert last_logged_request.dig(:response, :code) == 200
    assert last_logged_request.dig(:response, :body) == 'BODY'
    assert last_logged_request.dig(:response, :headers, :hi) == 'there'

  end

  def test_logged_rest_client_get_ok
    stub_request(:get, url)
      .to_return(status: 200)

    response = Inferno::LoggedRestClient.get(url)

    assert response.code == 200
  end

  def test_logged_rest_client_get_created
    stub_request(:get, url)
      .to_return(status: 201)

    response = Inferno::LoggedRestClient.get(url)
    assert response.code == 201
  end

  def test_logged_rest_client_get_not_found
    stub_request(:get, url)
      .to_return(status: 404)

    response = Inferno::LoggedRestClient.get(url)
    assert response.code == 404
  end

  def test_logged_rest_client_get_bad
    stub_request(:get, url)
      .to_return(status: 400)

    response = Inferno::LoggedRestClient.get(url)
    assert response.code == 400
  end

  def test_logged_rest_client_post_ok
    stub_request(:post, url)
      .to_return(status: 200)

    response = Inferno::LoggedRestClient.post(url, nil)
    assert response.code == 200
  end

  def test_logged_rest_client_post_created
    stub_request(:post, url)
      .to_return(status: 201)

    response = Inferno::LoggedRestClient.post(url, nil)
    assert response.code == 201
  end

  def test_logged_rest_client_post_not_found
    stub_request(:post, url)
      .to_return(status: 404)

    response = Inferno::LoggedRestClient.post(url, nil)
    assert response.code == 404
  end

  def test_logged_rest_client_post_bad
    stub_request(:post, url)
      .to_return(status: 400)

    response = Inferno::LoggedRestClient.post(url, nil)
    assert response.code == 400
  end

  def test_logged_rest_client_clears_log
    stub_request(:get, url)
      .to_return(status: 200)

    response = Inferno::LoggedRestClient.get(url)

    Inferno::LoggedRestClient.requests.length == 1
    Inferno::LoggedRestClient.clear_log
    assert Inferno::LoggedRestClient.requests.empty?
  end

  def test_logged_rest_client_post_body_form
    stub_request(:post, url)
      .to_return(status: 200)

    response = Inferno::LoggedRestClient.post(url, {body: 'something'}, {'Content-Type' => 'application/x-www-form-urlencoded'})
    assert response.code == 200
    assert last_logged_request.dig(:request, :payload) == 'body=something'
    assert last_logged_request.dig(:request, :headers, 'Content-Type') == 'application/x-www-form-urlencoded'
  end

  def test_logged_rest_client_post_body_json
    stub_request(:post, url)
      .to_return(status: 200)
    
    body = {key: 'value'}

    response = Inferno::LoggedRestClient.post(url, body.to_json, {'Content-Type' => 'application/json'})
    assert response.code == 200
    assert last_logged_request.dig(:request, :payload) == body.to_json
  end

  def test_logged_rest_client_post_body_default_to_json
    stub_request(:post, url)
      .to_return(status: 200)
    
    body = {key: 'value'}

    response = Inferno::LoggedRestClient.post(url, body.to_json)
    assert response.code == 200
    assert last_logged_request.dig(:request, :payload) == body.to_json
  end

end
