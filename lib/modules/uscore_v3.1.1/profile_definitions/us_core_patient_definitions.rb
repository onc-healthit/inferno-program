# frozen_string_literal: true

module Inferno
  module USCore311ProfileDefinitions
    class USCore311PatientSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [
          {
            id: 'Patient.extension:race',
            url: 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-race'
          }.freeze,
          {
            id: 'Patient.extension:ethnicity',
            url: 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity'
          }.freeze,
          {
            id: 'Patient.extension:birthsex',
            url: 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-birthsex'
          }.freeze
        ].freeze,
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
            path: 'name'
          }.freeze,
          {
            path: 'name.family'
          }.freeze,
          {
            path: 'name.given'
          }.freeze,
          {
            path: 'telecom'
          }.freeze,
          {
            path: 'telecom.system'
          }.freeze,
          {
            path: 'telecom.value'
          }.freeze,
          {
            path: 'telecom.use'
          }.freeze,
          {
            path: 'gender'
          }.freeze,
          {
            path: 'birthDate'
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
            path: 'address.period'
          }.freeze,
          {
            path: 'communication'
          }.freeze,
          {
            path: 'communication.language'
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
          system: 'http://hl7.org/fhir/ValueSet/name-use',
          path: 'name.use'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/contact-point-system',
          path: 'telecom.system'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/contact-point-use',
          path: 'telecom.use'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/administrative-gender',
          path: 'gender'
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
          system: 'http://hl7.org/fhir/ValueSet/marital-status',
          path: 'maritalStatus'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/patient-contactrelationship',
          path: 'contact.relationship'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/administrative-gender',
          path: 'contact.gender'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/us/core/ValueSet/simple-language',
          path: 'communication.language'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/link-type',
          path: 'link.type'
        }.freeze,
        {
          type: 'Coding',
          strength: 'required',
          system: 'http://hl7.org/fhir/us/core/ValueSet/omb-race-category',
          path: 'value',
          extensions: [
            'http://hl7.org/fhir/us/core/StructureDefinition/us-core-race',
            'ombCategory'
          ].freeze
        }.freeze,
        {
          type: 'Coding',
          strength: 'required',
          system: 'http://hl7.org/fhir/us/core/ValueSet/detailed-race',
          path: 'value',
          extensions: [
            'http://hl7.org/fhir/us/core/StructureDefinition/us-core-race',
            'detailed'
          ].freeze
        }.freeze,
        {
          type: 'Coding',
          strength: 'required',
          system: 'http://hl7.org/fhir/us/core/ValueSet/omb-ethnicity-category',
          path: 'value',
          extensions: [
            'http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity',
            'ombCategory'
          ].freeze
        }.freeze,
        {
          type: 'Coding',
          strength: 'required',
          system: 'http://hl7.org/fhir/us/core/ValueSet/detailed-ethnicity',
          path: 'value',
          extensions: [
            'http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity',
            'detailed'
          ].freeze
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/us/core/ValueSet/birthsex',
          path: 'value',
          extensions: [
            'http://hl7.org/fhir/us/core/StructureDefinition/us-core-birthsex'
          ].freeze
        }.freeze
      ].freeze
    end
  end
end
