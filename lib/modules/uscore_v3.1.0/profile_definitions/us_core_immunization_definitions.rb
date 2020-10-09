# frozen_string_literal: true

module Inferno
  module USCore310ProfileDefinitions
    class USCore310ImmunizationSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [],
        slices: [],
        references: [
          {
            path: 'patient',
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
            path: 'statusReason'
          },
          {
            path: 'vaccineCode'
          },
          {
            path: 'occurrenceDateTime'
          },
          {
            path: 'occurrenceString'
          },
          {
            path: 'occurrence'
          },
          {
            path: 'primarySource'
          }
        ]
      }.freeze

      DELAYED_REFERENCES = [].freeze

      BINDINGS = [
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/immunization-status',
          path: 'status'
        },
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-vaccines-cvx',
          path: 'vaccineCode'
        },
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/immunization-function',
          path: 'performer.function'
        }
      ].freeze
    end
  end
end
