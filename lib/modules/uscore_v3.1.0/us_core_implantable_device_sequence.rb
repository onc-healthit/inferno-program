# frozen_string_literal: true

require_relative './data_absent_reason_checker'

module Inferno
  module Sequence
    class USCore310ImplantableDeviceSequence < SequenceBase
      include Inferno::DataAbsentReasonChecker

      title 'Implantable Device'

      description 'Verify that Device resources on the FHIR server follow the US Core Implementation Guide'

      test_id_prefix 'USCID'

      requires :token, :patient_ids, :device_codes
      conformance_supports :Device

      def validate_resource_item(resource, property, value)
        case property

        when 'patient'
          value_found = resolve_element_from_path(resource, 'patient.reference') { |reference| [value, 'Patient/' + value].include? reference }
          assert value_found.present?, 'patient on resource does not match patient requested'

        when 'type'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'type.coding.code') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'type on resource does not match type requested'

        end
      end

      details %(
        The #{title} Sequence tests `#{title.gsub(/\s+/, '')}` resources associated with the provided patient.
      )

      def patient_ids
        @instance.patient_ids.split(',').map(&:strip)
      end

      @resources_found = false

      test :search_by_patient do
        metadata do
          id '01'
          name 'Server returns expected results from Device search by patient'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by patient on the Device resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Device', ['patient'])
        @device_ary = {}
        patient_ids.each do |patient|
          search_params = {
            'patient': patient
          }

          reply = get_resource_by_params(versioned_resource_class('Device'), search_params)

          assert_response_ok(reply)
          assert_bundle_response(reply)

          any_resources = reply&.resource&.entry&.any? { |entry| entry&.resource&.resourceType == 'Device' }

          next unless any_resources

          @device_ary[patient] = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
            .select do |resource|
            device_codes = @instance&.device_codes&.split(',')&.map(&:strip)
            device_codes.blank? || resource&.type&.coding&.any? do |coding|
              device_codes.include?(coding.code)
            end
          end
          if @device_ary[patient].blank? && reply&.resource&.entry&.present?
            @skip_if_not_found_message = "No Devices of the specified type (#{@instance&.device_codes}) were found"
          end

          @device = @device_ary[patient]
            .find { |resource| resource.resourceType == 'Device' }
          @resources_found = @device.present?

          save_resource_references(versioned_resource_class('Device'), @device_ary[patient])
          save_delayed_sequence_references(@device_ary[patient])
          validate_reply_entries(@device_ary[patient], search_params)
        end

        skip_if_not_found(resource_type: 'Device', delayed: false)
      end

      test :search_by_patient_type do
        metadata do
          id '02'
          name 'Server returns expected results from Device search by patient+type'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+type on the Device resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Device', ['patient', 'type'])
        skip_if_not_found(resource_type: 'Device', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'type': get_value_for_search_param(resolve_element_from_path(@device_ary[patient], 'type') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('Device'), search_params)

          validate_search_reply(versioned_resource_class('Device'), reply, search_params)
        end

        skip 'Could not resolve all parameters (patient, type) in any resource.' unless resolved_one
      end

      test :read_interaction do
        metadata do
          id '03'
          name 'Server returns correct Device resource from Device read interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(
            A server SHALL support the Device read interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Device, [:read])
        skip_if_not_found(resource_type: 'Device', delayed: false)

        validate_read_reply(@device, versioned_resource_class('Device'), check_for_data_absent_reasons)
      end

      test :vread_interaction do
        metadata do
          id '04'
          name 'Server returns correct Device resource from Device vread interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the Device vread interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Device, [:vread])
        skip_if_not_found(resource_type: 'Device', delayed: false)

        validate_vread_reply(@device, versioned_resource_class('Device'))
      end

      test :history_interaction do
        metadata do
          id '05'
          name 'Server returns correct Device resource from Device history interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the Device history interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Device, [:history])
        skip_if_not_found(resource_type: 'Device', delayed: false)

        validate_history_reply(@device, versioned_resource_class('Device'))
      end

      test 'Server returns Provenance resources from Device search by patient + _revIncludes: Provenance:target' do
        metadata do
          id '06'
          link 'https://www.hl7.org/fhir/search.html#revinclude'
          description %(
            A Server SHALL be capable of supporting the following _revincludes: Provenance:target
          )
          versions :r4
        end

        skip_if_known_revinclude_not_supported('Device', 'Provenance:target')
        skip_if_not_found(resource_type: 'Device', delayed: false)

        provenance_results = []
        patient_ids.each do |patient|
          search_params = {
            'patient': patient
          }

          search_params['_revinclude'] = 'Provenance:target'
          reply = get_resource_by_params(versioned_resource_class('Device'), search_params)

          assert_response_ok(reply)
          assert_bundle_response(reply)
          provenance_results += fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
            .select { |resource| resource.resourceType == 'Provenance' }
        end
        save_resource_references(versioned_resource_class('Provenance'), provenance_results)
        save_delayed_sequence_references(provenance_results)

        skip 'No Provenance resources were returned from this search' unless provenance_results.present?
      end

      test :validate_resources do
        metadata do
          id '07'
          name 'Device resources returned conform to US Core R4 profiles'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-implantable-device'
          description %(

            This test checks if the resources returned from prior searches conform to the US Core profiles.
            This includes checking for missing data elements and valueset verification.

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'Device', delayed: false)
        test_resources_against_profile('Device')
        bindings = [
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/udi-entry-type',
            path: 'udiCarrier.entryType'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/device-status',
            path: 'status'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/ValueSet/device-status-reason',
            path: 'statusReason'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/device-nametype',
            path: 'deviceName.type'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/ValueSet/device-kind',
            path: 'type'
          }
        ]
        invalid_binding_messages = []
        invalid_binding_resources = Set.new
        bindings.select { |binding_def| binding_def[:strength] == 'required' }.each do |binding_def|
          begin
            invalid_bindings = resources_with_invalid_binding(binding_def, @device_ary&.values&.flatten)
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
            invalid_bindings = resources_with_invalid_binding(binding_def, @device_ary&.values&.flatten)
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

      test 'All must support elements are provided in the Device resources returned.' do
        metadata do
          id '08'
          link 'http://www.hl7.org/fhir/us/core/general-guidance.html#must-support'
          description %(

            US Core Responders SHALL be capable of populating all data elements as part of the query results as specified by the US Core Server Capability Statement.
            This will look through all Device resources returned from prior searches to see if any of them provide the following must support elements:

            Device.udiCarrier

            Device.udiCarrier.deviceIdentifier

            Device.udiCarrier.carrierAIDC

            Device.udiCarrier.carrierHRF

            Device.distinctIdentifier

            Device.manufactureDate

            Device.expirationDate

            Device.lotNumber

            Device.serialNumber

            Device.type

            Device.patient

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'Device', delayed: false)

        must_support_elements = [
          { path: 'Device.udiCarrier' },
          { path: 'Device.udiCarrier.deviceIdentifier' },
          { path: 'Device.udiCarrier.carrierAIDC' },
          { path: 'Device.udiCarrier.carrierHRF' },
          { path: 'Device.distinctIdentifier' },
          { path: 'Device.manufactureDate' },
          { path: 'Device.expirationDate' },
          { path: 'Device.lotNumber' },
          { path: 'Device.serialNumber' },
          { path: 'Device.type' },
          { path: 'Device.patient' }
        ]

        missing_must_support_elements = must_support_elements.reject do |element|
          truncated_path = element[:path].gsub('Device.', '')
          @device_ary&.values&.flatten&.any? do |resource|
            value_found = resolve_element_from_path(resource, truncated_path) { |value| element[:fixed_value].blank? || value == element[:fixed_value] }
            value_found.present?
          end
        end
        missing_must_support_elements.map! { |must_support| "#{must_support[:path]}#{': ' + must_support[:fixed_value] if must_support[:fixed_value].present?}" }

        skip_if missing_must_support_elements.present?,
                "Could not find #{missing_must_support_elements.join(', ')} in the #{@device_ary&.values&.flatten&.length} provided Device resource(s)"
        @instance.save!
      end

      test 'Every reference within Device resource is valid and can be read.' do
        metadata do
          id '09'
          link 'http://hl7.org/fhir/references.html'
          description %(
            This test checks if references found in resources from prior searches can be resolved.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Device, [:search, :read])
        skip_if_not_found(resource_type: 'Device', delayed: false)

        validated_resources = Set.new
        max_resolutions = 50

        @device_ary&.values&.flatten&.each do |resource|
          validate_reference_resolutions(resource, validated_resources, max_resolutions) if validated_resources.length < max_resolutions
        end
      end
    end
  end
end
