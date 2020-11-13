# frozen_string_literal: true

# NOTE: This is a generated file. Any changes made to this file will be
#       overwritten when it is regenerated

require_relative '../../../../test/test_helper'

describe Inferno::Sequence::USCore311ConditionSequence do
  before do
    @sequence_class = Inferno::Sequence::USCore311ConditionSequence
    @base_url = 'http://www.example.com/fhir'
    @token = 'ABC'
    @instance = Inferno::Models::TestingInstance.create(url: @base_url, token: @token, selected_module: 'uscore_v3.1.1')
    @client = FHIR::Client.for_testing_instance(@instance)
    @patient_ids = 'example'
    @instance.patient_ids = @patient_ids
    @auth_header = { 'Authorization' => "Bearer #{@token}" }
  end

  describe 'Condition search by patient test' do
    before do
      @test = @sequence_class[:search_by_patient]
      @sequence = @sequence_class.new(@instance, @client)
      @condition = FHIR.from_contents(load_fixture(:us_core_condition))
      @condition_ary = { @sequence.patient_ids.first => @condition }
      @sequence.instance_variable_set(:'@condition', @condition)
      @sequence.instance_variable_set(:'@condition_ary', @condition_ary)

      @query = {
        'patient': @sequence.patient_ids.first
      }
    end

    it 'skips if the search params are not supported' do
      capabilities = Inferno::Models::ServerCapabilities.new
      def capabilities.supported_search_params(_)
        []
      end
      @instance.server_capabilities = capabilities

      exception = assert_raises(Inferno::SkipException) { @sequence.run_test(@test) }

      assert_match(/The server doesn't support the search parameters:/, exception.message)
    end

    it 'fails if a non-success response code is received' do
      stub_request(:get, "#{@base_url}/Condition")
        .with(query: @query, headers: @auth_header)
        .to_return(status: 401)

      exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

      assert_equal 'Bad response code: expected 200, 201, but found 401. ', exception.message
    end

    it 'fails if a Bundle is not received' do
      stub_request(:get, "#{@base_url}/Condition")
        .with(query: @query, headers: @auth_header)
        .to_return(status: 200, body: FHIR::Condition.new.to_json)

      exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

      assert_equal 'Expected FHIR Bundle but found: Condition', exception.message
    end

    it 'skips if an empty Bundle is received' do
      stub_request(:get, "#{@base_url}/Condition")
        .with(query: @query, headers: @auth_header)
        .to_return(status: 200, body: FHIR::Bundle.new.to_json)

      exception = assert_raises(Inferno::SkipException) { @sequence.run_test(@test) }

      assert_equal 'No Condition resources appear to be available. Please use patients with more information.', exception.message
    end

    it 'fails if the bundle contains a resource which does not conform to the base FHIR spec' do
      stub_request(:get, "#{@base_url}/Condition")
        .with(query: @query, headers: @auth_header)
        .to_return(status: 200, body: wrap_resources_in_bundle(FHIR::Condition.new(id: '!@#$%')).to_json)

      exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

      assert_match(/Invalid \w+:/, exception.message)
    end

    it 'succeeds when a bundle containing a valid resource matching the search parameters is returned' do
      stub_request(:get, "#{@base_url}/Condition")
        .with(query: @query, headers: @auth_header)
        .to_return(status: 200, body: wrap_resources_in_bundle(@condition_ary.values.flatten).to_json)

      reference_with_type_params = @query.merge('patient': 'Patient/' + @query[:patient])
      stub_request(:get, "#{@base_url}/Condition")
        .with(query: reference_with_type_params, headers: @auth_header)
        .to_return(status: 200, body: wrap_resources_in_bundle(@condition_ary.values.flatten).to_json)

      @sequence.run_test(@test)
    end

    describe 'with servers that require status' do
      it 'fails if a 400 is received without an OperationOutcome' do
        stub_request(:get, "#{@base_url}/Condition")
          .with(query: @query, headers: @auth_header)
          .to_return(status: 400)

        exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

        assert_equal 'Server returned a status of 400 without an OperationOutcome.', exception.message
      end

      it 'warns if the search is not documented in the CapabilityStatement' do
        stub_request(:get, "#{@base_url}/Condition")
          .with(query: @query, headers: @auth_header)
          .to_return(status: 400, body: FHIR::OperationOutcome.new.to_json)

        assert_raises(WebMock::NetConnectNotAllowedError) { @sequence.run_test(@test) }

        warnings = @sequence.instance_variable_get(:@test_warnings)

        assert warnings.present?, 'Test did not generate any warnings.'
        assert warnings.any? { |warning| warning.match(/search interaction for this resource is not documented/) },
               'Test did not generate the expected warning.'
      end

      it 'fails if searching with status is not successful' do
        stub_request(:get, "#{@base_url}/Condition")
          .with(query: @query, headers: @auth_header)
          .to_return(status: 400, body: FHIR::OperationOutcome.new.to_json)
        stub_request(:get, "#{@base_url}/Condition")
          .with(query: @query.merge('clinical-status': ['active', 'recurrence', 'relapse', 'inactive', 'remission', 'resolved'].first), headers: @auth_header)
          .to_return(status: 500)

        exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

        assert_equal 'Bad response code: expected 200, 201, but found 500. ', exception.message
      end

      it 'fails if searching with status does not return a Bundle' do
        stub_request(:get, "#{@base_url}/Condition")
          .with(query: @query, headers: @auth_header)
          .to_return(status: 400, body: FHIR::OperationOutcome.new.to_json)
        stub_request(:get, "#{@base_url}/Condition")
          .with(query: @query.merge('clinical-status': ['active', 'recurrence', 'relapse', 'inactive', 'remission', 'resolved'].first), headers: @auth_header)
          .to_return(status: 200, body: FHIR::Condition.new.to_json)

        exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

        assert_equal 'Expected FHIR Bundle but found: Condition', exception.message
      end

      it 'succeeds if searching with status returns valid resources' do
        stub_request(:get, "#{@base_url}/Condition")
          .with(query: @query, headers: @auth_header)
          .to_return(status: 400, body: FHIR::OperationOutcome.new.to_json)
        stub_request(:get, "#{@base_url}/Condition")
          .with(query: @query.merge('clinical-status': ['active', 'recurrence', 'relapse', 'inactive', 'remission', 'resolved'].first), headers: @auth_header)
          .to_return(status: 200, body: wrap_resources_in_bundle([@condition]).to_json)

        stub_request(:get, "#{@base_url}/Condition")
          .with(query: @query.merge('patient': 'Patient/' + @query[:patient], 'clinical-status': ['active', 'recurrence', 'relapse', 'inactive', 'remission', 'resolved'].first), headers: @auth_header)
          .to_return(status: 200, body: wrap_resources_in_bundle([@condition]).to_json)

        @sequence.run_test(@test)
      end
    end
  end

  describe 'Condition search by patient+category test' do
    before do
      @test = @sequence_class[:search_by_patient_category]
      @sequence = @sequence_class.new(@instance, @client)
      @condition = FHIR.from_contents(load_fixture(:us_core_condition))
      @condition_ary = { @sequence.patient_ids.first => @condition }
      @sequence.instance_variable_set(:'@condition', @condition)
      @sequence.instance_variable_set(:'@condition_ary', @condition_ary)

      @sequence.instance_variable_set(:'@resources_found', true)

      @query = {
        'patient': @sequence.patient_ids.first,
        'category': @sequence.get_value_for_search_param(@sequence.resolve_element_from_path(@condition_ary[@sequence.patient_ids.first], 'category'))
      }

      @query_with_system = {
        'patient': @sequence.patient_ids.first,
        'category': @sequence.get_value_for_search_param(@sequence.resolve_element_from_path(@condition_ary[@sequence.patient_ids.first], 'category'), true)
      }
    end

    it 'skips if the search params are not supported' do
      capabilities = Inferno::Models::ServerCapabilities.new
      def capabilities.supported_search_params(_)
        ['patient']
      end
      @instance.server_capabilities = capabilities

      exception = assert_raises(Inferno::SkipException) { @sequence.run_test(@test) }

      assert_match(/The server doesn't support the search parameters:/, exception.message)
    end

    it 'skips if no Condition resources have been found' do
      @sequence.instance_variable_set(:'@resources_found', false)

      exception = assert_raises(Inferno::SkipException) { @sequence.run_test(@test) }

      assert_equal 'No Condition resources appear to be available. Please use patients with more information.', exception.message
    end

    it 'skips if a value for one of the search parameters cannot be found' do
      @sequence.instance_variable_set(:'@condition_ary', @sequence.patient_ids.first => FHIR::Condition.new)

      exception = assert_raises(Inferno::SkipException) { @sequence.run_test(@test) }

      assert_match(/Could not resolve .* in any resource\./, exception.message)
    end

    it 'fails if a non-success response code is received' do
      stub_request(:get, "#{@base_url}/Condition")
        .with(query: @query, headers: @auth_header)
        .to_return(status: 401)

      exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

      assert_equal 'Bad response code: expected 200, 201, but found 401. ', exception.message
    end

    it 'fails if a Bundle is not received' do
      stub_request(:get, "#{@base_url}/Condition")
        .with(query: @query, headers: @auth_header)
        .to_return(status: 200, body: FHIR::Condition.new.to_json)

      exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

      assert_equal 'Expected FHIR Bundle but found: Condition', exception.message
    end

    it 'fails if the bundle contains a resource which does not conform to the base FHIR spec' do
      stub_request(:get, "#{@base_url}/Condition")
        .with(query: @query, headers: @auth_header)
        .to_return(status: 200, body: wrap_resources_in_bundle(FHIR::Condition.new(id: '!@#$%')).to_json)

      exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

      assert_match(/Invalid \w+:/, exception.message)
    end

    it 'succeeds when a bundle containing a valid resource matching the search parameters is returned' do
      stub_request(:get, "#{@base_url}/Condition")
        .with(query: @query, headers: @auth_header)
        .to_return(status: 200, body: wrap_resources_in_bundle(@condition_ary.values.flatten).to_json)

      stub_request(:get, "#{@base_url}/Condition")
        .with(query: @query_with_system, headers: @auth_header)
        .to_return(status: 200, body: wrap_resources_in_bundle(@condition_ary.values.flatten).to_json)

      @sequence.run_test(@test)
    end

    describe 'with servers that require status' do
      it 'fails if a 400 is received without an OperationOutcome' do
        stub_request(:get, "#{@base_url}/Condition")
          .with(query: @query, headers: @auth_header)
          .to_return(status: 400)

        exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

        assert_equal 'Server returned a status of 400 without an OperationOutcome.', exception.message
      end

      it 'warns if the search is not documented in the CapabilityStatement' do
        stub_request(:get, "#{@base_url}/Condition")
          .with(query: @query, headers: @auth_header)
          .to_return(status: 400, body: FHIR::OperationOutcome.new.to_json)

        assert_raises(WebMock::NetConnectNotAllowedError) { @sequence.run_test(@test) }

        warnings = @sequence.instance_variable_get(:@test_warnings)

        assert warnings.present?, 'Test did not generate any warnings.'
        assert warnings.any? { |warning| warning.match(/search interaction for this resource is not documented/) },
               'Test did not generate the expected warning.'
      end

      it 'fails if searching with status is not successful' do
        stub_request(:get, "#{@base_url}/Condition")
          .with(query: @query, headers: @auth_header)
          .to_return(status: 400, body: FHIR::OperationOutcome.new.to_json)
        stub_request(:get, "#{@base_url}/Condition")
          .with(query: @query.merge('clinical-status': ['active', 'recurrence', 'relapse', 'inactive', 'remission', 'resolved'].first), headers: @auth_header)
          .to_return(status: 500)

        exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

        assert_equal 'Bad response code: expected 200, 201, but found 500. ', exception.message
      end

      it 'fails if searching with status does not return a Bundle' do
        stub_request(:get, "#{@base_url}/Condition")
          .with(query: @query, headers: @auth_header)
          .to_return(status: 400, body: FHIR::OperationOutcome.new.to_json)
        stub_request(:get, "#{@base_url}/Condition")
          .with(query: @query.merge('clinical-status': ['active', 'recurrence', 'relapse', 'inactive', 'remission', 'resolved'].first), headers: @auth_header)
          .to_return(status: 200, body: FHIR::Condition.new.to_json)

        exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

        assert_equal 'Expected FHIR Bundle but found: Condition', exception.message
      end

      it 'succeeds if searching with status returns valid resources' do
        stub_request(:get, "#{@base_url}/Condition")
          .with(query: @query, headers: @auth_header)
          .to_return(status: 400, body: FHIR::OperationOutcome.new.to_json)
        stub_request(:get, "#{@base_url}/Condition")
          .with(query: @query.merge('clinical-status': ['active', 'recurrence', 'relapse', 'inactive', 'remission', 'resolved'].first), headers: @auth_header)
          .to_return(status: 200, body: wrap_resources_in_bundle([@condition]).to_json)

        stub_request(:get, "#{@base_url}/Condition")
          .with(query: @query_with_system.merge('clinical-status': ['active', 'recurrence', 'relapse', 'inactive', 'remission', 'resolved'].first), headers: @auth_header)
          .to_return(status: 200, body: wrap_resources_in_bundle([@condition]).to_json)

        @sequence.run_test(@test)
      end
    end
  end

  describe 'Condition search by patient+clinical-status test' do
    before do
      @test = @sequence_class[:search_by_patient_clinical_status]
      @sequence = @sequence_class.new(@instance, @client)
      @condition = FHIR.from_contents(load_fixture(:us_core_condition))
      @condition_ary = { @sequence.patient_ids.first => @condition }
      @sequence.instance_variable_set(:'@condition', @condition)
      @sequence.instance_variable_set(:'@condition_ary', @condition_ary)

      @sequence.instance_variable_set(:'@resources_found', true)

      @query = {
        'patient': @sequence.patient_ids.first,
        'clinical-status': @sequence.get_value_for_search_param(@sequence.resolve_element_from_path(@condition_ary[@sequence.patient_ids.first], 'clinicalStatus'))
      }

      @query_with_system = {
        'patient': @sequence.patient_ids.first,
        'clinical-status': @sequence.get_value_for_search_param(@sequence.resolve_element_from_path(@condition_ary[@sequence.patient_ids.first], 'clinicalStatus'), true)
      }
    end

    it 'skips if the search params are not supported' do
      capabilities = Inferno::Models::ServerCapabilities.new
      def capabilities.supported_search_params(_)
        ['patient']
      end
      @instance.server_capabilities = capabilities

      exception = assert_raises(Inferno::SkipException) { @sequence.run_test(@test) }

      assert_match(/The server doesn't support the search parameters:/, exception.message)
    end

    it 'skips if no Condition resources have been found' do
      @sequence.instance_variable_set(:'@resources_found', false)

      exception = assert_raises(Inferno::SkipException) { @sequence.run_test(@test) }

      assert_equal 'No Condition resources appear to be available. Please use patients with more information.', exception.message
    end

    it 'skips if a value for one of the search parameters cannot be found' do
      @sequence.instance_variable_set(:'@condition_ary', @sequence.patient_ids.first => FHIR::Condition.new)

      exception = assert_raises(Inferno::SkipException) { @sequence.run_test(@test) }

      assert_match(/Could not resolve .* in any resource\./, exception.message)
    end

    it 'fails if a non-success response code is received' do
      stub_request(:get, "#{@base_url}/Condition")
        .with(query: @query, headers: @auth_header)
        .to_return(status: 401)

      exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

      assert_equal 'Bad response code: expected 200, 201, but found 401. ', exception.message
    end

    it 'fails if a Bundle is not received' do
      stub_request(:get, "#{@base_url}/Condition")
        .with(query: @query, headers: @auth_header)
        .to_return(status: 200, body: FHIR::Condition.new.to_json)

      exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

      assert_equal 'Expected FHIR Bundle but found: Condition', exception.message
    end

    it 'fails if the bundle contains a resource which does not conform to the base FHIR spec' do
      stub_request(:get, "#{@base_url}/Condition")
        .with(query: @query, headers: @auth_header)
        .to_return(status: 200, body: wrap_resources_in_bundle(FHIR::Condition.new(id: '!@#$%')).to_json)

      exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

      assert_match(/Invalid \w+:/, exception.message)
    end

    it 'succeeds when a bundle containing a valid resource matching the search parameters is returned' do
      stub_request(:get, "#{@base_url}/Condition")
        .with(query: @query, headers: @auth_header)
        .to_return(status: 200, body: wrap_resources_in_bundle(@condition_ary.values.flatten).to_json)

      stub_request(:get, "#{@base_url}/Condition")
        .with(query: @query_with_system, headers: @auth_header)
        .to_return(status: 200, body: wrap_resources_in_bundle(@condition_ary.values.flatten).to_json)

      @sequence.run_test(@test)
    end
  end

  describe 'Condition search by patient+code test' do
    before do
      @test = @sequence_class[:search_by_patient_code]
      @sequence = @sequence_class.new(@instance, @client)
      @condition = FHIR.from_contents(load_fixture(:us_core_condition))
      @condition_ary = { @sequence.patient_ids.first => @condition }
      @sequence.instance_variable_set(:'@condition', @condition)
      @sequence.instance_variable_set(:'@condition_ary', @condition_ary)

      @sequence.instance_variable_set(:'@resources_found', true)

      @query = {
        'patient': @sequence.patient_ids.first,
        'code': @sequence.get_value_for_search_param(@sequence.resolve_element_from_path(@condition_ary[@sequence.patient_ids.first], 'code'))
      }

      @query_with_system = {
        'patient': @sequence.patient_ids.first,
        'code': @sequence.get_value_for_search_param(@sequence.resolve_element_from_path(@condition_ary[@sequence.patient_ids.first], 'code'), true)
      }
    end

    it 'skips if the search params are not supported' do
      capabilities = Inferno::Models::ServerCapabilities.new
      def capabilities.supported_search_params(_)
        ['patient']
      end
      @instance.server_capabilities = capabilities

      exception = assert_raises(Inferno::SkipException) { @sequence.run_test(@test) }

      assert_match(/The server doesn't support the search parameters:/, exception.message)
    end

    it 'skips if no Condition resources have been found' do
      @sequence.instance_variable_set(:'@resources_found', false)

      exception = assert_raises(Inferno::SkipException) { @sequence.run_test(@test) }

      assert_equal 'No Condition resources appear to be available. Please use patients with more information.', exception.message
    end

    it 'skips if a value for one of the search parameters cannot be found' do
      @sequence.instance_variable_set(:'@condition_ary', @sequence.patient_ids.first => FHIR::Condition.new)

      exception = assert_raises(Inferno::SkipException) { @sequence.run_test(@test) }

      assert_match(/Could not resolve .* in any resource\./, exception.message)
    end

    it 'fails if a non-success response code is received' do
      stub_request(:get, "#{@base_url}/Condition")
        .with(query: @query, headers: @auth_header)
        .to_return(status: 401)

      exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

      assert_equal 'Bad response code: expected 200, 201, but found 401. ', exception.message
    end

    it 'fails if a Bundle is not received' do
      stub_request(:get, "#{@base_url}/Condition")
        .with(query: @query, headers: @auth_header)
        .to_return(status: 200, body: FHIR::Condition.new.to_json)

      exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

      assert_equal 'Expected FHIR Bundle but found: Condition', exception.message
    end

    it 'fails if the bundle contains a resource which does not conform to the base FHIR spec' do
      stub_request(:get, "#{@base_url}/Condition")
        .with(query: @query, headers: @auth_header)
        .to_return(status: 200, body: wrap_resources_in_bundle(FHIR::Condition.new(id: '!@#$%')).to_json)

      exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

      assert_match(/Invalid \w+:/, exception.message)
    end

    it 'succeeds when a bundle containing a valid resource matching the search parameters is returned' do
      stub_request(:get, "#{@base_url}/Condition")
        .with(query: @query, headers: @auth_header)
        .to_return(status: 200, body: wrap_resources_in_bundle(@condition_ary.values.flatten).to_json)

      stub_request(:get, "#{@base_url}/Condition")
        .with(query: @query_with_system, headers: @auth_header)
        .to_return(status: 200, body: wrap_resources_in_bundle(@condition_ary.values.flatten).to_json)

      @sequence.run_test(@test)
    end

    describe 'with servers that require status' do
      it 'fails if a 400 is received without an OperationOutcome' do
        stub_request(:get, "#{@base_url}/Condition")
          .with(query: @query, headers: @auth_header)
          .to_return(status: 400)

        exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

        assert_equal 'Server returned a status of 400 without an OperationOutcome.', exception.message
      end

      it 'warns if the search is not documented in the CapabilityStatement' do
        stub_request(:get, "#{@base_url}/Condition")
          .with(query: @query, headers: @auth_header)
          .to_return(status: 400, body: FHIR::OperationOutcome.new.to_json)

        assert_raises(WebMock::NetConnectNotAllowedError) { @sequence.run_test(@test) }

        warnings = @sequence.instance_variable_get(:@test_warnings)

        assert warnings.present?, 'Test did not generate any warnings.'
        assert warnings.any? { |warning| warning.match(/search interaction for this resource is not documented/) },
               'Test did not generate the expected warning.'
      end

      it 'fails if searching with status is not successful' do
        stub_request(:get, "#{@base_url}/Condition")
          .with(query: @query, headers: @auth_header)
          .to_return(status: 400, body: FHIR::OperationOutcome.new.to_json)
        stub_request(:get, "#{@base_url}/Condition")
          .with(query: @query.merge('clinical-status': ['active', 'recurrence', 'relapse', 'inactive', 'remission', 'resolved'].first), headers: @auth_header)
          .to_return(status: 500)

        exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

        assert_equal 'Bad response code: expected 200, 201, but found 500. ', exception.message
      end

      it 'fails if searching with status does not return a Bundle' do
        stub_request(:get, "#{@base_url}/Condition")
          .with(query: @query, headers: @auth_header)
          .to_return(status: 400, body: FHIR::OperationOutcome.new.to_json)
        stub_request(:get, "#{@base_url}/Condition")
          .with(query: @query.merge('clinical-status': ['active', 'recurrence', 'relapse', 'inactive', 'remission', 'resolved'].first), headers: @auth_header)
          .to_return(status: 200, body: FHIR::Condition.new.to_json)

        exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

        assert_equal 'Expected FHIR Bundle but found: Condition', exception.message
      end

      it 'succeeds if searching with status returns valid resources' do
        stub_request(:get, "#{@base_url}/Condition")
          .with(query: @query, headers: @auth_header)
          .to_return(status: 400, body: FHIR::OperationOutcome.new.to_json)
        stub_request(:get, "#{@base_url}/Condition")
          .with(query: @query.merge('clinical-status': ['active', 'recurrence', 'relapse', 'inactive', 'remission', 'resolved'].first), headers: @auth_header)
          .to_return(status: 200, body: wrap_resources_in_bundle([@condition]).to_json)

        stub_request(:get, "#{@base_url}/Condition")
          .with(query: @query_with_system.merge('clinical-status': ['active', 'recurrence', 'relapse', 'inactive', 'remission', 'resolved'].first), headers: @auth_header)
          .to_return(status: 200, body: wrap_resources_in_bundle([@condition]).to_json)

        @sequence.run_test(@test)
      end
    end
  end

  describe 'Condition read test' do
    before do
      @condition_id = '456'
      @test = @sequence_class[:read_interaction]
      @sequence = @sequence_class.new(@instance, @client)
      @sequence.instance_variable_set(:'@resources_found', true)
      @sequence.instance_variable_set(:'@condition', FHIR::Condition.new(id: @condition_id))
    end

    it 'skips if the Condition read interaction is not supported' do
      Inferno::Models::ServerCapabilities.create(
        testing_instance_id: @instance.id,
        capabilities: FHIR::CapabilityStatement.new.to_json
      )
      @instance.reload
      exception = assert_raises(Inferno::SkipException) { @sequence.run_test(@test) }

      skip_message = 'This server does not support Condition read operation(s) according to conformance statement.'
      assert_equal skip_message, exception.message
    end

    it 'skips if no Condition has been found' do
      @sequence.instance_variable_set(:'@resources_found', false)
      exception = assert_raises(Inferno::SkipException) { @sequence.run_test(@test) }

      assert_equal 'No Condition resources appear to be available. Please use patients with more information.', exception.message
    end

    it 'fails if a non-success response code is received' do
      Inferno::Models::ResourceReference.create(
        resource_type: 'Condition',
        resource_id: @condition_id,
        testing_instance: @instance
      )

      stub_request(:get, "#{@base_url}/Condition/#{@condition_id}")
        .with(query: @query, headers: @auth_header)
        .to_return(status: 401)

      exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

      assert_equal 'Bad response code: expected 200, 201, but found 401. ', exception.message
    end

    it 'fails if no resource is received' do
      Inferno::Models::ResourceReference.create(
        resource_type: 'Condition',
        resource_id: @condition_id,
        testing_instance: @instance
      )

      stub_request(:get, "#{@base_url}/Condition/#{@condition_id}")
        .with(query: @query, headers: @auth_header)
        .to_return(status: 200)

      exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

      assert_equal 'Expected Condition resource to be present.', exception.message
    end

    it 'fails if the resource returned is not a Condition' do
      Inferno::Models::ResourceReference.create(
        resource_type: 'Condition',
        resource_id: @condition_id,
        testing_instance: @instance
      )

      stub_request(:get, "#{@base_url}/Condition/#{@condition_id}")
        .with(query: @query, headers: @auth_header)
        .to_return(status: 200, body: FHIR::Patient.new.to_json)

      exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

      assert_equal 'Expected resource to be of type Condition.', exception.message
    end

    it 'fails if the resource has an incorrect id' do
      Inferno::Models::ResourceReference.create(
        resource_type: 'Condition',
        resource_id: @condition_id,
        testing_instance: @instance
      )

      condition = FHIR::Condition.new(
        id: 'wrong_id'
      )

      stub_request(:get, "#{@base_url}/Condition/#{@condition_id}")
        .with(query: @query, headers: @auth_header)
        .to_return(status: 200, body: condition.to_json)
      exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }
      assert_equal "Expected resource to contain id: #{@condition_id}", exception.message
    end

    it 'succeeds when a Condition resource is read successfully' do
      condition = FHIR::Condition.new(
        id: @condition_id
      )
      Inferno::Models::ResourceReference.create(
        resource_type: 'Condition',
        resource_id: @condition_id,
        testing_instance: @instance
      )

      stub_request(:get, "#{@base_url}/Condition/#{@condition_id}")
        .with(query: @query, headers: @auth_header)
        .to_return(status: 200, body: condition.to_json)

      @sequence.run_test(@test)
    end
  end

  describe 'resource validation test' do
    before do
      @condition = FHIR::Condition.new(load_json_fixture(:us_core_condition))
      @test = @sequence_class[:validate_resources]
      @sequence = @sequence_class.new(@instance, @client)
      @sequence.instance_variable_set(:'@resources_found', true)

      Inferno::Models::ResourceReference.create(
        resource_type: 'Condition',
        resource_id: @condition.id,
        testing_instance: @instance
      )
    end

    it 'fails if a resource does not contain a code for a CodeableConcept with a required binding' do
      ['clinicalStatus', 'verificationStatus'].each do |path|
        @sequence.resolve_path(@condition, path).each do |concept|
          concept&.coding&.each do |coding|
            coding&.code = nil
            coding&.system = nil
          end
          concept&.text = 'abc'
        end
      end

      stub_request(:get, "#{@base_url}/Condition/#{@condition.id}")
        .with(headers: @auth_header)
        .to_return(status: 200, body: @condition.to_json)

      exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

      ['clinicalStatus', 'verificationStatus'].each do |path|
        assert_match(%r{Condition/#{@condition.id}: The CodeableConcept at '#{path}' is bound to a required ValueSet but does not contain any codes\.}, exception.message)
      end
    end
  end
end
