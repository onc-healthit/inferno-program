# frozen_string_literal: true

module Inferno
  module USCore311ProfileDefinitions
    class USCore311BodyheightSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [].freeze,
        slices: [
          {
            name: 'Observation.category:VSCat',
            path: 'category',
            discriminator: {
              type: 'value',
              values: [
                {
                  path: 'coding.code',
                  value: 'vital-signs'
                }.freeze,
                {
                  path: 'coding.system',
                  value: 'http://terminology.hl7.org/CodeSystem/observation-category'
                }.freeze
              ].freeze
            }.freeze
          }.freeze,
          {
            name: 'Observation.value[x]:valueQuantity',
            path: 'value',
            discriminator: {
              type: 'type',
              code: 'Quantity'
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
            path: 'category.coding'
          }.freeze,
          {
            path: 'category.coding.system',
            fixed_value: 'http://terminology.hl7.org/CodeSystem/observation-category'
          }.freeze,
          {
            path: 'category.coding.code',
            fixed_value: 'vital-signs'
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
            path: 'value'
          }.freeze,
          {
            path: 'value.value'
          }.freeze,
          {
            path: 'value.unit'
          }.freeze,
          {
            path: 'value.system',
            fixed_value: 'http://unitsofmeasure.org'
          }.freeze,
          {
            path: 'value.code'
          }.freeze
        ].freeze
      }.freeze

      DELAYED_REFERENCES = [].freeze

      BINDINGS = [
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/observation-status',
          path: 'status'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/observation-vitalsignresult',
          path: 'code'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/quantity-comparator',
          path: 'value.comparator'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/ucum-bodylength',
          path: 'value.code'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/data-absent-reason',
          path: 'dataAbsentReason'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/observation-interpretation',
          path: 'interpretation'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/observation-vitalsignresult',
          path: 'component.code'
        }.freeze,
        {
          type: 'Quantity',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/ucum-vitals-common',
          path: 'component.value'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/data-absent-reason',
          path: 'component.dataAbsentReason'
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/observation-interpretation',
          path: 'component.interpretation'
        }.freeze
      ].freeze
    end
  end
end
