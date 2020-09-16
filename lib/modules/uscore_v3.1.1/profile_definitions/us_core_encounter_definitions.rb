# frozen_string_literal: true

module Inferno
  module USCore311ProfileDefinitions
    class USCore311EncounterSequenceDefinitions
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
            path: 'participant.individual',
            resource_types: [
              'Practitioner'
            ]
          },
          {
            path: 'location.location',
            resource_types: []
          }
        ],
        elements: [
          {
            path: 'identifier'
          },
          {
            path: 'identifier.system'
          },
          {
            path: 'identifier.value'
          },
          {
            path: 'status'
          },
          {
            path: 'class'
          },
          {
            path: 'type'
          },
          {
            path: 'participant'
          },
          {
            path: 'participant.type'
          },
          {
            path: 'participant.period'
          },
          {
            path: 'period'
          },
          {
            path: 'reasonCode'
          },
          {
            path: 'hospitalization'
          },
          {
            path: 'hospitalization.dischargeDisposition'
          },
          {
            path: 'location'
          }
        ]
      }.freeze

      DELAYED_REFERENCES = [
        {
          path: 'participant.individual',
          resources: [
            'Practitioner'
          ]
        }
      ].freeze

      BINDINGS = [
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/identifier-use',
          path: 'identifier.use'
        },
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/identifier-type',
          path: 'identifier.type'
        },
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/encounter-status',
          path: 'status'
        },
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/encounter-status',
          path: 'statusHistory.status'
        },
        {
          type: 'Coding',
          strength: 'extensible',
          system: 'http://terminology.hl7.org/ValueSet/v3-ActEncounterCode',
          path: 'local_class'
        },
        {
          type: 'Coding',
          strength: 'extensible',
          system: 'http://terminology.hl7.org/ValueSet/v3-ActEncounterCode',
          path: 'classHistory.local_class'
        },
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-encounter-type',
          path: 'type'
        },
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/encounter-participant-type',
          path: 'participant.type'
        },
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/encounter-location-status',
          path: 'location.status'
        }
      ].freeze
    end
  end
end
