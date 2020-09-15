# frozen_string_literal: true

module Inferno
  module USCore310ProfileDefinitions
    class USCore311GoalSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [],
        slices: [
          {
            name: 'Goal.target.due[x]:dueDate',
            path: 'target.due',
            discriminator: {
              type: 'type',
              code: 'Date'
            }
          }
        ],
        references: [
          {
            path: 'subject',
            resource_types: [
              'Patient'
            ]
          }
        ],
        elements: [
          {
            path: 'lifecycleStatus'
          },
          {
            path: 'description'
          },
          {
            path: 'target'
          }
        ]
      }.freeze

      DELAYED_REFERENCES = [].freeze

      BINDINGS = [
        {
          type: 'code',
          strength: 'required',
          system: 'http://hl7.org/fhir/ValueSet/goal-status',
          path: 'lifecycleStatus'
        }
      ].freeze
    end
  end
end
