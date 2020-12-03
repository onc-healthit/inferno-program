# frozen_string_literal: true

require_relative '../../../../test/test_helper'

describe Inferno::Sequence::OncTokenRefreshSequence do
  let(:full_body) do
    {
      'access_token' => 'abc',
      'expires_in' => 300,
      'token_type' => 'Bearer',
      'scope' => 'jkl'
    }
  end

  before do
    @sequence_class = Inferno::Sequence::OncTokenRefreshSequence
    @token_endpoint = 'http://www.example.com/token'
    @client = FHIR::Client.new('http://www.example.com/fhir')
    @instance = Inferno::Models::TestingInstance.create(
      oauth_token_endpoint: @token_endpoint,
      scopes: 'jkl',
      refresh_token: 'abc',
      received_scopes: 'jkl'
    )
    @instance.instance_variable_set(:'@module', OpenStruct.new(fhir_version: 'r4'))
    @sequence = @sequence_class.new(@instance, @client)
    @sequence.instance_variable_set(:@params, 'abc' => 'def')
  end

  describe 'invalid refresh token test' do
    before do
      @test = @sequence_class[:invalid_refresh_token]
    end

    it 'fails when the token refresh response has a success status' do
      stub_request(:post, @token_endpoint)
        .with(body: hash_including(refresh_token: @sequence_class::INVALID_REFRESH_TOKEN))
        .to_return(status: 200)

      assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }
      exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

      assert_equal 'Bad response code: expected 400 or 401, but found 200', exception.message
    end

    it 'succeeds when the token refresh response has an error status' do
      stub_request(:post, @token_endpoint)
        .with(body: hash_including(refresh_token: @sequence_class::INVALID_REFRESH_TOKEN))
        .to_return(status: 400)

      @sequence.run_test(@test)
    end
  end

  describe 'valid client id test' do
    before do
      @test = @sequence_class[:invalid_client_id]
      @client_secret = 'SECRET'
      @instance.client_secret = @client_secret
      @instance.confidential_client = true
      @auth_header = {
        'Authorization': @sequence.encoded_secret(@sequence_class::INVALID_CLIENT_ID, @client_secret)
      }
    end

    it 'omits when the using a public client' do
      @instance.confidential_client = false

      exception = assert_raises(Inferno::OmitException) { @sequence.run_test(@test) }

      assert_equal 'This test is only applicable to confidential clients.', exception.message
    end

    it 'fails when the token refresh response has a success status' do
      stub_request(:post, @token_endpoint)
        .with(headers: @auth_header)
        .to_return(status: 200)

      exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

      assert_equal 'Bad response code: expected 400 or 401, but found 200', exception.message
    end

    it 'succeeds when the token refresh has an error status' do
      stub_request(:post, @token_endpoint)
        .with(headers: @auth_header)
        .to_return(status: 400)

      @sequence.run_test(@test)
    end
  end

  describe 'refresh with scope parameter test' do
    before do
      @test = @sequence_class[:refresh_with_scope]
    end

    it 'skips if no refresh token has been received' do
      @instance.update(refresh_token: nil)
      exception = assert_raises(Inferno::SkipException) { @sequence.run_test(@test) }

      assert_equal 'No refresh token was received during the SMART launch', exception.message
    end

    it 'succeeds when the token refresh succeeds' do
      stub_request(:post, @token_endpoint)
        .with(body: hash_including(scope: 'jkl'))
        .to_return(status: 200, body: full_body.to_json, headers: {})

      @sequence.run_test(@test)
    end

    it 'fails when the token refresh fails' do
      stub_request(:post, @token_endpoint)
        .with(body: hash_including(scope: 'jkl'))
        .to_return(status: 400)

      exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

      assert_equal 'Bad response code: expected 200, 201, but found 400. ', exception.message
    end
  end

  describe 'refresh without scope parameter test' do
    before do
      @test = @sequence_class[:refresh_without_scope]
    end

    it 'skips if no refresh token has been received' do
      @instance.update(refresh_token: nil)
      exception = assert_raises(Inferno::SkipException) { @sequence.run_test(@test) }

      assert_equal 'No refresh token was received during the SMART launch', exception.message
    end

    it 'succeeds when the token refresh succeeds' do
      stub_request(:post, @token_endpoint)
        .with { |request| !request.body.include? 'scope' }
        .to_return(status: 200, body: full_body.to_json, headers: {})

      @sequence.run_test(@test)
    end

    it 'fails when the token refresh fails' do
      stub_request(:post, @token_endpoint)
        .with { |request| !request.body.include? 'scope' }
        .to_return(status: 400)

      exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

      assert_equal 'Bad response code: expected 200, 201, but found 400. ', exception.message
    end
  end

  describe '#validate_and_save_refresh_response' do
    let(:successful_response) do
      OpenStruct.new(
        code: 200,
        body: full_body.to_json,
        headers: {}
      )
    end

    it 'skips if no refresh token has been received' do
      exception = assert_raises(Inferno::SkipException) { @sequence.validate_and_save_refresh_response(nil) }

      assert_equal @sequence.no_token_response_message, exception.message
    end

    it 'fails when the token response body is invalid json' do
      response = OpenStruct.new(code: 200, body: '{')
      exception = assert_raises(Inferno::AssertionException) { @sequence.validate_and_save_refresh_response(response) }
      assert_equal('Invalid JSON. ', exception.message)
    end

    it 'fails when the token response does not contain an access token' do
      response = OpenStruct.new(code: 200, body: '{"not_access_token":"abc"}')
      exception = assert_raises(Inferno::AssertionException) { @sequence.validate_and_save_refresh_response(response) }
      assert_equal('Token response did not contain access_token as required', exception.message)
    end

    it 'fails when the token response does not contain a required field' do
      required_fields = ['token_type', 'scope', 'expires_in']
      required_fields.each do |field|
        body = full_body.reject { |key, _| key == field }.to_json
        response = OpenStruct.new(code: 200, body: body)
        exception = assert_raises(Inferno::AssertionException) { @sequence.validate_and_save_refresh_response(response) }
        assert_equal("Token response did not contain #{field} as required", exception.message)
      end
    end

    it 'fails when the token_type is not "Bearer"' do
      full_body['token_type'] = 'ghi'
      response = OpenStruct.new(code: 200, body: full_body.to_json)
      exception = assert_raises(Inferno::AssertionException) { @sequence.validate_and_save_refresh_response(response) }
      assert_equal('Token type must be Bearer.', exception.message)
    end

    it 'creates a warning when scopes are missing' do
      @instance.scopes = 'jkl mno'
      @sequence.validate_and_save_refresh_response(successful_response)

      warnings = @sequence.instance_variable_get(:'@test_warnings')
      assert_includes(warnings, 'Token exchange response did not include all requested scopes.  These may have been denied by user: ["mno"]')
    end

    it 'creates a warning when the body has no patient field' do
      @sequence.validate_and_save_refresh_response(successful_response)

      warnings = @sequence.instance_variable_get(:'@test_warnings')
      assert_includes(warnings, 'No patient id provided in token exchange.')
    end

    it 'creates a warning when the cache_control header is missing' do
      @sequence.validate_and_save_refresh_response(successful_response)

      warnings = @sequence.instance_variable_get(:'@test_warnings')
      assert_includes(warnings, 'Token response headers did not contain cache_control as is required in the SMART App Launch Guide.')
    end

    it 'creates a warning when the pragma header is missing' do
      successful_response.headers = { cache_control: 'abc' }
      @sequence.validate_and_save_refresh_response(successful_response)

      warnings = @sequence.instance_variable_get(:'@test_warnings')
      assert_includes(warnings, 'Token response headers did not contain pragma as is required in the SMART App Launch Guide.')
    end

    it 'creates a warning when the cache_control header is not set to "no-store"' do
      successful_response.headers = { cache_control: 'abc', pragma: 'def' }
      @sequence.validate_and_save_refresh_response(successful_response)

      warnings = @sequence.instance_variable_get(:'@test_warnings')
      assert_includes(warnings, 'Token response header must have cache_control containing no-store.')
    end

    it 'creates a warning when the pragma header is not set to "no-cache"' do
      successful_response.headers = { cache_control: 'no-store', pragma: 'def' }
      @sequence.validate_and_save_refresh_response(successful_response)

      warnings = @sequence.instance_variable_get(:'@test_warnings')
      assert_includes(warnings, 'Token response header must have pragma containing no-cache.')
    end
  end
