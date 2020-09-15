# frozen_string_literal: true

module Inferno
  module USCore310ProfileDefinitions
    class USCore311ConditionSequenceDefinitions
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
            path: 'clinicalStatus'
          },
          {
            path: 'verificationStatus'
          },
          {
            path: 'category'
          },
          {
            path: 'code'
          }
        ]
      }.freeze

      DELAYED_REFERENCES = [].freeze

      BINDINGS = [
        {
          type: 'CodeableConcept',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/condition-clinical',
          path: 'clinicalStatus'
        },
        {
          type: 'CodeableConcept',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/condition-ver-status',
          path: 'verificationStatus'
        },
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-condition-category',
          path: 'category'
        },
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-condition-code',
          path: 'code'
        }
      ].freeze
    end
  end
end
