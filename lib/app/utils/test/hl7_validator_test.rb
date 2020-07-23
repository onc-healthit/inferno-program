# frozen_string_literal: true

require_relative '../../../../test/test_helper'

describe Inferno::HL7Validator do
  before do
    @validator_url = 'http://localhost:8888'
    @validator = Inferno::HL7Validator.new(@validator_url)
  end

  describe 'issues_by_severity tests' do
    before do
      @resource = FHIR::CapabilityStatement.new
      @profile = FHIR::Definitions.resource_definition(@resource.resourceType).url
    end

    it 'removes excluded errors' do
      outcome = load_fixture('hl7_validator_operation_outcome')

      stub_request(:post, @validator_url + '/validate')
        .with(
          query: { 'profile': @profile },
          body: @resource.to_json
        )
        .to_return(
          status: 200,
          body: outcome
        )

      result = @validator.validate(@resource, FHIR, @profile)
      assert result[:errors].length == 1
    end
  end
end
