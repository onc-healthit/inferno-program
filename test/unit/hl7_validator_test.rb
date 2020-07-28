# frozen_string_literal: true

require_relative '../test_helper'

describe Inferno::HL7Validator do
  before do
    @validator_url = 'http://example.com:8080'
    @validator = Inferno::HL7Validator.new(@validator_url)
  end

  describe 'Validating a good resource' do
    before do
      @resource = FHIR::CapabilityStatement.new
      @profile = FHIR::Definitions.resource_definition(@resource.resourceType).url
    end

    it "Shouldn't pass back any messages" do
      patient = FHIR::Patient.new
      stub_request(:post, "#{@validator_url}/validate")
        .with(
          query: { profile: 'http://hl7.org/fhir/StructureDefinition/Patient' },
          body: patient.to_json
        )
        .to_return(status: 200, body: load_fixture('validator_good_response'))
      result = @validator.validate(patient, FHIR)

      assert_empty result[:errors]
      assert_empty result[:warnings]
      assert_empty result[:information]
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
      assert result[:errors].length == 2
      assert result[:warnings].length == 1
      assert result[:information].length == 5
    end
  end
end
