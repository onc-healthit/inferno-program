# frozen_string_literal: true

require_relative '../../../../test/test_helper'

describe Inferno::Sequence::BulkDataGroupExportValidationSequence do
  before do
    @sequence_class = Inferno::Sequence::BulkDataGroupExportValidationSequence

    @patient_file_location = 'https://www.example.com/patient_export.ndjson'
    @condition_file_location = 'https://www.example.com/condition_export.ndjson'

    @output = [
      { 'type' => 'Patient', 'url' => @patient_file_location },
      { 'type' => 'Condition', 'url' => @condition_file_location }
    ]

    @status_response = {
      'output' => @output,
      'requiresAccessToken' => true
    }

    @instance = Inferno::Models::TestingInstance.create(
      url: 'http://www.example.com',
      bulk_status_output: @status_response.to_json,
      bulk_access_token: 99_897_979
    )

    @instance.instance_variable_set(:'@module', OpenStruct.new(fhir_version: 'r4'))

    @client = FHIR::Client.new(@instance.url)

    @file_request_headers = { accept: 'application/fhir+ndjson',
                              authorization: "Bearer #{@instance.bulk_access_token}" }

    @patient_export = load_fixture_with_extension('bulk_data_patient.ndjson')
    @condition_export = load_fixture_with_extension('bulk_data_condition.ndjson')
  end

  describe 'initialize' do
    it 'not initialize if status response is nil' do
      copy_instance = @instance.clone
      copy_instance.bulk_status_output = nil
      sequence = @sequence_class.new(copy_instance, @client)
      assert sequence.output.nil?
      assert sequence.requires_access_token.nil?
    end

    it 'initialize output' do
      sequence = @sequence_class.new(@instance, @client)
      assert sequence.output.to_json == @output.to_json
    end

    it 'initialize requiresAccessToken' do
      sequence = @sequence_class.new(@instance, @client)
      assert sequence.requires_access_token == @status_response['requiresAccessToken']
    end
  end

  describe 'endpoint TLS tests' do
    before do
      @sequence = @sequence_class.new(@instance, @client)
      @test = @sequence_class[:require_tls]
    end

    it 'fails when the auth endpoint does not support tls' do
      a_sequence = @sequence.clone
      a_sequence.output[0]['url'] = 'http://www.example.com/patient_export.ndjson'

      error = assert_raises(Inferno::AssertionException) do
        @sequence.run_test(@test)
      end

      assert_match(/^URI is not HTTPS/, error.message)
    end

    it 'succeeds when TLS 1.2 is supported' do
      stub_request(:get, @patient_file_location)
        .to_return(status: 200).then
        .to_raise(StandardError)

      @sequence.run_test(@test)
    end
  end

  describe 'validate patient ids in group' do
    it 'omits when no patient ids in group passed' do
      @sequence = @sequence_class.new(@instance, @client)
      @test = @sequence_class[:validate_patient_ids_in_group]

      error = assert_raises(Inferno::OmitException) do
        @sequence.run_test(@test)
      end

      assert_match(/^No patient/, error.message)
    end

    it 'succeeds when patients found equals patients provided' do
      instance_copy = @instance.clone
      @sequence = @sequence_class.new(instance_copy, @client)
      @test = @sequence_class[:validate_patient_ids_in_group]

      instance_copy.bulk_patient_ids_in_group = 'a,b'

      @sequence.patient_ids_seen = Set.new(['b', 'a'])

      @sequence.run_test(@test)
    end

    it 'fails when patients found subset of patients provided' do
      instance_copy = @instance.clone
      @sequence = @sequence_class.new(instance_copy, @client)
      @test = @sequence_class[:validate_patient_ids_in_group]

      instance_copy.bulk_patient_ids_in_group = 'a,b,c'

      @sequence.patient_ids_seen = Set.new(['b', 'a'])

      error = assert_raises(Inferno::AssertionException) do
        @sequence.run_test(@test)
      end

      assert_match(/^Mismatch/, error.message)
    end

    it 'fails when patients found superset of patients provided' do
      instance_copy = @instance.clone
      @sequence = @sequence_class.new(instance_copy, @client)
      @test = @sequence_class[:validate_patient_ids_in_group]

      instance_copy.bulk_patient_ids_in_group = 'a,b'

      @sequence.patient_ids_seen = Set.new(['b', 'a', 'c'])

      error = assert_raises(Inferno::AssertionException) do
        @sequence.run_test(@test)
      end

      assert_match(/^Mismatch/, error.message)
    end

    it 'fails when patients found different than patients provided' do
      instance_copy = @instance.clone
      @sequence = @sequence_class.new(instance_copy, @client)
      @test = @sequence_class[:validate_patient_ids_in_group]

      instance_copy.bulk_patient_ids_in_group = 'a,b'

      @sequence.patient_ids_seen = Set.new(['a', 'c'])

      error = assert_raises(Inferno::AssertionException) do
        @sequence.run_test(@test)
      end

      assert_match(/^Mismatch/, error.message)
    end
  end

  describe 'require access token test' do
    before do
      @sequence = @sequence_class.new(@instance, @client)
      @test = @sequence_class[:require_access_token]
      @headers_no_token = @file_request_headers.clone
      @headers_no_token.delete(:authorization)
    end

    it 'skips when requiresAccessToken is false' do
      a_sequence = @sequence.clone
      a_sequence.requires_access_token = false

      error = assert_raises(Inferno::SkipException) do
        a_sequence.run_test(@test)
      end

      assert error.message == 'Could not verify this functionality when requireAccessToken is false'
    end

    it 'skips when bulk_access_token is nil' do
      a_instance = Inferno::Models::TestingInstance.create(
        url: 'http://www.example.com',
        bulk_status_output: @status_response.to_json
      )

      a_sequence = @sequence_class.new(a_instance, @client)

      error = assert_raises(Inferno::SkipException) do
        a_sequence.run_test(@test)
      end

      assert error.message == 'Could not verify this functionality when bearer token is not set'
    end

    it 'catches non 401 status code' do
      stub_request(:get, @patient_file_location)
        .with(headers: @headers_no_token)
        .to_return(
          status: 200
        )

      error = assert_raises(Inferno::AssertionException) do
        @sequence.run_test(@test)
      end

      assert_match(/^Bad response code: expected 400 or 401/, error.message)
    end

    it 'catches 401 error' do
      stub_request(:get, @patient_file_location)
        .with(headers: @headers_no_token)
        .to_return(
          status: 401
        )

      @sequence.run_test(@test)
    end
  end

  describe 'get lines-to-validate' do
    before do
      @sequence = @sequence_class.new(@instance, @client)
    end

    it 'get integer when input is integer string' do
      result = @sequence.get_lines_to_validate('2')
      assert !result[:validate_all]
      assert result[:lines_to_validate] == 2
    end

    it 'get integer when input is a decimal string' do
      result = @sequence.get_lines_to_validate('2.5')
      assert !result[:validate_all]
      assert result[:lines_to_validate] == 2
    end

    it 'get 0 when input is not a number nor *' do
      result = @sequence.get_lines_to_validate('abc')
      assert !result[:validate_all]
      assert result[:lines_to_validate].zero?
    end

    it 'get 0 when input is empty' do
      result = @sequence.get_lines_to_validate('')
      assert !result[:validate_all]
      assert result[:lines_to_validate].zero?
    end

    it 'get 0 when input is nil' do
      result = @sequence.get_lines_to_validate(nil)
      assert !result[:validate_all]
      assert result[:lines_to_validate].zero?
    end

    it 'get validate_all when input is *' do
      result = @sequence.get_lines_to_validate('*')
      assert result[:validate_all]
    end
  end

  describe 'read output tests' do
    before do
      @sequence = @sequence_class.new(@instance, @client)
    end

    it 'skip when output is nil' do
      error = assert_raises(Inferno::SkipException) do
        @sequence.test_output_against_profile('Patient', nil, '1')
      end

      assert error.message == 'Bulk Data Server response does not have output data'
    end

    it 'skip when resource is not exported' do
      error = assert_raises(Inferno::SkipException) do
        @sequence.test_output_against_profile('Observation', @output, '1')
      end

      assert error.message == 'Bulk Data Server export does not have Observation data'
    end

    it 'select matched output file' do
      stub_request(:get, @patient_file_location)
        .with(headers: @file_request_headers)
        .to_return(
          status: 200,
          headers: { content_type: 'application/fhir+ndjson' },
          body: @patient_export
        )

      pass_exception = assert_raises(Inferno::PassException) { @sequence.test_output_against_profile('Patient', @output, '1') }
      assert_match(/^Successfully validated [\d]+ resource/, pass_exception.message)
    end

    it 'fails when content-type is invalid' do
      stub_request(:get, @patient_file_location)
        .with(headers: @file_request_headers)
        .to_return(
          status: 200,
          headers: { content_type: 'application/fhir+text' },
          body: @patient_export
        )

      error = assert_raises(Inferno::AssertionException) do
        @sequence.test_output_against_profile('Patient', @output, '1')
      end

      assert_match(/Content type/, error.message)
    end
  end

  describe 'read NDJSON file tests' do
    before do
      @sequence = @sequence_class.new(@instance, @client)
      @headers = { accept: 'application/fhir+ndjson' }
      @headers['Authorization'] = "Bearer #{@instance.bulk_access_token}"
      stub_request(:get, @patient_file_location)
        .with(headers: @file_request_headers)
        .to_return(
          status: 200,
          headers: { content_type: 'application/fhir+ndjson' },
          body: @patient_export
        )
    end

    it 'succeeds when NDJSON is valid and saves patient ids as seen' do
      file = @output.find { |line| line['type'] == 'Patient' }
      @sequence.check_file_request(file, 'Patient', true, 1)
      diff = @sequence.patient_ids_seen ^ Set.new(['ac1bdb14-fea1-4912-8d7c-e3ecec74b0d7',
                                                   '8a7c11ff-25f0-433e-882a-4f43b8fb7dc4',
                                                   '9f83799e-76db-41fa-8c1f-e1a532c30a52',
                                                   '1f4b3e0c-3137-4fdd-a94f-0aaeb883074e'])
      assert diff.empty?
    end

    it 'succeeds when lines_to_validate is greater than lines of output file' do
      file = @output.find { |line| line['type'] == 'Patient' }
      @sequence.check_file_request(file, 'Patient', false, 100)
    end

    it 'skip validation when lines_to_validate is less than 1' do
      file = @output.find { |line| line['type'] == 'Patient' }
      @sequence.check_file_request(file, 'Condition', false, 0)
    end

    it 'fails when output file type is different from resource type' do
      file = @output.find { |line| line['type'] == 'Patient' }
      error = assert_raises(Inferno::AssertionException) do
        @sequence.check_file_request(file, 'Condition', true, 1)
      end

      assert_match(/^Resource type/, error.message)
    end

    it 'fails when output file has invalid resource' do
      invalid_patient_export = @patient_export.sub('"male"', '"001"')
      stub_request(:get, 'https://www.example.com/wrong_patient_export.json')
        .with(headers: @file_request_headers)
        .to_return(
          status: 200,
          headers: { content_type: 'application/fhir+ndjson' },
          body: invalid_patient_export
        )

      error = assert_raises(Inferno::AssertionException) do
        file = @output.find { |line| line['type'] == 'Patient' }
        file['url'] = 'https://www.example.com/wrong_patient_export.json'
        @sequence.check_file_request(file, 'Patient', true, 1)
      end

      assert_match(/invalid code '001'/, error.message)
    end

    it 'succeeds when validate first line in output file having invalid resource' do
      invalid_patient_export = @patient_export.sub('"male"', '"001"')
      stub_request(:get, 'https://www.example.com/wrong_patient_export.json')
        .with(headers: @file_request_headers)
        .to_return(
          status: 200,
          headers: { content_type: 'application/fhir+ndjson' },
          body: invalid_patient_export
        )

      file = @output.find { |line| line['type'] == 'Patient' }
      file['url'] = 'https://www.example.com/wrong_patient_export.json'
      @sequence.check_file_request(file, 'Patient', false, 1)
    end

    it 'succeeds when NDJSON is valid and has at least two patients' do
      file = @output.find { |line| line['type'] == 'Patient' }
      @sequence.check_file_request(file, 'Patient', false, 0)
      assert @sequence.has_min_patient_count
    end

    it 'fails when NDJSON is valid and has only one patient' do
      single_patient_export = @patient_export.each_line.first
      stub_request(:get, 'https://www.example.com/single_patient_export.json')
        .with(headers: @file_request_headers)
        .to_return(
          status: 200,
          headers: { content_type: 'application/fhir+ndjson' },
          body: single_patient_export
        )

      file = @output.find { |line| line['type'] == 'Patient' }
      file['url'] = 'https://www.example.com/single_patient_export.json'
      @sequence.check_file_request(file, 'Patient', false, 0)
      assert !@sequence.has_min_patient_count
    end
  end
end
