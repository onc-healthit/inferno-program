# frozen_string_literal: true

module Inferno
  module USCore310ProfileDefinitions
    class USCore310DiagnosticreportLabSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [],
        slices: [
          {
            name: 'DiagnosticReport.category:LaboratorySlice',
            path: 'category',
            discriminator: {
              type: 'patternCodeableConcept',
              path: '',
              code: 'LAB',
              system: 'http://terminology.hl7.org/CodeSystem/v2-0074'
            }
          }
        ],
        references: [
          {
            path: 'subject',
            resource_types: [
              'Patient'
            ]
          },
          {
            path: 'performer',
            resource_types: [
              'Practitioner',
              'Organization'
            ]
          },
          {
            path: 'result',
            resource_types: [
              'Observation'
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
            path: 'effective'
          },
          {
            path: 'issued'
          }
        ]
      }.freeze

      DELAYED_REFERENCES = [
        {
          path: 'performer',
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
          system: 'http://hl7.org/fhir/ValueSet/diagnostic-report-status',
          path: 'status'
        },
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-diagnosticreport-lab-codes',
          path: 'code'
        }
      ].freeze
    end
  end
end
