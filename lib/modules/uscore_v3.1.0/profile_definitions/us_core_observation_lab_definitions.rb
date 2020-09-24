# frozen_string_literal: true

module Inferno
  module USCore310ProfileDefinitions
    class USCore310ObservationLabSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [],
        slices: [
          {
            name: 'Observation.category:Laboratory',
            path: 'category',
            discriminator: {
              type: 'patternCodeableConcept',
              path: '',
              code: 'laboratory',
              system: 'http://terminology.hl7.org/CodeSystem/observation-category'
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
            path: 'category'
          },
          {
            path: 'code'
          },
          {
            path: 'effectiveDateTime'
          },
          {
            path: 'effectivePeriod'
          },
          {
            path: 'effective'
          },
          {
            path: 'valueQuantity'
          },
          {
            path: 'valueCodeableConcept'
          },
          {
            path: 'valueString'
          },
          {
            path: 'valueBoolean'
          },
          {
            path: 'valueInteger'
          },
          {
            path: 'valueRange'
          },
          {
            path: 'valueRatio'
          },
          {
            path: 'valueSampledData'
          },
          {
            path: 'valueTime'
          },
          {
            path: 'valueDateTime'
          },
          {
            path: 'valuePeriod'
          },
          {
            path: 'value'
          },
          {
            path: 'dataAbsentReason'
          }
        ]
      }.freeze

      DELAYED_REFERENCES = [].freeze

      BINDINGS = [
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/observation-status',
          path: 'status'
        },
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/observation-codes',
          path: 'code'
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
