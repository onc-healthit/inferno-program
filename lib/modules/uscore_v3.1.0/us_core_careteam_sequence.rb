# frozen_string_literal: true

require_relative './data_absent_reason_checker'

module Inferno
  module Sequence
    class USCore310CareteamSequence < SequenceBase
      include Inferno::DataAbsentReasonChecker

      title 'CareTeam'

      description 'Verify that CareTeam resources on the FHIR server follow the US Core Implementation Guide'

      test_id_prefix 'USCCT'

      requires :token, :patient_ids
      conformance_supports :CareTeam

      def validate_resource_item(resource, property, value)
        case property

        when 'patient'
          value_found = resolve_element_from_path(resource, 'subject.reference') { |reference| [value, 'Patient/' + value].include? reference }
          assert value_found.present?, 'patient on resource does not match patient requested'

        when 'status'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'status') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'status on resource does not match status requested'

        end
      end

      def perform_search_with_status(reply, search_param)
        begin
          parsed_reply = JSON.parse(reply.body)
          assert parsed_reply['resourceType'] == 'OperationOutcome', 'Server returned a status of 400 without an OperationOutcome.'
        rescue JSON::ParserError
          assert false, 'Server returned a status of 400 without an OperationOutcome.'
        end

        warning do
          assert @instance.server_capabilities&.search_documented?('CareTeam'),
                 %(Server returned a status of 400 with an OperationOutcome, but the
                search interaction for this resource is not documented in the
                CapabilityStatement. If this response was due to the server
                requiring a status parameter, the server must document this
                requirement in its CapabilityStatement.)
        end

        ['proposed,active,suspended,inactive,entered-in-error'].each do |status_value|
          params_with_status = search_param.merge('status': status_value)
          reply = get_resource_by_params(versioned_resource_class('CareTeam'), params_with_status)
          assert_response_ok(reply)
          assert_bundle_response(reply)

          entries = reply.resource.entry.select { |entry| entry.resource.resourceType == 'CareTeam' }
          next if entries.blank?

          search_param.merge!('status': status_value)
          break
        end

        reply
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
            path: 'subject'
          },
          {
            path: 'participant'
          },
          {
            path: 'participant.role'
          },
          {
            path: 'participant.member'
          }
        ]
      }.freeze

      test :search_by_patient_status do
        metadata do
          id '01'
          name 'Server returns expected results from CareTeam search by patient+status'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by patient+status on the CareTeam resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('CareTeam', ['patient', 'status'])
        @care_team_ary = {}
        @resources_found = false
        values_found = 0
        status_val = ['proposed', 'active', 'suspended', 'inactive', 'entered-in-error']
        patient_ids.each do |patient|
          @care_team_ary[patient] = []
          status_val.each do |val|
            search_params = { 'patient': patient, 'status': val }
            reply = get_resource_by_params(versioned_resource_class('CareTeam'), search_params)

            assert_response_ok(reply)
            assert_bundle_response(reply)

            next unless reply&.resource&.entry&.any? { |entry| entry&.resource&.resourceType == 'CareTeam' }

            @resources_found = true
            resources_returned = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
            @care_team = resources_returned.first
            @care_team_ary[patient] += resources_returned
            values_found += 1

            save_resource_references(versioned_resource_class('CareTeam'), @care_team_ary[patient])
            save_delayed_sequence_references(resources_returned)
            validate_reply_entries(resources_returned, search_params)

            break if values_found == 2
          end
        end
        skip_if_not_found(resource_type: 'CareTeam', delayed: false)
      end

      test :read_interaction do
        metadata do
          id '02'
          name 'Server returns correct CareTeam resource from CareTeam read interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(
            A server SHALL support the CareTeam read interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:CareTeam, [:read])
        skip_if_not_found(resource_type: 'CareTeam', delayed: false)

        validate_read_reply(@care_team, versioned_resource_class('CareTeam'), check_for_data_absent_reasons)
      end

      test :vread_interaction do
        metadata do
          id '03'
          name 'Server returns correct CareTeam resource from CareTeam vread interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the CareTeam vread interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:CareTeam, [:vread])
        skip_if_not_found(resource_type: 'CareTeam', delayed: false)

        validate_vread_reply(@care_team, versioned_resource_class('CareTeam'))
      end

      test :history_interaction do
        metadata do
          id '04'
          name 'Server returns correct CareTeam resource from CareTeam history interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the CareTeam history interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:CareTeam, [:history])
        skip_if_not_found(resource_type: 'CareTeam', delayed: false)

        validate_history_reply(@care_team, versioned_resource_class('CareTeam'))
      end

      test 'Server returns Provenance resources from CareTeam search by patient + status + _revIncludes: Provenance:target' do
        metadata do
          id '05'
          link 'https://www.hl7.org/fhir/search.html#revinclude'
          description %(
            A Server SHALL be capable of supporting the following _revincludes: Provenance:target
          )
          versions :r4
        end

        skip_if_known_revinclude_not_supported('CareTeam', 'Provenance:target')
        skip_if_not_found(resource_type: 'CareTeam', delayed: false)

        resolved_one = false

        provenance_results = []
        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'status': get_value_for_search_param(resolve_element_from_path(@care_team_ary[patient], 'status') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          search_params['_revinclude'] = 'Provenance:target'
          reply = get_resource_by_params(versioned_resource_class('CareTeam'), search_params)

          assert_response_ok(reply)
          assert_bundle_response(reply)
          provenance_results += fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
            .select { |resource| resource.resourceType == 'Provenance' }
        end
        save_resource_references(versioned_resource_class('Provenance'), provenance_results)
        save_delayed_sequence_references(provenance_results)
        skip 'Could not resolve all parameters (patient, status) in any resource.' unless resolved_one
        skip 'No Provenance resources were returned from this search' unless provenance_results.present?
      end

      test :validate_resources do
        metadata do
          id '06'
          name 'CareTeam resources returned conform to US Core R4 profiles'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-careteam'
          description %(

            This test checks if the resources returned from prior searches conform to the US Core profiles.
            This includes checking for missing data elements and valueset verification.

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'CareTeam', delayed: false)
        test_resources_against_profile('CareTeam')
        bindings = [
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/care-team-status',
            path: 'status'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-careteam-provider-roles',
            path: 'participant.role'
          }
        ]
        invalid_binding_messages = []
        invalid_binding_resources = Set.new
        bindings.select { |binding_def| binding_def[:strength] == 'required' }.each do |binding_def|
          begin
            invalid_bindings = resources_with_invalid_binding(binding_def, @care_team_ary&.values&.flatten)
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
            invalid_bindings = resources_with_invalid_binding(binding_def, @care_team_ary&.values&.flatten)
            binding_def_new = binding_def
            # If the valueset binding wasn't valid, check if the codes are in the stated codesystem
            if invalid_bindings.present?
              invalid_bindings = resources_with_invalid_binding(binding_def.except(:system), @care_team_ary&.values&.flatten)
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

      test 'All must support elements are provided in the CareTeam resources returned.' do
        metadata do
          id '07'
          link 'http://www.hl7.org/fhir/us/core/general-guidance.html#must-support'
          description %(

            US Core Responders SHALL be capable of populating all data elements as part of the query results as specified by the US Core Server Capability Statement.
            This will look through all CareTeam resources returned from prior searches to see if any of them provide the following must support elements:

            status

            subject

            participant

            participant.role

            participant.member

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'CareTeam', delayed: false)

        missing_must_support_elements = MUST_SUPPORTS[:elements].reject do |element|
          @care_team_ary&.values&.flatten&.any? do |resource|
            value_found = resolve_element_from_path(resource, element[:path]) { |value| element[:fixed_value].blank? || value == element[:fixed_value] }
            value_found.present?
          end
        end
        missing_must_support_elements.map! { |must_support| "#{must_support[:path]}#{': ' + must_support[:fixed_value] if must_support[:fixed_value].present?}" }

        skip_if missing_must_support_elements.present?,
                "Could not find #{missing_must_support_elements.join(', ')} in the #{@care_team_ary&.values&.flatten&.length} provided CareTeam resource(s)"
        @instance.save!
      end

      test 'The server returns expected results when parameters use composite-or' do
        metadata do
          id '08'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-careteam'
          description %(

          )
          versions :r4
        end

        skip_if_known_search_not_supported('CareTeam', ['patient', 'status'])

        resolved_one = false

        found_second_val = false
        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'status': get_value_for_search_param(resolve_element_from_path(@care_team_ary[patient], 'status') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          second_status_val = resolve_element_from_path(@care_team_ary[patient], 'status') { |el| get_value_for_search_param(el) != search_params[:status] }
          next if second_status_val.nil?

          found_second_val = true
          search_params[:status] += ',' + get_value_for_search_param(second_status_val)
          reply = get_resource_by_params(versioned_resource_class('CareTeam'), search_params)
          validate_search_reply(versioned_resource_class('CareTeam'), reply, search_params)
          assert_response_ok(reply)
          resources_returned = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
          missing_values = search_params[:status].split(',').reject do |val|
            resolve_element_from_path(resources_returned, 'status') { |val_found| val_found == val }
          end
          assert missing_values.blank?, "Could not find #{missing_values.join(',')} values from status in any of the resources returned"
        end
        skip 'Cannot find second value for status to perform a multipleOr search' unless found_second_val
      end

      test 'Every reference within CareTeam resource is valid and can be read.' do
        metadata do
          id '09'
          link 'http://hl7.org/fhir/references.html'
          description %(
            This test checks if references found in resources from prior searches can be resolved.
          )
          versions :r4
        end

        skip_if_known_not_supported(:CareTeam, [:search, :read])
        skip_if_not_found(resource_type: 'CareTeam', delayed: false)

        validated_resources = Set.new
        max_resolutions = 50

        @care_team_ary&.values&.flatten&.each do |resource|
          validate_reference_resolutions(resource, validated_resources, max_resolutions) if validated_resources.length < max_resolutions
        end
      end
    end
  end
end
