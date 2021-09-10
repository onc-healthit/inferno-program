# frozen_string_literal: true

module Inferno
  module USCore311ProfileDefinitions
    class USCore311DiagnosticreportNoteSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [].freeze,
        slices: [].freeze,
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
            path: 'encounter'
          }.freeze,
          {
            path: 'effective'
          }.freeze,
          {
            path: 'issued'
          }.freeze,
          {
            path: 'performer'
          }.freeze,
          {
            path: 'presentedForm'
          }.freeze
        ].freeze
      }.freeze

      DELAYED_REFERENCES = [
        {
          path: 'encounter',
          resources: [
            'Encounter'
          ].freeze
        }.freeze,
        {
          path: 'performer',
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
          system: 'http://hl7.org/fhir/ValueSet/diagnostic-report-status',
          path: 'status'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-diagnosticreport-category',
          path: 'category'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-diagnosticreport-report-and-note-codes',
          path: 'code'
        }.freeze
      ].freeze
    end
  end
end
