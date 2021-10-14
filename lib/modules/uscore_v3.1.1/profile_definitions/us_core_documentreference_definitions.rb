# frozen_string_literal: true

module Inferno
  module USCore311ProfileDefinitions
    class USCore311DocumentreferenceSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [].freeze,
        slices: [].freeze,
        elements: [
          {
            path: 'identifier'
          }.freeze,
          {
            path: 'status'
          }.freeze,
          {
            path: 'type'
          }.freeze,
          {
            path: 'category'
          }.freeze,
          {
            path: 'subject'
          }.freeze,
          {
            path: 'date'
          }.freeze,
          {
            path: 'author'
          }.freeze,
          {
            path: 'custodian'
          }.freeze,
          {
            path: 'content'
          }.freeze,
          {
            path: 'content.attachment'
          }.freeze,
          {
            path: 'content.attachment.contentType'
          }.freeze,
          {
            path: 'content.format'
          }.freeze,
          {
            path: 'context'
          }.freeze,
          {
            path: 'context.encounter'
          }.freeze,
          {
            path: 'context.period'
          }.freeze
        ].freeze
      }.freeze

      DELAYED_REFERENCES = [
        {
          path: 'author',
          resources: [
            'Practitioner',
            'Organization'
          ].freeze
        }.freeze,
        {
          path: 'custodian',
          resources: [
            'Organization'
          ].freeze
        }.freeze,
        {
          path: 'context.encounter',
          resources: [
            'Encounter'
          ].freeze
        }.freeze
      ].freeze

      BINDINGS = [
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/document-reference-status',
          path: 'status'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/composition-status',
          path: 'docStatus'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'required',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-documentreference-type',
          path: 'type'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-documentreference-category',
          path: 'category'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/document-relationship-type',
          path: 'relatesTo.code'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/security-labels',
          path: 'securityLabel'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/mimetypes',
          path: 'content.attachment.contentType'
        }.freeze,
        {
          type: 'Coding',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/formatcodes',
          path: 'content.format'
        }.freeze
      ].freeze
    end
  end
end
