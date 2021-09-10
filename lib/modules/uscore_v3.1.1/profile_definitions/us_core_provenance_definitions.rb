# frozen_string_literal: true

module Inferno
  module USCore311ProfileDefinitions
    class USCore311ProvenanceSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [].freeze,
        slices: [
          {
            name: 'Provenance.agent:ProvenanceAuthor',
            path: 'agent',
            discriminator: {
              type: 'patternCodeableConcept',
              path: 'type',
              code: 'author',
              system: 'http://terminology.hl7.org/CodeSystem/provenance-participant-type'
            }.freeze
          }.freeze,
          {
            name: 'Provenance.agent:ProvenanceTransmitter',
            path: 'agent',
            discriminator: {
              type: 'patternCodeableConcept',
              path: 'type',
              code: 'transmitter',
              system: 'http://hl7.org/fhir/us/core/CodeSystem/us-core-provenance-participant-type'
            }.freeze
          }.freeze
        ].freeze,
        elements: [
          {
            path: 'target'
          }.freeze,
          {
            path: 'recorded'
          }.freeze,
          {
            path: 'agent'
          }.freeze,
          {
            path: 'agent.type'
          }.freeze,
          {
            path: 'agent.who'
          }.freeze,
          {
            path: 'agent.onBehalfOf'
          }.freeze,
          {
            path: 'agent.type.coding.code',
            fixed_value: 'author'
          }.freeze,
          {
            path: 'agent.type.coding.code',
            fixed_value: 'transmitter'
          }.freeze
        ].freeze
      }.freeze

      DELAYED_REFERENCES = [
        {
          path: 'agent.who',
          resources: [
            'Practitioner',
            'Organization'
          ].freeze
        }.freeze,
        {
          path: 'agent.onBehalfOf',
          resources: [
            'Organization'
          ].freeze
        }.freeze
      ].freeze

      BINDINGS = [
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://terminology.hl7.org/ValueSet/v3-PurposeOfUse',
          path: 'reason'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/provenance-activity-type',
          path: 'activity'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-provenance-participant-type',
          path: 'agent.type'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/provenance-agent-type',
          path: 'agent.type'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/provenance-agent-type',
          path: 'agent.type'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/provenance-entity-role',
          path: 'entity.role'
        }.freeze
      ].freeze
    end
  end
end