end

class OncTokenRefreshSequenceTest < MiniTest::Test
  def setup
    @refresh_token = 'REFRESH_TOKEN'
    @instance = Inferno::Models::TestingInstance.create(
      url: 'http://www.example.com',
      client_name: 'Inferno',
      base_url: 'http://localhost:4567',
      client_endpoint_key: Inferno::SecureRandomBase62.generate(32),
      client_id: SecureRandom.uuid,
      oauth_authorize_endpoint: 'http://oauth_reg.example.com/authorize',
      oauth_token_endpoint: 'http://oauth_reg.example.com/token',
      initiate_login_uri: 'http://localhost:4567/launch',
      redirect_uris: 'http://localhost:4567/redirect',
      scopes: 'launch/patient online_access openid profile launch user/*.* patient/*.*',
      refresh_token: @refresh_token,
      received_scopes: 'launch/patient online_access openid profile launch user/*.* patient/*.*'
    )
    @instance.instance_variable_set(:'@module', OpenStruct.new(fhir_version: 'r4'))

    client = FHIR::Client.new(@instance.url)
    client.default_json
    @sequence = Inferno::Sequence::OncTokenRefreshSequence.new(@instance, client, true)
    @sequence.instance_variable_set(:@params, 'abc' => 'def')
    @standalone_token_exchange = load_json_fixture(:standalone_token_exchange)
    @confidential_client_secret = SecureRandom.uuid
  end

  def setup_mocks(failure_mode = nil)
    WebMock.reset!

    headers = {
      'Content-Type' => 'application/x-www-form-urlencoded'
    }

    @instance.refresh_token = 'REFRESH_TOKEN'

    body = {
      'grant_type' => 'refresh_token'
    }

    body_response_code = 200

    body_with_scope = body.merge('scope' => @instance.scopes)

    body_with_scope_response_code = 200

    exchange_response = @standalone_token_exchange.dup
    exchange_response['refresh_token'] = SecureRandom.uuid

    response_headers = { content_type: 'application/json; charset=UTF-8',
                         cache_control: 'no-store',
                         pragma: 'no-cache' }

    case failure_mode
    when :bad_token_type
      exchange_response['token_type'] = 'unknown'
    when :no_scope
      exchange_response.delete('scope')
    when :no_access_token
      exchange_response.delete('access_token')
    when :no_expires_in
      exchange_response.delete('expires_in')
    when :cache_control_off
      response_headers.delete(:cache_control)
    when :pragma_off
      response_headers.delete(:pragma)
    when :requires_scope
      body_response_code = 400
    when :disallows_scope
      body_with_scope_response_code = 400
    end

    # can't do this above because we are altering the content of hash in other error modes
    exchange_response_json = exchange_response.to_json
    exchange_response_json = '<bad>' if failure_mode == :bad_json_response

    headers['Authorization'] = "Basic #{Base64.strict_encode64(@instance.client_id + ':' + @instance.client_secret)}" if @instance.client_secret.present?

    patient_id = @standalone_token_exchange['patient']

    stub_request(:get, "#{@instance.url}/Patient/#{exchange_response['patient']}")
      .to_return(status: 200,
                 body: FHIR::Patient.new(id: patient_id).to_json)

    stub_request(:get, "#{@instance.url}/Encounter/#{exchange_response['encounter']}")
      .to_return(status: 200,
                 body: FHIR::Encounter.new(subject: { reference: "Patient/#{patient_id}" }).to_json)

    stub_request(:post, @instance.oauth_token_endpoint)
      .with(headers: headers,
            body: hash_including(body))
      .to_return(status: body_response_code,
                 body: exchange_response_json,
                 headers: response_headers)

    stub_request(:post, @instance.oauth_token_endpoint)
      .with(headers: headers,
            body: hash_including(body_with_scope))
      .to_return(status: body_with_scope_response_code,
                 body: exchange_response_json,
                 headers: response_headers)

    # To test rejection of invalid client_id for public client
    stub_request(:post, @instance.oauth_token_endpoint)
      .with(body: /INVALID/,
            headers: { 'Content-Type' => 'application/x-www-form-urlencoded' })
      .to_return(status: 401)

    # To test rejection of invalid client_id for confidential client
    auth_header = "Basic #{Base64.strict_encode64('INVALID_CLIENT_ID:' + @confidential_client_secret)}"
    stub_request(:post, @instance.oauth_token_endpoint)
      .with(headers: { 'Content-Type' => 'application/x-www-form-urlencoded',
                       'Authorization' => auth_header })
      .to_return(status: 401)
  end

  def all_pass
    setup_mocks
    sequence_result = @sequence.start

    assert sequence_result.pass?
    assert(sequence_result.test_results.none? { |result| result.test_warnings.present? })
  end

  def test_pass_if_confidential_client
    @instance.update(
      client_secret: @confidential_client_secret,
      confidential_client: true
    )
    all_pass
  end

  def test_pass_if_public_client
    @instance.update(
      client_secret: nil,
      confidential_client: false
    )
    all_pass
  end

  # Initial token exchange requires cache control and pragma headers
  # But token exchange does not according to the letter of the smart spec
  # This may be updated in future versions of the spec
  # See https://github.com/HL7/smart-app-launch/issues/293
  def test_warning_if_cache_control_off
    setup_mocks(:cache_control_off)

    sequence_result = @sequence.start
    assert sequence_result.pass?
    assert(sequence_result.test_results.any? { |result| result.test_warnings.present? })
  end

  def test_warning_if_pragma_off
    setup_mocks(:pragma_off)

    sequence_result = @sequence.start
    assert sequence_result.pass?
    assert(sequence_result.test_results.any? { |result| result.test_warnings.present? })
  end

  def test_fail_if_bad_token_type
    setup_mocks(:bad_token_type)

    sequence_result = @sequence.start
    assert sequence_result.fail?
  end

  def test_fail_if_no_scope_returned
    setup_mocks(:no_scope)

    sequence_result = @sequence.start
    assert sequence_result.fail?
  end

  def test_fail_if_no_access_token
    setup_mocks(:no_access_token)

    sequence_result = @sequence.start
    assert sequence_result.fail?
  end

  def test_fail_if_no_expires_in
    setup_mocks(:no_expires_in)

    sequence_result = @sequence.start
    assert sequence_result.fail?
  end

  def test_fail_if_bad_json_response
    setup_mocks(:bad_json_response)

    sequence_result = @sequence.start
    assert sequence_result.fail?
  end

  def test_fail_if_scope_must_be_in_payload
    setup_mocks(:requires_scope)

    sequence_result = @sequence.start
    assert sequence_result.fail?
  end

  def test_fail_if_scope_cannot_be_in_payload
    setup_mocks(:disallows_scope)

    sequence_result = @sequence.start
    assert sequence_result.fail?
  end
end
