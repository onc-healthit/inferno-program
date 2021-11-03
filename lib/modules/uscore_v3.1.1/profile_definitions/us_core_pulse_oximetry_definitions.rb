# frozen_string_literal: true

module Inferno
  module USCore311ProfileDefinitions
    class USCore311PulseOximetrySequenceDefinitions
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
            name: 'Observation.code.coding:PulseOx',
            path: 'code.coding',
            discriminator: {
              type: 'value',
              values: [
                {
                  path: 'code',
                  value: '59408-5'
                }.freeze,
                {
                  path: 'system',
                  value: 'http://loinc.org'
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
          }.freeze,
          {
            name: 'Observation.component:FlowRate',
            path: 'component',
            discriminator: {
              type: 'patternCodeableConcept',
              path: 'code',
              code: '3151-8',
              system: 'http://loinc.org'
            }.freeze
          }.freeze,
          {
            name: 'Observation.component:Concentration',
            path: 'component',
            discriminator: {
              type: 'patternCodeableConcept',
              path: 'code',
              code: '3150-0',
              system: 'http://loinc.org'
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
            path: 'code.coding'
          }.freeze,
          {
            path: 'code.coding.system',
            fixed_value: 'http://loinc.org'
          }.freeze,
          {
            path: 'code.coding.code',
            fixed_value: '59408-5'
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
            path: 'value.code',
            fixed_value: '%'
          }.freeze,
          {
            path: 'component'
          }.freeze,
          {
            path: 'component.code'
          }.freeze,
          {
            path: 'component.code.coding.code',
            fixed_value: '3151-8'
          }.freeze,
          {
            path: 'component.value.system',
            fixed_value: 'http://unitsofmeasure.org'
          }.freeze,
          {
            path: 'component.value.code',
            fixed_value: 'L/min'
          }.freeze,
          {
            path: 'component.code.coding.code',
            fixed_value: '3150-0'
          }.freeze,
          {
            path: 'component.value'
          }.freeze,
          {
            path: 'component.value.value'
          }.freeze,
          {
            path: 'component.value.unit'
          }.freeze,
          {
            path: 'component.value.code',
            fixed_value: '%'
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
