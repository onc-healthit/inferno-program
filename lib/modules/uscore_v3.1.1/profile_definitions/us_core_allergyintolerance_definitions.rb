# frozen_string_literal: true

module Inferno
  module USCore311ProfileDefinitions
    class USCore311AllergyintoleranceSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [].freeze,
        slices: [].freeze,
        elements: [
          {
            path: 'clinicalStatus'
          }.freeze,
          {
            path: 'verificationStatus'
          }.freeze,
          {
            path: 'code'
          }.freeze,
          {
            path: 'patient'
          }.freeze,
          {
            path: 'reaction'
          }.freeze,
          {
            path: 'reaction.manifestation'
          }.freeze
        ].freeze
      }.freeze

      DELAYED_REFERENCES = [].freeze

      BINDINGS = [
        {
          type: 'CodeableConcept',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/allergyintolerance-clinical',
          path: 'clinicalStatus'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/allergyintolerance-verification',
          path: 'verificationStatus'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/allergy-intolerance-type',
          path: 'type'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/allergy-intolerance-category',
          path: 'category'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/allergy-intolerance-criticality',
          path: 'criticality'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-allergy-substance',
          path: 'code'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/clinical-findings',
          path: 'reaction.manifestation'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/reaction-event-severity',
          path: 'reaction.severity'
        }.freeze
      ].freeze
    end
  end
end
