# frozen_string_literal: true

require_relative 'walk'

module Inferno
  # A validator that calls out to the HL7 validator API
  class HL7Validator
    ISSUE_DETAILS_FILTER = [
      # This will be fixed with https://jira.hl7.org/browse/FHIR-28099
      %r{^Sub-extension url 'introspect' is not defined by the Extension http://fhir-registry\.smarthealthit\.org/StructureDefinition/oauth-uris$},
      # This will be fixed with https://jira.hl7.org/browse/FHIR-28099
      %r{^Sub-extension url 'revoke' is not defined by the Extension http://fhir-registry\.smarthealthit\.org/StructureDefinition/oauth-uris$},
      # Invalid invariant in FHIR v4.0.1
      /^vs-1: 'if Observation\.effective\[x\] is dateTime and has a value then that value shall be precise to the day'/,
      # Invalid invariant in US Core v3.1.1
      /^us-core-1: 'Datetime must be at least to day.'/
    ].freeze
    @validator_url = nil
    attr_accessor :expected_version

    def initialize(validator_url, expected_version = nil)
      raise ArgumentError, 'Validator URL is unset' if validator_url.blank?

      @validator_url = validator_url
      @expected_version = expected_version
    end

    def validate(resource, fhir_models_klass, profile_url = nil)
      profile_url ||= fhir_models_klass::Definitions.resource_definition(resource.resourceType).url

      Inferno.logger.info("Validating #{resource.resourceType} resource with id #{resource.id}")
      Inferno.logger.info("POST #{@validator_url}/validate?profile=#{profile_url}")

      result = RestClient.post "#{@validator_url}/validate", resource.source_contents, params: { profile: profile_url }
      outcome = fhir_models_klass.from_contents(result.body)

      issues_by_severity(outcome.issue)
    end

    # @return [String] the version of the validator currently being used or nil
    #   if unable to reach the /version endpoint
    def version
      Inferno.logger.info('Fetching validator version')
      Inferno.logger.info("GET #{@validator_url}/version")

      result = RestClient.get "#{@validator_url}/version"
      result.body
    rescue StandardError
      Inferno.logger.error('Unable to reach the /version validator endpoint. Please ensure that the validator is up to date.')
      nil
    end

    # @return [Boolean] true if the 'requested' version from the config file matches the version
    # returned by the external service, false otherwise.
    def version_match?
      @expected_version == version
    end

    private

    def issues_by_severity(issues)
      errors = []
      warnings = []
      information = []

      issues.each do |iss|
        if iss.severity == 'information' || iss.code == 'code-invalid' || ISSUE_DETAILS_FILTER.any? { |filter| filter.match?(iss&.details&.text) }
          information << issue_message(iss)
        elsif iss.severity == 'warning'
          warnings << issue_message(iss)
        else
          errors << issue_message(iss)
        end
      end

      {
        errors: errors,
        warnings: warnings,
        information: information
      }
    end

    def issue_message(issue)
      location = if issue.respond_to?(:expression)
                   issue&.expression&.join(', ')
                 else
                   issue&.location&.join(', ')
                 end

      "#{location}: #{issue&.details&.text}"
    end
  end
end
