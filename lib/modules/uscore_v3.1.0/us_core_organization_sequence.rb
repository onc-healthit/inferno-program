# frozen_string_literal: true

require_relative './data_absent_reason_checker'

module Inferno
  module Sequence
    class USCore310OrganizationSequence < SequenceBase
      include Inferno::DataAbsentReasonChecker

      title 'Organization'

      description 'Verify that Organization resources on the FHIR server follow the US Core Implementation Guide'

      test_id_prefix 'USCO'

      requires :token
      conformance_supports :Organization
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
          name 'Server returns correct Organization resource from the Organization read interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(
            Reference to Organization can be resolved and read.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Organization, [:read])

        organization_references = @instance.resource_references.select { |reference| reference.resource_type == 'Organization' }
        skip 'No Organization references found from the prior searches' if organization_references.blank?

        @organization_ary = organization_references.map do |reference|
          validate_read_reply(
            FHIR::Organization.new(id: reference.resource_id),
            FHIR::Organization,
            check_for_data_absent_reasons
          )
        end
        @organization = @organization_ary.first
        @resources_found = @organization.present?
      end

      test :search_by_name do
        metadata do
          id '02'
          name 'Server returns expected results from Organization search by name'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by name on the Organization resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Organization', ['name'])

        search_params = {
          'name': get_value_for_search_param(resolve_element_from_path(@organization_ary, 'name') { |el| get_value_for_search_param(el).present? })
        }

        search_params.each { |param, value| skip "Could not resolve #{param} in any resource." if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('Organization'), search_params)

        assert_response_ok(reply)
        assert_bundle_response(reply)

        @resources_found = reply&.resource&.entry&.any? { |entry| entry&.resource&.resourceType == 'Organization' }
        skip_if_not_found(resource_type: 'Organization', delayed: true)
        search_result_resources = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
        @organization_ary += search_result_resources
        @organization = @organization_ary
          .find { |resource| resource.resourceType == 'Organization' }

        save_resource_references(versioned_resource_class('Organization'), @organization_ary)
        save_delayed_sequence_references(@organization_ary)
        validate_reply_entries(search_result_resources, search_params)
      end

      test :search_by_address do
        metadata do
          id '03'
          name 'Server returns expected results from Organization search by address'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by address on the Organization resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Organization', ['address'])
        skip_if_not_found(resource_type: 'Organization', delayed: true)

        search_params = {
          'address': get_value_for_search_param(resolve_element_from_path(@organization_ary, 'address') { |el| get_value_for_search_param(el).present? })
        }

        search_params.each { |param, value| skip "Could not resolve #{param} in any resource." if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('Organization'), search_params)

        validate_search_reply(versioned_resource_class('Organization'), reply, search_params)
      end

      test :vread_interaction do
        metadata do
          id '04'
          name 'Server returns correct Organization resource from Organization vread interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the Organization vread interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Organization, [:vread])
        skip_if_not_found(resource_type: 'Organization', delayed: true)

        validate_vread_reply(@organization, versioned_resource_class('Organization'))
      end

      test :history_interaction do
        metadata do
          id '05'
          name 'Server returns correct Organization resource from Organization history interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the Organization history interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Organization, [:history])
        skip_if_not_found(resource_type: 'Organization', delayed: true)

        validate_history_reply(@organization, versioned_resource_class('Organization'))
      end

      test 'Server returns Provenance resources from Organization search by name + _revIncludes: Provenance:target' do
        metadata do
          id '06'
          link 'https://www.hl7.org/fhir/search.html#revinclude'
          description %(
            A Server SHALL be capable of supporting the following _revincludes: Provenance:target
          )
          versions :r4
        end

        skip_if_known_revinclude_not_supported('Organization', 'Provenance:target')
        skip_if_not_found(resource_type: 'Organization', delayed: true)

        provenance_results = []

        search_params = {
          'name': get_value_for_search_param(resolve_element_from_path(@organization_ary, 'name') { |el| get_value_for_search_param(el).present? })
        }

        search_params.each { |param, value| skip "Could not resolve #{param} in any resource." if value.nil? }

        search_params['_revinclude'] = 'Provenance:target'
        reply = get_resource_by_params(versioned_resource_class('Organization'), search_params)

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
          name 'Organization resources returned conform to US Core R4 profiles'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-organization'
          description %(

            This test checks if the resources returned from prior searches conform to the US Core profiles.
            This includes checking for missing data elements and valueset verification.

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'Organization', delayed: true)
        test_resources_against_profile('Organization')
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
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/ValueSet/contactentity-type',
            path: 'contact.purpose'
          }
        ]
        invalid_binding_messages = []
        invalid_binding_resources = Set.new
        bindings.select { |binding_def| binding_def[:strength] == 'required' }.each do |binding_def|
          begin
            invalid_bindings = resources_with_invalid_binding(binding_def, @organization_ary)
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
            invalid_bindings = resources_with_invalid_binding(binding_def, @organization_ary)
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

      test 'All must support elements are provided in the Organization resources returned.' do
        metadata do
          id '08'
          link 'http://www.hl7.org/fhir/us/core/general-guidance.html#must-support'
          description %(

            US Core Responders SHALL be capable of populating all data elements as part of the query results as specified by the US Core Server Capability Statement.
            This will look through all Organization resources returned from prior searches to see if any of them provide the following must support elements:

            Organization.identifier

            Organization.identifier.system

            Organization.identifier.value

            Organization.active

            Organization.name

            Organization.telecom

            Organization.address

            Organization.address.line

            Organization.address.city

            Organization.address.state

            Organization.address.postalCode

            Organization.address.country

            Organization.identifier:NPI

            Organization.identifier:CLIA

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'Organization', delayed: true)

        must_support_slices = [
          {
            name: 'Organization.identifier:NPI',
            path: 'Organization.identifier',
            discriminator: {
              type: 'patternIdentifier',
              path: '',
              system: 'http://hl7.org/fhir/sid/us-npi'
            }
          },
          {
            name: 'Organization.identifier:CLIA',
            path: 'Organization.identifier',
            discriminator: {
              type: 'patternIdentifier',
              path: '',
              system: 'urn:oid:2.16.840.1.113883.4.7'
            }
          }
        ]
        missing_slices = must_support_slices.reject do |slice|
          truncated_path = slice[:path].gsub('Organization.', '')
          @organization_ary&.any? do |resource|
            slice_found = find_slice(resource, truncated_path, slice[:discriminator])
            slice_found.present?
          end
        end

        must_support_elements = [
          { path: 'Organization.identifier' },
          { path: 'Organization.identifier.system' },
          { path: 'Organization.identifier.value' },
          { path: 'Organization.active' },
          { path: 'Organization.name' },
          { path: 'Organization.telecom' },
          { path: 'Organization.address' },
          { path: 'Organization.address.line' },
          { path: 'Organization.address.city' },
          { path: 'Organization.address.state' },
          { path: 'Organization.address.postalCode' },
          { path: 'Organization.address.country' }
        ]

        missing_must_support_elements = must_support_elements.reject do |element|
          truncated_path = element[:path].gsub('Organization.', '')
          @organization_ary&.any? do |resource|
            value_found = resolve_element_from_path(resource, truncated_path) { |value| element[:fixed_value].blank? || value == element[:fixed_value] }
            value_found.present?
          end
        end
        missing_must_support_elements.map! { |must_support| "#{must_support[:path]}#{': ' + must_support[:fixed_value] if must_support[:fixed_value].present?}" }

        missing_must_support_elements += missing_slices.map { |slice| slice[:name] }

        skip_if missing_must_support_elements.present?,
                "Could not find #{missing_must_support_elements.join(', ')} in the #{@organization_ary&.length} provided Organization resource(s)"
        @instance.save!
      end

      test 'Every reference within Organization resource is valid and can be read.' do
        metadata do
          id '09'
          link 'http://hl7.org/fhir/references.html'
          description %(
            This test checks if references found in resources from prior searches can be resolved.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Organization, [:search, :read])
        skip_if_not_found(resource_type: 'Organization', delayed: true)

        validated_resources = Set.new
        max_resolutions = 50

        @organization_ary&.each do |resource|
          validate_reference_resolutions(resource, validated_resources, max_resolutions) if validated_resources.length < max_resolutions
        end
      end
    end
  end
end
