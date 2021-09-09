# frozen_string_literal: true

module Inferno
  module USCore311ProfileDefinitions
    class USCore311ObservationLabSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [].freeze,
        slices: [
          {
            name: 'Observation.category:Laboratory',
            path: 'category',
            discriminator: {
              type: 'patternCodeableConcept',
              path: '',
              code: 'laboratory',
              system: 'http://terminology.hl7.org/CodeSystem/observation-category'
            }.freeze
          }.freeze
        ].freeze,
        elements: [
          {
            path: 'status'
          }.freeze,
          {
            path: 'category'
          }.freeze,
          {
            path: 'code'
          }.freeze,
          {
            path: 'subject'
          }.freeze,
          {
            path: 'effective'
          }.freeze,
          {
            path: 'value'
          }.freeze,
          {
            path: 'dataAbsentReason'
          }.freeze
        ].freeze
      }.freeze

      DELAYED_REFERENCES = [].freeze

      BINDINGS = [
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/observation-status',
          path: 'status'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/observation-codes',
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
