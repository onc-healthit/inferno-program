# frozen_string_literal: true

module Inferno
  module USCore310ProfileDefinitions
    class USCore310BpSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [],
        slices: [
          {
            name: 'Observation.category:VSCat',
            path: 'category',
            discriminator: {
              type: 'value',
              values: [
                {
                  path: 'coding.code',
                  value: 'vital-signs'
                },
                {
                  path: 'coding.system',
                  value: 'http://terminology.hl7.org/CodeSystem/observation-category'
                }
              ]
            }
          }
        ],
        references: [
          {
            path: 'subject',
            resource_types: []
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
            path: 'category.coding'
          },
          {
            path: 'category.coding.system',
            fixed_value: 'http://terminology.hl7.org/CodeSystem/observation-category'
          },
          {
            path: 'category.coding.code',
            fixed_value: 'vital-signs'
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
          system: 'http://hl7.org/fhir/ValueSet/observation-vitalsignresult',
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
          system: 'http://hl7.org/fhir/ValueSet/observation-vitalsignresult',
          path: 'component.code'
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
        },
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/observation-vitalsignresult',
          path: 'component.code'
        },
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/quantity-comparator',
          path: 'component.value.comparator'
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
        },
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/observation-vitalsignresult',
          path: 'component.code'
        },
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/quantity-comparator',
          path: 'component.value.comparator'
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
