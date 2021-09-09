# frozen_string_literal: true

module Inferno
  module USCore311ProfileDefinitions
    class USCore311EncounterSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [].freeze,
        slices: [].freeze,
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
            path: 'status'
          }.freeze,
          {
            path: 'class'
          }.freeze,
          {
            path: 'type'
          }.freeze,
          {
            path: 'subject'
          }.freeze,
          {
            path: 'participant'
          }.freeze,
          {
            path: 'participant.type'
          }.freeze,
          {
            path: 'participant.period'
          }.freeze,
          {
            path: 'participant.individual'
          }.freeze,
          {
            path: 'period'
          }.freeze,
          {
            path: 'reasonCode'
          }.freeze,
          {
            path: 'hospitalization'
          }.freeze,
          {
            path: 'hospitalization.dischargeDisposition'
          }.freeze,
          {
            path: 'location'
          }.freeze,
          {
            path: 'location.location'
          }.freeze
        ].freeze
      }.freeze

      DELAYED_REFERENCES = [
        {
          path: 'participant.individual',
          resources: [
            'Practitioner'
          ].freeze
        }.freeze
      ].freeze

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
          system: 'http://hl7.org/fhir/ValueSet/encounter-status',
          path: 'status'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/encounter-status',
          path: 'statusHistory.status'
        }.freeze,
        {
          type: 'Coding',
          strength: 'extensible',
          system: 'http://terminology.hl7.org/ValueSet/v3-ActEncounterCode',
          path: 'local_class'
        }.freeze,
        {
          type: 'Coding',
          strength: 'extensible',
          system: 'http://terminology.hl7.org/ValueSet/v3-ActEncounterCode',
          path: 'classHistory.local_class'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-encounter-type',
          path: 'type'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/encounter-participant-type',
          path: 'participant.type'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/encounter-location-status',
          path: 'location.status'
        }.freeze
      ].freeze
    end
  end
end
