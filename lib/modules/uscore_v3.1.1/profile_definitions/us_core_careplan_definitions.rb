# frozen_string_literal: true

module Inferno
  module USCore311ProfileDefinitions
    class USCore311CareplanSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [].freeze,
        slices: [
          {
            name: 'CarePlan.category:AssessPlan',
            path: 'category',
            discriminator: {
              type: 'patternCodeableConcept',
              path: '',
              code: 'assess-plan',
              system: 'http://hl7.org/fhir/us/core/CodeSystem/careplan-category'
            }.freeze
          }.freeze
        ].freeze,
        elements: [
          {
            path: 'text'
          }.freeze,
          {
            path: 'text.status'
          }.freeze,
          {
            path: 'status'
          }.freeze,
          {
            path: 'intent'
          }.freeze,
          {
            path: 'category'
          }.freeze,
          {
            path: 'subject'
          }.freeze
        ].freeze
      }.freeze

      DELAYED_REFERENCES = [].freeze

      BINDINGS = [
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-narrative-status',
          path: 'text.status'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/request-status',
          path: 'status'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/care-plan-intent',
          path: 'intent'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/care-plan-activity-kind',
          path: 'activity.detail.kind'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/care-plan-activity-status',
          path: 'activity.detail.status'
        }.freeze
      ].freeze
    end
  end
end
