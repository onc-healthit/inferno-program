# frozen_string_literal: true

module Inferno
  module USCore311ProfileDefinitions
    class USCore311CareteamSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [].freeze,
        slices: [].freeze,
        elements: [
          {
            path: 'status'
          }.freeze,
          {
            path: 'subject'
          }.freeze,
          {
            path: 'participant'
          }.freeze,
          {
            path: 'participant.role'
          }.freeze,
          {
            path: 'participant.member'
          }.freeze
        ].freeze
      }.freeze

      DELAYED_REFERENCES = [
        {
          path: 'participant.member',
          resources: [
            'Practitioner',
            'Organization'
          ].freeze
        }.freeze
      ].freeze

      BINDINGS = [
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/care-team-status',
          path: 'status'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-careteam-provider-roles',
          path: 'participant.role'
        }.freeze
      ].freeze
    end
  end
end
