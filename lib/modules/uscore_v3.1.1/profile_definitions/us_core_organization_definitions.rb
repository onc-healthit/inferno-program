# frozen_string_literal: true

module Inferno
  module USCore311ProfileDefinitions
    class USCore311OrganizationSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [].freeze,
        slices: [
          {
            name: 'Organization.identifier:NPI',
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
            path: 'active'
          }.freeze,
          {
            path: 'name'
          }.freeze,
          {
            path: 'telecom'
          }.freeze,
          {
            path: 'address'
          }.freeze,
          {
            path: 'address.line'
          }.freeze,
          {
            path: 'address.city'
          }.freeze,
          {
            path: 'address.state'
          }.freeze,
          {
            path: 'address.postalCode'
          }.freeze,
          {
            path: 'address.country'
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
          system: 'http://hl7.org/fhir/ValueSet/address-use',
          path: 'address.use'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/address-type',
          path: 'address.type'
        }.freeze,
        {
          type: 'string',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-usps-state',
          path: 'address.state'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/contactentity-type',
          path: 'contact.purpose'
        }.freeze
      ].freeze
    end
  end
end
