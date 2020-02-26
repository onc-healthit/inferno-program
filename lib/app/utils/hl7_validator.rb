# frozen_string_literal: true

module Inferno
  # A validator that calls out to the HL7 validator API
  class HL7Validator
    @validator_url = nil

    def initialize(validator_url)
      raise ArgumentError, 'Validator URL is unset' if validator_url.blank?

      @validator_url = validator_url
    end

    def validate(resource, fhir_models_klass, profile_url = nil)
      profile_url ||= fhir_models_klass::Definitions.resource_definition(resource.resourceType).url

      Inferno.logger.info("Validating #{resource.resourceType} resource with id #{resource.id}")
      Inferno.logger.info("POST #{@validator_url}/validate?profile=#{profile_url}")

      result = RestClient.post "#{@validator_url}/validate", resource.to_json, params: { profile: profile_url }
      outcome = fhir_models_klass.from_contents(result.body)
      fatals = issues_by_severity(outcome.issue, 'fatal')
      errors = issues_by_severity(outcome.issue, 'error')
      warnings = issues_by_severity(outcome.issue, 'warning')
      information = issues_by_severity(outcome.issue, 'information')
      {
        errors: fatals.concat(errors).reject(&:empty?),
        warnings: warnings,
        information: information
      }
    end

    private

    def issues_by_severity(issues, severity)
      issues.reject { |i| i.code == 'code-invalid' }
        .select { |i| i.severity == severity }
        .map { |iss| "#{issue_location(iss)}: #{iss&.details&.text}" }
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
