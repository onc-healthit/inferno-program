# frozen_string_literal: true

module Inferno
  module USCore310ProfileDefinitions
    class USCore311MedicationrequestSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [],
        slices: [],
        references: [
          {
            path: 'reported',
            resource_types: [
              'Patient',
              'Practitioner',
              'Organization'
            ]
          },
          {
            path: 'medication',
            resource_types: [
              'Medication'
            ]
          },
          {
            path: 'subject',
            resource_types: [
              'Patient'
            ]
          },
          {
            path: 'encounter',
            resource_types: []
          },
          {
            path: 'requester',
            resource_types: [
              'Practitioner',
              'Organization',
              'Patient'
            ]
          }
        ],
        elements: [
          {
            path: 'status'
          },
          {
            path: 'intent'
          },
          {
            path: 'authoredOn'
          },
          {
            path: 'dosageInstruction'
          },
          {
            path: 'dosageInstruction.text'
          }
        ]
      }.freeze

      DELAYED_REFERENCES = [
        {
          path: 'requester',
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
          system: 'http://hl7.org/fhir/ValueSet/medicationrequest-status',
          path: 'status'
        },
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/medicationrequest-intent',
          path: 'intent'
        },
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/request-priority',
          path: 'priority'
        },
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-medication-codes',
          path: 'medication'
        }
      ].freeze
    end
  end
end
