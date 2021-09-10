# frozen_string_literal: true

module Inferno
  module USCore311ProfileDefinitions
    class USCore311ImplantableDeviceSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [].freeze,
        slices: [].freeze,
        elements: [
          {
            path: 'udiCarrier'
          }.freeze,
          {
            path: 'udiCarrier.deviceIdentifier'
          }.freeze,
          {
            path: 'distinctIdentifier'
          }.freeze,
          {
            path: 'manufactureDate'
          }.freeze,
          {
            path: 'expirationDate'
          }.freeze,
          {
            path: 'lotNumber'
          }.freeze,
          {
            path: 'serialNumber'
          }.freeze,
          {
            path: 'type'
          }.freeze,
          {
            path: 'patient'
          }.freeze
        ].freeze
      }.freeze

      DELAYED_REFERENCES = [].freeze

      BINDINGS = [
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/udi-entry-type',
          path: 'udiCarrier.entryType'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/device-status',
          path: 'status'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/device-status-reason',
          path: 'statusReason'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/device-nametype',
          path: 'deviceName.type'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/device-kind',
          path: 'type'
        }.freeze
      ].freeze
    end
  end
end
