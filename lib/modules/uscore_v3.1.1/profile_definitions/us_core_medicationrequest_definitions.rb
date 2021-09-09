# frozen_string_literal: true

module Inferno
  module USCore311ProfileDefinitions
    class USCore311MedicationrequestSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [].freeze,
        slices: [].freeze,
        elements: [
          {
            path: 'status'
          }.freeze,
          {
            path: 'intent'
          }.freeze,
          {
            path: 'reported'
          }.freeze,
          {
            path: 'medication'
          }.freeze,
          {
            path: 'subject'
          }.freeze,
          {
            path: 'encounter'
          }.freeze,
          {
            path: 'authoredOn'
          }.freeze,
          {
            path: 'requester'
          }.freeze,
          {
            path: 'dosageInstruction'
          }.freeze,
          {
            path: 'dosageInstruction.text'
          }.freeze
        ].freeze
      }.freeze

      DELAYED_REFERENCES = [
        {
          path: 'requester',
          resources: [
            'Practitioner',
            'Organization'
          ].freeze
        }.freeze
      ].freeze

      BINDINGS = [
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/medicationrequest-status',
          path: 'status'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/medicationrequest-intent',
          path: 'intent'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/request-priority',
          path: 'priority'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-medication-codes',
          path: 'medication'
        }.freeze
      ].freeze
    end
  end
end
