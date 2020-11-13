# frozen_string_literal: true

module Inferno
  module USCore311ProfileDefinitions
    class USCore311CareteamSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [],
        slices: [],
        references: [
          {
            path: 'subject',
            resource_types: [
              'Patient'
            ]
          },
          {
            path: 'participant.member',
            resource_types: [
              'Patient',
              'Practitioner',
              'Organization'
            ]
          }
        ],
        elements: [
          {
            path: 'status'
          },
          {
            path: 'participant'
          },
          {
            path: 'participant.role'
          }
        ]
      }.freeze

      DELAYED_REFERENCES = [
        {
          path: 'participant.member',
          resources: [
            'Practitioner',
            'Organization'
          ]
        }
      ].freeze

      BINDINGS = [
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/care-team-status',
          path: 'status'
        },
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-careteam-provider-roles',
          path: 'participant.role'
        }
      ].freeze
    end
  end
end
