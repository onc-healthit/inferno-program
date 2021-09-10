# frozen_string_literal: true

module Inferno
  module USCore311ProfileDefinitions
    class USCore311PractitionerSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [].freeze,
        slices: [
          {
            name: 'Practitioner.identifier:NPI',
            path: 'identifier',
            discriminator: {
              type: 'patternIdentifier',
              path: '',
              system: 'http://hl7.org/fhir/sid/us-npi'
            }.freeze
          }.freeze
        ].freeze,
        elements: [
          {
            path: 'identifier'
          }.freeze,
          {
            path: 'identifier.system'
          }.freeze,
          {
            path: 'identifier.value'
          }.freeze,
          {
            path: 'name'
          }.freeze,
          {
            path: 'name.family'
          }.freeze
        ].freeze
      }.freeze

      DELAYED_REFERENCES = [].freeze

      BINDINGS = [
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/identifier-use',
          path: 'identifier.use'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/identifier-type',
          path: 'identifier.type'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/name-use',
          path: 'name.use'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/administrative-gender',
          path: 'gender'
        }.freeze
      ].freeze
    end
  end
end
