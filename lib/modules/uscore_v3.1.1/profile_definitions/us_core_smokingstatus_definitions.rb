# frozen_string_literal: true

module Inferno
  module USCore311ProfileDefinitions
    class USCore311SmokingstatusSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [].freeze,
        slices: [
          {
            name: 'Observation.value[x]:valueCodeableConcept',
            path: 'value',
            discriminator: {
              type: 'type',
              code: 'CodeableConcept'
            }.freeze
          }.freeze
        ].freeze,
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
            path: 'issued'
          }.freeze
        ].freeze
      }.freeze

      DELAYED_REFERENCES = [].freeze

      BINDINGS = [
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-observation-smoking-status-status',
          path: 'status'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-smoking-status-observation-codes',
          path: 'code'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/data-absent-reason',
          path: 'dataAbsentReason'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/observation-interpretation',
          path: 'interpretation'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/data-absent-reason',
          path: 'component.dataAbsentReason'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/observation-interpretation',
          path: 'component.interpretation'
        }.freeze
      ].freeze
    end
  end
end
