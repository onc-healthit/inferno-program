# frozen_string_literal: true

module Inferno
  module USCore311ProfileDefinitions
    class USCore311ImmunizationSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [].freeze,
        slices: [].freeze,
        elements: [
          {
            path: 'status'
          }.freeze,
          {
            path: 'statusReason'
          }.freeze,
          {
            path: 'vaccineCode'
          }.freeze,
          {
            path: 'patient'
          }.freeze,
          {
            path: 'occurrence'
          }.freeze,
          {
            path: 'primarySource'
          }.freeze
        ].freeze
      }.freeze

      DELAYED_REFERENCES = [].freeze

      BINDINGS = [
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/immunization-status',
          path: 'status'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-vaccines-cvx',
          path: 'vaccineCode'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/immunization-function',
          path: 'performer.function'
        }.freeze
      ].freeze
    end
  end
end
