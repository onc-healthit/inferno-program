# frozen_string_literal: true

require_relative './data_absent_reason_checker'

module Inferno
  module Sequence
    class USCore310PractitionerSequence < SequenceBase
      include Inferno::DataAbsentReasonChecker

      title 'Practitioner'

      description 'Verify that Practitioner resources on the FHIR server follow the US Core Implementation Guide'

      test_id_prefix 'USCPR'

      requires :token
      conformance_supports :Practitioner
      delayed_sequence

      def validate_resource_item(resource, property, value)
        case property

        when 'name'
          value = value.downcase
          value_found = resolve_element_from_path(resource, 'name') do |name|
            name&.text&.start_with?(value) ||
              name&.family&.downcase&.include?(value) ||
              name&.given&.any? { |given| given.downcase.start_with?(value) } ||
              name&.prefix&.any? { |prefix| prefix.downcase.start_with?(value) } ||
              name&.suffix&.any? { |suffix| suffix.downcase.start_with?(value) }
          end
          assert value_found.present?, 'name on resource does not match name requested'

        when 'identifier'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'identifier.value') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'identifier on resource does not match identifier requested'

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
          name 'Server returns correct Practitioner resource from the Practitioner read interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(
            Reference to Practitioner can be resolved and read.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Practitioner, [:read])

        practitioner_references = @instance.resource_references.select { |reference| reference.resource_type == 'Practitioner' }
        skip 'No Practitioner references found from the prior searches' if practitioner_references.blank?

        @practitioner_ary = practitioner_references.map do |reference|
          validate_read_reply(
            FHIR::Practitioner.new(id: reference.resource_id),
            FHIR::Practitioner,
            check_for_data_absent_reasons
          )
        end
        @practitioner = @practitioner_ary.first
        @resources_found = @practitioner.present?
      end

      test :search_by_name do
        metadata do
          id '02'
          name 'Server returns expected results from Practitioner search by name'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by name on the Practitioner resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Practitioner', ['name'])

        search_params = {
          'name': get_value_for_search_param(resolve_element_from_path(@practitioner_ary, 'name') { |el| get_value_for_search_param(el).present? })
        }

        search_params.each { |param, value| skip "Could not resolve #{param} in any resource." if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('Practitioner'), search_params)

        assert_response_ok(reply)
        assert_bundle_response(reply)

        @resources_found = reply&.resource&.entry&.any? { |entry| entry&.resource&.resourceType == 'Practitioner' }
        skip_if_not_found(resource_type: 'Practitioner', delayed: true)
        search_result_resources = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
        @practitioner_ary += search_result_resources
        @practitioner = @practitioner_ary
          .find { |resource| resource.resourceType == 'Practitioner' }

        save_resource_references(versioned_resource_class('Practitioner'), @practitioner_ary)
        save_delayed_sequence_references(@practitioner_ary)
        validate_reply_entries(search_result_resources, search_params)
      end

      test :search_by_identifier do
        metadata do
          id '03'
          name 'Server returns expected results from Practitioner search by identifier'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by identifier on the Practitioner resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Practitioner', ['identifier'])
        skip_if_not_found(resource_type: 'Practitioner', delayed: true)

        search_params = {
          'identifier': get_value_for_search_param(resolve_element_from_path(@practitioner_ary, 'identifier') { |el| get_value_for_search_param(el).present? })
        }

        search_params.each { |param, value| skip "Could not resolve #{param} in any resource." if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('Practitioner'), search_params)

        validate_search_reply(versioned_resource_class('Practitioner'), reply, search_params)
      end

      test :vread_interaction do
        metadata do
          id '04'
          name 'Server returns correct Practitioner resource from Practitioner vread interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the Practitioner vread interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Practitioner, [:vread])
        skip_if_not_found(resource_type: 'Practitioner', delayed: true)

        validate_vread_reply(@practitioner, versioned_resource_class('Practitioner'))
      end

      test :history_interaction do
        metadata do
          id '05'
          name 'Server returns correct Practitioner resource from Practitioner history interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the Practitioner history interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Practitioner, [:history])
        skip_if_not_found(resource_type: 'Practitioner', delayed: true)

        validate_history_reply(@practitioner, versioned_resource_class('Practitioner'))
      end

      test 'Server returns Provenance resources from Practitioner search by name + _revIncludes: Provenance:target' do
        metadata do
          id '06'
          link 'https://www.hl7.org/fhir/search.html#revinclude'
          description %(
            A Server SHALL be capable of supporting the following _revincludes: Provenance:target
          )
          versions :r4
        end

        skip_if_known_revinclude_not_supported('Practitioner', 'Provenance:target')
        skip_if_not_found(resource_type: 'Practitioner', delayed: true)

        provenance_results = []

        search_params = {
          'name': get_value_for_search_param(resolve_element_from_path(@practitioner_ary, 'name') { |el| get_value_for_search_param(el).present? })
        }

        search_params.each { |param, value| skip "Could not resolve #{param} in any resource." if value.nil? }

        search_params['_revinclude'] = 'Provenance:target'
        reply = get_resource_by_params(versioned_resource_class('Practitioner'), search_params)

        assert_response_ok(reply)
        assert_bundle_response(reply)
        provenance_results += fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
          .select { |resource| resource.resourceType == 'Provenance' }

        save_resource_references(versioned_resource_class('Provenance'), provenance_results)
        save_delayed_sequence_references(provenance_results)

        skip 'No Provenance resources were returned from this search' unless provenance_results.present?
      end

      test :validate_resources do
        metadata do
          id '07'
          name 'Practitioner resources returned conform to US Core R4 profiles'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-practitioner'
          description %(

            This test checks if the resources returned from prior searches conform to the US Core profiles.
            This includes checking for missing data elements and valueset verification.

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'Practitioner', delayed: true)
        test_resources_against_profile('Practitioner')
        bindings = [
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/identifier-use',
            path: 'identifier.use'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/ValueSet/identifier-type',
            path: 'identifier.type'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/name-use',
            path: 'name.use'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/administrative-gender',
            path: 'gender'
          }
        ]
        invalid_binding_messages = []
        invalid_binding_resources = Set.new
        bindings.select { |binding_def| binding_def[:strength] == 'required' }.each do |binding_def|
          begin
            invalid_bindings = resources_with_invalid_binding(binding_def, @practitioner_ary)
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
            invalid_bindings = resources_with_invalid_binding(binding_def, @practitioner_ary)
          rescue Inferno::Terminology::UnknownValueSetException => e
            warning do
              assert false, e.message
            end
            invalid_bindings = []
          end
          invalid_binding_messages.concat(invalid_bindings.map { |invalid| invalid_binding_message(invalid, binding_def) })
        end
        warning do
          invalid_binding_messages.each do |error_message|
            assert false, error_message
          end
        end
      end

      test 'All must support elements are provided in the Practitioner resources returned.' do
        metadata do
          id '08'
          link 'http://www.hl7.org/fhir/us/core/general-guidance.html#must-support'
          description %(

            US Core Responders SHALL be capable of populating all data elements as part of the query results as specified by the US Core Server Capability Statement.
            This will look through all Practitioner resources returned from prior searches to see if any of them provide the following must support elements:

            Practitioner.identifier

            Practitioner.identifier.system

            Practitioner.identifier.value

            Practitioner.name

            Practitioner.name.family

            Practitioner.identifier:NPI

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'Practitioner', delayed: true)

        must_support_slices = [
          {
            name: 'Practitioner.identifier:NPI',
            path: 'Practitioner.identifier',
            discriminator: {
              type: 'patternIdentifier',
              path: '',
              system: 'http://hl7.org/fhir/sid/us-npi'
            }
          }
        ]
        missing_slices = must_support_slices.reject do |slice|
          truncated_path = slice[:path].gsub('Practitioner.', '')
          @practitioner_ary&.any? do |resource|
            slice_found = find_slice(resource, truncated_path, slice[:discriminator])
            slice_found.present?
          end
        end

        must_support_elements = [
          { path: 'Practitioner.identifier' },
          { path: 'Practitioner.identifier.system' },
          { path: 'Practitioner.identifier.value' },
          { path: 'Practitioner.name' },
          { path: 'Practitioner.name.family' }
        ]

        missing_must_support_elements = must_support_elements.reject do |element|
          truncated_path = element[:path].gsub('Practitioner.', '')
          @practitioner_ary&.any? do |resource|
            value_found = resolve_element_from_path(resource, truncated_path) { |value| element[:fixed_value].blank? || value == element[:fixed_value] }
            value_found.present?
          end
        end
        missing_must_support_elements.map! { |must_support| "#{must_support[:path]}#{': ' + must_support[:fixed_value] if must_support[:fixed_value].present?}" }

        missing_must_support_elements += missing_slices.map { |slice| slice[:name] }

        skip_if missing_must_support_elements.present?,
                "Could not find #{missing_must_support_elements.join(', ')} in the #{@practitioner_ary&.length} provided Practitioner resource(s)"
        @instance.save!
      end

      test 'Every reference within Practitioner resource is valid and can be read.' do
        metadata do
          id '09'
          link 'http://hl7.org/fhir/references.html'
          description %(
            This test checks if references found in resources from prior searches can be resolved.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Practitioner, [:search, :read])
        skip_if_not_found(resource_type: 'Practitioner', delayed: true)

        validated_resources = Set.new
        max_resolutions = 50

        @practitioner_ary&.each do |resource|
          validate_reference_resolutions(resource, validated_resources, max_resolutions) if validated_resources.length < max_resolutions
        end
      end
    end
  end
end
