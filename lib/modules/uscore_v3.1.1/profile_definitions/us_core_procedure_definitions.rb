# frozen_string_literal: true

module Inferno
  module USCore311ProfileDefinitions
    class USCore311ProcedureSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [].freeze,
        slices: [].freeze,
        elements: [
          {
            path: 'status'
          }.freeze,
          {
            path: 'code'
          }.freeze,
          {
            path: 'subject'
          }.freeze,
          {
            path: 'performed'
          }.freeze
        ].freeze
      }.freeze

      DELAYED_REFERENCES = [].freeze

      BINDINGS = [
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/event-status',
          path: 'status'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-procedure-code',
          path: 'code'
        }.freeze
      ].freeze
    end
  end
end
