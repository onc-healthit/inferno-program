# frozen_string_literal: true

module Inferno
  module USCore311ProfileDefinitions
    class USCore311BpSequenceDefinitions
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
            name: 'Observation.component:SystolicBP',
            path: 'component',
            discriminator: {
              type: 'value',
              values: [
                {
                  path: 'code.coding.code',
                  value: '8480-6'
                }.freeze,
                {
                  path: 'code.coding.system',
                  value: 'http://loinc.org'
                }.freeze
              ].freeze
            }.freeze
          }.freeze,
          {
            name: 'Observation.component:DiastolicBP',
            path: 'component',
            discriminator: {
              type: 'value',
              values: [
                {
                  path: 'code.coding.code',
                  value: '8462-4'
                }.freeze,
                {
                  path: 'code.coding.system',
                  value: 'http://loinc.org'
                }.freeze
              ].freeze
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
            path: 'component'
          }.freeze,
          {
            path: 'component.value.system',
            fixed_value: 'http://unitsofmeasure.org'
          }.freeze,
          {
            path: 'component.value.code',
            fixed_value: 'mm[Hg]'
          }.freeze,
          {
            path: 'component.code'
          }.freeze,
          {
            path: 'component.value'
          }.freeze,
          {
            path: 'component.value.value'
          }.freeze,
          {
            path: 'component.value.unit'
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
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/observation-vitalsignresult',
          path: 'component.code'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/quantity-comparator',
          path: 'component.value.comparator'
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
        }.freeze,
        {
          type: 'CodeableConcept',
          strength: 'extensible',
          system: 'http://hl7.org/fhir/ValueSet/observation-vitalsignresult',
          path: 'component.code'
        }.freeze,
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/quantity-comparator',
          path: 'component.value.comparator'
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
