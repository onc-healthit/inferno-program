# frozen_string_literal: true

module Inferno
  module USCore311ProfileDefinitions
    class USCore311DiagnosticreportLabSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [].freeze,
        slices: [
          {
            name: 'DiagnosticReport.category:LaboratorySlice',
            path: 'category',
            discriminator: {
              type: 'patternCodeableConcept',
              path: '',
              code: 'LAB',
              system: 'http://terminology.hl7.org/CodeSystem/v2-0074'
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
            path: 'issued'
          }.freeze,
          {
            path: 'performer'
          }.freeze,
          {
            path: 'result'
          }.freeze
        ].freeze
      }.freeze

      DELAYED_REFERENCES = [
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
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-diagnosticreport-lab-codes',
          path: 'code'
        }.freeze
      ].freeze
    end
  end
end
