# frozen_string_literal: true

module Inferno
  module USCore310ProfileDefinitions
    class USCore310PractitionerroleSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [],
        slices: [],
        references: [
          {
            path: 'practitioner',
            resource_types: [
              'Practitioner'
            ]
          },
          {
            path: 'organization',
            resource_types: [
              'Organization'
            ]
          },
          {
            path: 'location',
            resource_types: []
          },
          {
            path: 'endpoint',
            resource_types: []
          }
        ],
        elements: [
          {
            path: 'code'
          },
          {
            path: 'specialty'
          },
          {
            path: 'telecom'
          },
          {
            path: 'telecom.system'
          },
          {
            path: 'telecom.value'
          }
        ]
      }.freeze

      DELAYED_REFERENCES = [
        {
          path: 'practitioner',
          resources: [
            'Practitioner'
          ]
        },
        {
          path: 'organization',
          resources: [
            'Organization'
          ]
        }
      ].freeze

      BINDINGS = [
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-provider-role',
          path: 'code'
        },
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-provider-specialty',
          path: 'specialty'
        },
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/contact-point-system',
          path: 'telecom.system'
        },
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/contact-point-use',
          path: 'telecom.use'
        },
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/days-of-week',
          path: 'availableTime.daysOfWeek'
        }
      ].freeze
    end
  end
end
