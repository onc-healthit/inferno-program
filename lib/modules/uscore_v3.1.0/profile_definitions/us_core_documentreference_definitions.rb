# frozen_string_literal: true

module Inferno
  module USCore310ProfileDefinitions
    class USCore310DocumentreferenceSequenceDefinitions
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
            path: 'author',
            resource_types: [
              'Practitioner',
              'Organization',
              'Patient'
            ]
          },
          {
            path: 'custodian',
            resource_types: [
              'Organization'
            ]
          },
          {
            path: 'context.encounter',
            resource_types: [
              'Encounter'
            ]
          }
        ],
        elements: [
          {
            path: 'identifier'
          },
          {
            path: 'status'
          },
          {
            path: 'type'
          },
          {
            path: 'category'
          },
          {
            path: 'date'
          },
          {
            path: 'content'
          },
          {
            path: 'content.attachment'
          },
          {
            path: 'content.attachment.contentType'
          },
          {
            path: 'content.attachment.data'
          },
          {
            path: 'content.attachment.url'
          },
          {
            path: 'content.format'
          },
          {
            path: 'context'
          },
          {
            path: 'context.period'
          }
        ]
      }.freeze

      DELAYED_REFERENCES = [
        {
          path: 'author',
          resources: [
            'Practitioner',
            'Organization'
          ]
        },
        {
          path: 'custodian',
          resources: [
            'Organization'
          ]
        },
        {
          path: 'context.encounter',
          resources: [
            'Encounter'
          ]
        }
      ].freeze

      BINDINGS = [
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/document-reference-status',
          path: 'status'
        },
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/composition-status',
          path: 'docStatus'
        },
        {
          type: 'CodeableConcept',
          strength: 'required',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-documentreference-type',
          path: 'type'
        },
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-documentreference-category',
          path: 'category'
        },
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/document-relationship-type',
          path: 'relatesTo.code'
        },
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/security-labels',
          path: 'securityLabel'
        },
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/mimetypes',
          path: 'content.attachment.contentType'
        },
        {
          type: 'Coding',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/formatcodes',
          path: 'content.format'
        }
      ].freeze
    end
  end
end
