# frozen_string_literal: true

module Inferno
  module USCore311ProfileDefinitions
    class USCore311PractitionerroleSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [].freeze,
        slices: [].freeze,
        elements: [
          {
            path: 'practitioner'
          }.freeze,
          {
            path: 'organization'
          }.freeze,
          {
            path: 'code'
          }.freeze,
          {
            path: 'specialty'
          }.freeze,
          {
            path: 'location'
          }.freeze,
          {
            path: 'telecom'
          }.freeze,
          {
            path: 'telecom.system'
          }.freeze,
          {
            path: 'telecom.value'
          }.freeze,
          {
            path: 'endpoint'
          }.freeze
        ].freeze
      }.freeze

      DELAYED_REFERENCES = [
        {
          path: 'practitioner',
          resources: [
            'Practitioner'
          ].freeze
        }.freeze,
        {
          path: 'organization',
          resources: [
            'Organization'
          ].freeze
        }.freeze
      ].freeze

      BINDINGS = [
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-provider-role',
          path: 'code'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-provider-specialty',
          path: 'specialty'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/contact-point-system',
          path: 'telecom.system'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/contact-point-use',
          path: 'telecom.use'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/days-of-week',
          path: 'availableTime.daysOfWeek'
        }.freeze
      ].freeze
    end
  end
end
