# frozen_string_literal: true

require_relative './data_absent_reason_checker'
require_relative './profile_definitions/us_core_practitionerrole_definitions'

module Inferno
  module Sequence
    class USCore310PractitionerroleSequence < SequenceBase
      include Inferno::DataAbsentReasonChecker
      include Inferno::USCore310ProfileDefinitions

      title 'PractitionerRole'

      description 'Verify that PractitionerRole resources on the FHIR server follow the US Core Implementation Guide'

      test_id_prefix 'USCPRO'

      requires :token
      conformance_supports :PractitionerRole
      delayed_sequence

      def validate_resource_item(resource, property, value)
        case property

        when 'specialty'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'specialty.coding.code') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'specialty on resource does not match specialty requested'

        when 'practitioner'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'practitioner.reference') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'practitioner on resource does not match practitioner requested'

        end
      end

      details %(
        The #{title} Sequence tests `#{title.gsub(/\s+/, '')}` resources associated with the provided patient.
      )

      def patient_ids
        @instance.patient_ids.split(',').map(&:strip)
      end

      @resources_found = false

      test :resource_read do
        metadata do
          id '01'
          name 'Server returns correct PractitionerRole resource from the PractitionerRole read interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(
            Reference to PractitionerRole can be resolved and read.
          )
          versions :r4
        end

        skip_if_known_not_supported(:PractitionerRole, [:read])

        practitioner_role_references = @instance.resource_references.select { |reference| reference.resource_type == 'PractitionerRole' }
        skip 'No PractitionerRole references found from the prior searches' if practitioner_role_references.blank?

        @practitioner_role_ary = practitioner_role_references.map do |reference|
          validate_read_reply(
            FHIR::PractitionerRole.new(id: reference.resource_id),
            FHIR::PractitionerRole,
            check_for_data_absent_reasons
          )
        end
        @practitioner_role = @practitioner_role_ary.first
        @resources_found = @practitioner_role.present?
      end

      test :validate_resources do
        metadata do
          id '02'
          name 'PractitionerRole resources returned conform to US Core R4 profiles'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-practitionerrole'
          description %(

            This test checks if the resources returned from prior searches conform to the US Core profiles.
            This includes checking for missing data elements and valueset verification.

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'PractitionerRole', delayed: true)
        test_resources_against_profile('PractitionerRole')
        bindings = [
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-provider-role',
            path: 'code'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-provider-specialty',
            path: 'specialty'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/contact-point-system',
            path: 'telecom.system'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/contact-point-use',
            path: 'telecom.use'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/days-of-week',
            path: 'availableTime.daysOfWeek'
          }
        ]
        invalid_binding_messages = []
        invalid_binding_resources = Set.new
        bindings.select { |binding_def| binding_def[:strength] == 'required' }.each do |binding_def|
          begin
            invalid_bindings = resources_with_invalid_binding(binding_def, @practitioner_role_ary)
          rescue Inferno::Terminology::UnknownValueSetException => e
            warning do
              assert false, e.message
            end
            invalid_bindings = []
          end
          invalid_bindings.each { |invalid| invalid_binding_resources << "#{invalid[:resource]&.resourceType}/#{invalid[:resource].id}" }
          invalid_binding_messages.concat(invalid_bindings.map { |invalid| invalid_binding_message(invalid, binding_def) })
        end
        assert invalid_binding_messages.blank?, "#{invalid_binding_messages.count} invalid required binding(s) found in #{invalid_binding_resources.count} resources:" \
                                                "#{invalid_binding_messages.join('. ')}"

        bindings.select { |binding_def| binding_def[:strength] == 'extensible' }.each do |binding_def|
          begin
            invalid_bindings = resources_with_invalid_binding(binding_def, @practitioner_role_ary)
            binding_def_new = binding_def
            # If the valueset binding wasn't valid, check if the codes are in the stated codesystem
            if invalid_bindings.present?
              invalid_bindings = resources_with_invalid_binding(binding_def.except(:system), @practitioner_role_ary)
              binding_def_new = binding_def.except(:system)
            end
          rescue Inferno::Terminology::UnknownValueSetException, Inferno::Terminology::ValueSet::UnknownCodeSystemException => e
            warning do
              assert false, e.message
            end
            invalid_bindings = []
          end
          invalid_binding_messages.concat(invalid_bindings.map { |invalid| invalid_binding_message(invalid, binding_def_new) })
        end
        warning do
          invalid_binding_messages.each do |error_message|
            assert false, error_message
          end
        end
      end

      test 'All must support elements are provided in the PractitionerRole resources returned.' do
        metadata do
          id '03'
          link 'http://www.hl7.org/fhir/us/core/general-guidance.html#must-support'
          description %(

            US Core Responders SHALL be capable of populating all data elements as part of the query results as specified by the US Core Server Capability Statement.
            This will look through all PractitionerRole resources returned from prior searches to see if any of them provide the following must support elements:

            practitioner

            organization

            code

            specialty

            location

            telecom

            telecom.system

            telecom.value

            endpoint

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'PractitionerRole', delayed: true)
        must_supports = USCore310PractitionerroleSequenceDefinitions::MUST_SUPPORTS

        missing_must_support_elements = must_supports[:elements].reject do |element|
          @practitioner_role_ary&.any? do |resource|
            value_found = resolve_element_from_path(resource, element[:path]) { |value| element[:fixed_value].blank? || value == element[:fixed_value] }
            value_found.present?
          end
        end
        missing_must_support_elements.map! { |must_support| "#{must_support[:path]}#{': ' + must_support[:fixed_value] if must_support[:fixed_value].present?}" }

        skip_if missing_must_support_elements.present?,
                "Could not find #{missing_must_support_elements.join(', ')} in the #{@practitioner_role_ary&.length} provided PractitionerRole resource(s)"
        @instance.save!
      end

      test 'Every reference within PractitionerRole resource is valid and can be read.' do
        metadata do
          id '04'
          link 'http://hl7.org/fhir/references.html'
          description %(
            This test checks if references found in resources from prior searches can be resolved.
          )
          versions :r4
        end

        skip_if_known_not_supported(:PractitionerRole, [:search, :read])
        skip_if_not_found(resource_type: 'PractitionerRole', delayed: true)

        validated_resources = Set.new
        max_resolutions = 50

        @practitioner_role_ary&.each do |resource|
          validate_reference_resolutions(resource, validated_resources, max_resolutions) if validated_resources.length < max_resolutions
        end
      end
    end
  end
end
