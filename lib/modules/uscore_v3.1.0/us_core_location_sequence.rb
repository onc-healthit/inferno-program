# frozen_string_literal: true

require_relative './data_absent_reason_checker'

module Inferno
  module Sequence
    class USCore310LocationSequence < SequenceBase
      include Inferno::DataAbsentReasonChecker

      title 'Location'

      description 'Verify that Location resources on the FHIR server follow the US Core Implementation Guide'

      test_id_prefix 'USCL'

      requires :token
      conformance_supports :Location
      delayed_sequence

      def validate_resource_item(resource, property, value)
        case property

        when 'name'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'name') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'name on resource does not match name requested'

        when 'address'
          value_found = resolve_element_from_path(resource, 'address') do |address|
            address&.text&.start_with?(value) ||
              address&.city&.start_with?(value) ||
              address&.state&.start_with?(value) ||
              address&.postalCode&.start_with?(value) ||
              address&.country&.start_with?(value)
          end
          assert value_found.present?, 'address on resource does not match address requested'

        when 'address-city'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'address.city') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'address-city on resource does not match address-city requested'

        when 'address-state'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'address.state') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'address-state on resource does not match address-state requested'

        when 'address-postalcode'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'address.postalCode') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'address-postalcode on resource does not match address-postalcode requested'

        end
      end

      details %(
        The #{title} Sequence tests `#{title.gsub(/\s+/, '')}` resources associated with the provided patient.
      )

      def patient_ids
        @instance.patient_ids.split(',').map(&:strip)
      end

      @resources_found = false

      MUST_SUPPORTS = {
        extensions: [],
        slices: [],
        elements: [
          {
            path: 'status'
          },
          {
            path: 'name'
          },
          {
            path: 'telecom'
          },
          {
            path: 'address'
          },
          {
            path: 'address.line'
          },
          {
            path: 'address.city'
          },
          {
            path: 'address.state'
          },
          {
            path: 'address.postalCode'
          },
          {
            path: 'managingOrganization'
          }
        ]
      }.freeze

      test :resource_read do
        metadata do
          id '01'
          name 'Server returns correct Location resource from the Location read interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(
            Reference to Location can be resolved and read.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Location, [:read])

        location_references = @instance.resource_references.select { |reference| reference.resource_type == 'Location' }
        skip 'No Location references found from the prior searches' if location_references.blank?

        @location_ary = location_references.map do |reference|
          validate_read_reply(
            FHIR::Location.new(id: reference.resource_id),
            FHIR::Location,
            check_for_data_absent_reasons
          )
        end
        @location = @location_ary.first
        @resources_found = @location.present?
      end

      test :search_by_name do
        metadata do
          id '02'
          name 'Server returns expected results from Location search by name'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by name on the Location resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Location', ['name'])

        search_params = {
          'name': get_value_for_search_param(resolve_element_from_path(@location_ary, 'name') { |el| get_value_for_search_param(el).present? })
        }

        search_params.each { |param, value| skip "Could not resolve #{param} in any resource." if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('Location'), search_params)

        assert_response_ok(reply)
        assert_bundle_response(reply)

        @resources_found = reply&.resource&.entry&.any? { |entry| entry&.resource&.resourceType == 'Location' }
        skip_if_not_found(resource_type: 'Location', delayed: true)
        search_result_resources = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
        @location_ary += search_result_resources
        @location = @location_ary
          .find { |resource| resource.resourceType == 'Location' }

        save_resource_references(versioned_resource_class('Location'), @location_ary)
        save_delayed_sequence_references(@location_ary)
        validate_reply_entries(search_result_resources, search_params)
      end

      test :search_by_address do
        metadata do
          id '03'
          name 'Server returns expected results from Location search by address'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by address on the Location resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Location', ['address'])
        skip_if_not_found(resource_type: 'Location', delayed: true)

        search_params = {
          'address': get_value_for_search_param(resolve_element_from_path(@location_ary, 'address') { |el| get_value_for_search_param(el).present? })
        }

        search_params.each { |param, value| skip "Could not resolve #{param} in any resource." if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('Location'), search_params)

        validate_search_reply(versioned_resource_class('Location'), reply, search_params)
      end

      test :search_by_address_city do
        metadata do
          id '04'
          name 'Server returns expected results from Location search by address-city'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by address-city on the Location resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Location', ['address-city'])
        skip_if_not_found(resource_type: 'Location', delayed: true)

        search_params = {
          'address-city': get_value_for_search_param(resolve_element_from_path(@location_ary, 'address.city') { |el| get_value_for_search_param(el).present? })
        }

        search_params.each { |param, value| skip "Could not resolve #{param} in any resource." if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('Location'), search_params)

        validate_search_reply(versioned_resource_class('Location'), reply, search_params)
      end

      test :search_by_address_state do
        metadata do
          id '05'
          name 'Server returns expected results from Location search by address-state'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by address-state on the Location resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Location', ['address-state'])
        skip_if_not_found(resource_type: 'Location', delayed: true)

        search_params = {
          'address-state': get_value_for_search_param(resolve_element_from_path(@location_ary, 'address.state') { |el| get_value_for_search_param(el).present? })
        }

        search_params.each { |param, value| skip "Could not resolve #{param} in any resource." if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('Location'), search_params)

        validate_search_reply(versioned_resource_class('Location'), reply, search_params)
      end

      test :search_by_address_postalcode do
        metadata do
          id '06'
          name 'Server returns expected results from Location search by address-postalcode'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by address-postalcode on the Location resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Location', ['address-postalcode'])
        skip_if_not_found(resource_type: 'Location', delayed: true)

        search_params = {
          'address-postalcode': get_value_for_search_param(resolve_element_from_path(@location_ary, 'address.postalCode') { |el| get_value_for_search_param(el).present? })
        }

        search_params.each { |param, value| skip "Could not resolve #{param} in any resource." if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('Location'), search_params)

        validate_search_reply(versioned_resource_class('Location'), reply, search_params)
      end

      test :vread_interaction do
        metadata do
          id '07'
          name 'Server returns correct Location resource from Location vread interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the Location vread interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Location, [:vread])
        skip_if_not_found(resource_type: 'Location', delayed: true)

        validate_vread_reply(@location, versioned_resource_class('Location'))
      end

      test :history_interaction do
        metadata do
          id '08'
          name 'Server returns correct Location resource from Location history interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the Location history interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Location, [:history])
        skip_if_not_found(resource_type: 'Location', delayed: true)

        validate_history_reply(@location, versioned_resource_class('Location'))
      end

      test 'Server returns Provenance resources from Location search by name + _revIncludes: Provenance:target' do
        metadata do
          id '09'
          link 'https://www.hl7.org/fhir/search.html#revinclude'
          description %(
            A Server SHALL be capable of supporting the following _revincludes: Provenance:target
          )
          versions :r4
        end

        skip_if_known_revinclude_not_supported('Location', 'Provenance:target')
        skip_if_not_found(resource_type: 'Location', delayed: true)

        provenance_results = []

        search_params = {
          'name': get_value_for_search_param(resolve_element_from_path(@location_ary, 'name') { |el| get_value_for_search_param(el).present? })
        }

        search_params.each { |param, value| skip "Could not resolve #{param} in any resource." if value.nil? }

        search_params['_revinclude'] = 'Provenance:target'
        reply = get_resource_by_params(versioned_resource_class('Location'), search_params)

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
          id '10'
          name 'Location resources returned conform to US Core R4 profiles'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-location'
          description %(

            This test checks if the resources returned from prior searches conform to the US Core profiles.
            This includes checking for missing data elements and valueset verification.

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'Location', delayed: true)
        test_resources_against_profile('Location')
        bindings = [
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/location-status',
            path: 'status'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/location-mode',
            path: 'mode'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://terminology.hl7.org/ValueSet/v3-ServiceDeliveryLocationRoleType',
            path: 'type'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/address-use',
            path: 'address.use'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/address-type',
            path: 'address.type'
          },
          {
            type: 'string',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-usps-state',
            path: 'address.state'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/days-of-week',
            path: 'hoursOfOperation.daysOfWeek'
          }
        ]
        invalid_binding_messages = []
        invalid_binding_resources = Set.new
        bindings.select { |binding_def| binding_def[:strength] == 'required' }.each do |binding_def|
          begin
            invalid_bindings = resources_with_invalid_binding(binding_def, @location_ary)
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
            invalid_bindings = resources_with_invalid_binding(binding_def, @location_ary)
            binding_def_new = binding_def
            # If the valueset binding wasn't valid, check if the codes are in the stated codesystem
            if invalid_bindings.present?
              invalid_bindings = resources_with_invalid_binding(binding_def.except(:system), @location_ary)
              binding_def_new = binding_def.except(:system)
            end
          rescue Inferno::Terminology::UnknownValueSetException, Inferno::Terminology::Valueset::UnknownCodeSystemException => e
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

      test 'All must support elements are provided in the Location resources returned.' do
        metadata do
          id '11'
          link 'http://www.hl7.org/fhir/us/core/general-guidance.html#must-support'
          description %(

            US Core Responders SHALL be capable of populating all data elements as part of the query results as specified by the US Core Server Capability Statement.
            This will look through all Location resources returned from prior searches to see if any of them provide the following must support elements:

            status

            name

            telecom

            address

            address.line

            address.city

            address.state

            address.postalCode

            managingOrganization

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'Location', delayed: true)

        missing_must_support_elements = MUST_SUPPORTS[:elements].reject do |element|
          @location_ary&.any? do |resource|
            value_found = resolve_element_from_path(resource, element[:path]) { |value| element[:fixed_value].blank? || value == element[:fixed_value] }
            value_found.present?
          end
        end
        missing_must_support_elements.map! { |must_support| "#{must_support[:path]}#{': ' + must_support[:fixed_value] if must_support[:fixed_value].present?}" }

        skip_if missing_must_support_elements.present?,
                "Could not find #{missing_must_support_elements.join(', ')} in the #{@location_ary&.length} provided Location resource(s)"
        @instance.save!
      end

      test 'Every reference within Location resource is valid and can be read.' do
        metadata do
          id '12'
          link 'http://hl7.org/fhir/references.html'
          description %(
            This test checks if references found in resources from prior searches can be resolved.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Location, [:search, :read])
        skip_if_not_found(resource_type: 'Location', delayed: true)

        validated_resources = Set.new
        max_resolutions = 50

        @location_ary&.each do |resource|
          validate_reference_resolutions(resource, validated_resources, max_resolutions) if validated_resources.length < max_resolutions
        end
      end
    end
  end
end
