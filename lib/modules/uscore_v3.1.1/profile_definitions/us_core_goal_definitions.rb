# frozen_string_literal: true

module Inferno
  module USCore311ProfileDefinitions
    class USCore311GoalSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [].freeze,
        slices: [
          {
            name: 'Goal.target.due[x]:dueDate',
            path: 'target.due',
            discriminator: {
              type: 'type',
              code: 'Date'
            }.freeze
          }.freeze
        ].freeze,
        elements: [
          {
            path: 'lifecycleStatus'
          }.freeze,
          {
            path: 'description'
          }.freeze,
          {
            path: 'subject'
          }.freeze,
          {
            path: 'target'
          }.freeze
        ].freeze
      }.freeze

      DELAYED_REFERENCES = [].freeze

      BINDINGS = [
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/goal-status',
          path: 'lifecycleStatus'
        }.freeze
      ].freeze
    end
  end
end
