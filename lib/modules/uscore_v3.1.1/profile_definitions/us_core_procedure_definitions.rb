# frozen_string_literal: true

module Inferno
  module USCore311ProfileDefinitions
    class USCore311ProcedureSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [],
        slices: [],
        references: [
          {
            path: 'subject',
            resource_types: [
              'Patient'
            ]
          }
        ],
        elements: [
          {
            path: 'status'
          },
          {
            path: 'code'
          },
          {
            path: 'performedDateTime'
          },
          {
            path: 'performedPeriod'
          },
          {
            path: 'performed'
          }
        ]
      }.freeze

      DELAYED_REFERENCES = [].freeze

      BINDINGS = [
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/event-status',
          path: 'status'
        },
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-procedure-code',
          path: 'code'
        }
      ].freeze
    end
  end
end
