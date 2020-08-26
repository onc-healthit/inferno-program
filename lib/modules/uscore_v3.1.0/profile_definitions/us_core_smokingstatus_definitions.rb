# frozen_string_literal: true

module Inferno
  module USCore310ProfileDefinitions
    class USCore310SmokingstatusSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [],
        slices: [
          {
            name: 'Observation.value[x]:valueCodeableConcept',
            path: 'value',
            discriminator: {
              type: 'type',
              code: 'CodeableConcept'
            }
          }
        ],
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
            path: 'issued'
          }
        ]
      }.freeze

      DELAYED_REFERENCES = [].freeze

      BINDINGS = [
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-observation-smoking-status-status',
          path: 'status'
        },
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-smoking-status-observation-codes',
          path: 'code'
        },
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-observation-smokingstatus',
          path: 'value'
        },
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/data-absent-reason',
          path: 'dataAbsentReason'
        },
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/observation-interpretation',
          path: 'interpretation'
        },
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/data-absent-reason',
          path: 'component.dataAbsentReason'
        },
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/observation-interpretation',
          path: 'component.interpretation'
        }
      ].freeze
    end
  end
end
