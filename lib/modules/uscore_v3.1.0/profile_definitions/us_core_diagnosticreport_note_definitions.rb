# frozen_string_literal: true

module Inferno
  module USCore310ProfileDefinitions
    class USCore310DiagnosticreportNoteSequenceDefinitions
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
            path: 'encounter',
            resource_types: [
              'Encounter'
            ]
          },
          {
            path: 'performer',
            resource_types: [
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
          },
          {
            path: 'presentedForm'
          }
        ]
      }.freeze

      DELAYED_REFERENCES = [
        {
          path: 'encounter',
          resources: [
            'Encounter'
          ]
        },
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
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-diagnosticreport-category',
          path: 'category'
        },
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-diagnosticreport-report-and-note-codes',
          path: 'code'
        }
      ].freeze
    end
  end
end
