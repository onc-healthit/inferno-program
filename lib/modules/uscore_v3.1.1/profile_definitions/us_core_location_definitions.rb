# frozen_string_literal: true

module Inferno
  module USCore311ProfileDefinitions
    class USCore311LocationSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [].freeze,
        slices: [].freeze,
        elements: [
          {
            path: 'status'
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
            path: 'managingOrganization'
          }.freeze
        ].freeze
      }.freeze

      DELAYED_REFERENCES = [
        {
          path: 'managingOrganization',
          resources: [
            'Organization'
          ].freeze
        }.freeze
      ].freeze

      BINDINGS = [
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/location-status',
          path: 'status'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/location-mode',
          path: 'mode'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://terminology.hl7.org/ValueSet/v3-ServiceDeliveryLocationRoleType',
          path: 'type'
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
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/days-of-week',
          path: 'hoursOfOperation.daysOfWeek'
        }.freeze
      ].freeze
    end
  end
end
