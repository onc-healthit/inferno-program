# frozen_string_literal: true

require_relative '../../../../test/test_helper'

describe Inferno::Sequence::BulkDataGroupExportValidationSequence do
  before do
    @sequence_class = Inferno::Sequence::BulkDataGroupExportValidationSequence

    @instance = Inferno::Models::TestingInstance.create(
      url: 'http://www.example.com'
    )

    @instance.instance_variable_set(:'@module', OpenStruct.new(fhir_version: 'stu3'))

    @client = FHIR::Client.new(@instance.url)

    @file_request_headers = { accept: 'application/fhir+ndjson' }

    @patient_file_location = 'http://www.example.com/patient_export.ndjson'
    @condition_file_location = 'http://www.example.com/condition_export.ndjson'

    @patient_export = load_fixture_with_extension('bulk_data_patient.ndjson')
    @condition_export = load_fixture_with_extension('bulk_data_condition.ndjson')

    @output = [
      { 'type' => 'Patient', 'url' => @patient_file_location },
      { 'type' => 'Condition', 'url' => @condition_file_location }
    ]
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
        @sequence.test_output_against_profile('Observation', @output.to_json, '1')
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

      @sequence.test_output_against_profile('Patient', @output.to_json, '1')
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
        @sequence.test_output_against_profile('Patient', @output.to_json, '1')
      end

      assert_match(/Expected content-type/, error.message)
    end
  end

  describe 'read NDJSON file tests' do
    before do
      @sequence = @sequence_class.new(@instance, @client)
    end

    it 'succeeds when NDJSON is valid' do
      @sequence.check_ndjson(@patient_export, 'Patient', true, 1)
    end

    it 'succeeds when lines_to_validate is greater than lines of output file' do
      @sequence.check_ndjson(@patient_export, 'Patient', false, 100)
    end

    it 'skip validation when lines_to_validate is less than 1' do
      @sequence.check_ndjson(@patient_export, 'Condition', false, 0)
    end

    it 'fails when output file type is different from resource type' do
      error = assert_raises(Inferno::AssertionException) do
        @sequence.check_ndjson(@patient_export, 'Condition', true, 1)
      end

      assert_match(/^Resource type/, error.message)
    end

    it 'fails when output file has invalid resource' do
      invalid_patient_export = @patient_export.sub('"male"', '"001"')

      error = assert_raises(Inferno::AssertionException) do
        @sequence.check_ndjson(invalid_patient_export, 'Patient', true, 1)
      end

      assert_match(/invalid codes \[\\"001\\"\]/, error.message)
    end

    it 'succeeds when validate first line in output file having invalid resource' do
      invalid_patient_export = @patient_export.sub('"male"', '"001"')
      @sequence.check_ndjson(invalid_patient_export, 'Patient', false, 1)
    end
  end
end
