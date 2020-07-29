# frozen_string_literal: true

module Inferno
  # A validator that calls out to the HL7 validator API
  class HL7Validator
    DETAILS_FILTER = [
      %r{Sub-extension url 'introspect' is not defined by the Extension http://fhir-registry.smarthealthit.org/StructureDefinition/oauth-uris},
      %r{Sub-extension url 'revoke' is not defined by the Extension http://fhir-registry.smarthealthit.org/StructureDefinition/oauth-uris},
      /URL value .* does not resolve/
    ].freeze
    @validator_url = nil

    def initialize(validator_url)
      raise ArgumentError, 'Validator URL is unset' if validator_url.blank?

      @validator_url = validator_url
    end

    def validate(resource, fhir_models_klass, profile_url = nil)
      profile_url ||= fhir_models_klass::Definitions.resource_definition(resource.resourceType).url

      Inferno.logger.info("Validating #{resource.resourceType} resource with id #{resource.id}")
      Inferno.logger.info("POST #{@validator_url}/validate?profile=#{profile_url}")

      result = RestClient.post "#{@validator_url}/validate", resource.source_contents, params: { profile: profile_url }
      outcome = fhir_models_klass.from_contents(result.body)

      issues_by_severity(outcome.issue)
    end

    private

    def issues_by_severity(issues)
      errors = []
      warnings = []
      information = []

      issues.each do |iss|
        if iss.severity == 'information' || iss.code == 'code-invalid' || DETAILS_FILTER.any? { |filter| filter.match?(iss&.details&.text) }
          information << "#{issue_location(iss)}: #{iss&.details&.text}"
        elsif iss.severity == 'warning'
          warnings << "#{issue_location(iss)}: #{iss&.details&.text}"
        else
          errors << "#{issue_location(iss)}: #{iss&.details&.text}"
        end
      end

      {
        errors: errors,
        warnings: warnings,
        information: information
      }
    end

    def issue_location(issue)
      if issue.respond_to?(:expression)
        issue&.expression&.join(', ')
      else
        issue&.location&.join(', ')
      end
    end
  end
end
