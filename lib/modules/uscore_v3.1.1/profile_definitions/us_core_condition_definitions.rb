# frozen_string_literal: true

module Inferno
  module USCore311ProfileDefinitions
    class USCore311ConditionSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [].freeze,
        slices: [].freeze,
        elements: [
          {
            path: 'clinicalStatus'
          }.freeze,
          {
            path: 'verificationStatus'
          }.freeze,
          {
            path: 'category'
          }.freeze,
          {
            path: 'code'
          }.freeze,
          {
            path: 'subject'
          }.freeze
        ].freeze
      }.freeze

      DELAYED_REFERENCES = [].freeze

      BINDINGS = [
        {
          type: 'CodeableConcept',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/condition-clinical',
          path: 'clinicalStatus'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/condition-ver-status',
          path: 'verificationStatus'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-condition-category',
          path: 'category'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-condition-code',
          path: 'code'
        }.freeze
      ].freeze
    end
  end
end
