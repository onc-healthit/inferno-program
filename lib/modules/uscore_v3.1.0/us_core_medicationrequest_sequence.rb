# frozen_string_literal: true

require_relative './data_absent_reason_checker'

module Inferno
  module Sequence
    class USCore310MedicationrequestSequence < SequenceBase
      include Inferno::DataAbsentReasonChecker

      title 'MedicationRequest'

      description 'Verify that MedicationRequest resources on the FHIR server follow the US Core Implementation Guide'

      test_id_prefix 'USCMR'

      requires :token, :patient_ids
      conformance_supports :MedicationRequest

      def validate_resource_item(resource, property, value)
        case property

        when 'status'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'status') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'status on resource does not match status requested'

        when 'intent'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'intent') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'intent on resource does not match intent requested'

        when 'patient'
          value_found = resolve_element_from_path(resource, 'subject.reference') { |reference| [value, 'Patient/' + value].include? reference }
          assert value_found.present?, 'patient on resource does not match patient requested'

        when 'encounter'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'encounter.reference') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'encounter on resource does not match encounter requested'

        when 'authoredon'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'authoredOn') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'authoredon on resource does not match authoredon requested'

        end
      end

      def test_medication_inclusion(medication_requests, search_params)
        @medications ||= []
        @contained_medications ||= []

        requests_with_external_references =
          medication_requests
            .select { |request| request&.medicationReference&.present? }
            .reject { |request| request&.medicationReference&.reference&.start_with? '#' }

        @contained_medications +=
          medication_requests
            .select { |request| request&.medicationReference&.reference&.start_with? '#' }
            .flat_map(&:contained)
            .select { |resource| resource.resourceType == 'Medication' }

        return if requests_with_external_references.blank?

        search_params.merge!(_include: 'MedicationRequest:medication')
        response = get_resource_by_params(FHIR::MedicationRequest, search_params)
        assert_response_ok(response)
        assert_bundle_response(response)
        requests_with_medications = fetch_all_bundled_resources(response, check_for_data_absent_reasons)

        medications = requests_with_medications.select { |resource| resource.resourceType == 'Medication' }
        assert medications.present?, 'No Medications were included in the search results'

        @medications += medications
        @medications.uniq!(&:id)
      end

      def perform_search_with_status(reply, search_param)
        begin
          parsed_reply = JSON.parse(reply.body)
          assert parsed_reply['resourceType'] == 'OperationOutcome', 'Server returned a status of 400 without an OperationOutcome.'
        rescue JSON::ParserError
          assert false, 'Server returned a status of 400 without an OperationOutcome.'
        end

        warning do
          assert @instance.server_capabilities&.search_documented?('MedicationRequest'),
                 %(Server returned a status of 400 with an OperationOutcome, but the
                search interaction for this resource is not documented in the
                CapabilityStatement. If this response was due to the server
                requiring a status parameter, the server must document this
                requirement in its CapabilityStatement.)
        end

        ['active,on-hold,cancelled,completed,entered-in-error,stopped,draft,unknown'].each do |status_value|
          params_with_status = search_param.merge('status': status_value)
          reply = get_resource_by_params(versioned_resource_class('MedicationRequest'), params_with_status)
          assert_response_ok(reply)
          assert_bundle_response(reply)

          entries = reply.resource.entry.select { |entry| entry.resource.resourceType == 'MedicationRequest' }
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

      test :search_by_patient_intent do
        metadata do
          id '01'
          name 'Server returns expected results from MedicationRequest search by patient+intent'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by patient+intent on the MedicationRequest resource

            If any MedicationRequest resources use external references to
            Medications, the search will be repeated with
            _include=MedicationRequest:medication.

          )
          versions :r4
        end

        skip_if_known_search_not_supported('MedicationRequest', ['patient', 'intent'])
        @medication_request_ary = {}
        @resources_found = false

        intent_val = ['proposal', 'plan', 'order', 'original-order', 'reflex-order', 'filler-order', 'instance-order', 'option']
        patient_ids.each do |patient|
          @medication_request_ary[patient] = []
          intent_val.each do |val|
            search_params = { 'patient': patient, 'intent': val }
            reply = get_resource_by_params(versioned_resource_class('MedicationRequest'), search_params)

            reply = perform_search_with_status(reply, search_params) if reply.code == 400

            assert_response_ok(reply)
            assert_bundle_response(reply)

            next unless reply&.resource&.entry&.any? { |entry| entry&.resource&.resourceType == 'MedicationRequest' }

            @resources_found = true
            resources_returned = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
            @medication_request = resources_returned.first
            @medication_request_ary[patient] += resources_returned

            save_resource_references(versioned_resource_class('MedicationRequest'), @medication_request_ary[patient])
            save_delayed_sequence_references(resources_returned)
            validate_reply_entries(resources_returned, search_params)
            test_medication_inclusion(@medication_request_ary[patient], search_params)
            break
          end
        end
        skip_if_not_found(resource_type: 'MedicationRequest', delayed: false)
      end

      test :search_by_patient_intent_status do
        metadata do
          id '02'
          name 'Server returns expected results from MedicationRequest search by patient+intent+status'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by patient+intent+status on the MedicationRequest resource

            If any MedicationRequest resources use external references to
            Medications, the search will be repeated with
            _include=MedicationRequest:medication.

          )
          versions :r4
        end

        skip_if_known_search_not_supported('MedicationRequest', ['patient', 'intent', 'status'])
        skip_if_not_found(resource_type: 'MedicationRequest', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'intent': get_value_for_search_param(resolve_element_from_path(@medication_request_ary[patient], 'intent') { |el| get_value_for_search_param(el).present? }),
            'status': get_value_for_search_param(resolve_element_from_path(@medication_request_ary[patient], 'status') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('MedicationRequest'), search_params)

          validate_search_reply(versioned_resource_class('MedicationRequest'), reply, search_params)
          test_medication_inclusion(reply.resource.entry.map(&:resource), search_params)
        end

        skip 'Could not resolve all parameters (patient, intent, status) in any resource.' unless resolved_one
      end

      test :search_by_patient_intent_encounter do
        metadata do
          id '03'
          name 'Server returns expected results from MedicationRequest search by patient+intent+encounter'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+intent+encounter on the MedicationRequest resource

            If any MedicationRequest resources use external references to
            Medications, the search will be repeated with
            _include=MedicationRequest:medication.

          )
          versions :r4
        end

        skip_if_known_search_not_supported('MedicationRequest', ['patient', 'intent', 'encounter'])
        skip_if_not_found(resource_type: 'MedicationRequest', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'intent': get_value_for_search_param(resolve_element_from_path(@medication_request_ary[patient], 'intent') { |el| get_value_for_search_param(el).present? }),
            'encounter': get_value_for_search_param(resolve_element_from_path(@medication_request_ary[patient], 'encounter') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('MedicationRequest'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          validate_search_reply(versioned_resource_class('MedicationRequest'), reply, search_params)
          test_medication_inclusion(reply.resource.entry.map(&:resource), search_params)
        end

        skip 'Could not resolve all parameters (patient, intent, encounter) in any resource.' unless resolved_one
      end

      test :search_by_patient_intent_authoredon do
        metadata do
          id '04'
          name 'Server returns expected results from MedicationRequest search by patient+intent+authoredon'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+intent+authoredon on the MedicationRequest resource

              including support for these authoredon comparators: gt, lt, le, ge
            If any MedicationRequest resources use external references to
            Medications, the search will be repeated with
            _include=MedicationRequest:medication.

          )
          versions :r4
        end

        skip_if_known_search_not_supported('MedicationRequest', ['patient', 'intent', 'authoredon'])
        skip_if_not_found(resource_type: 'MedicationRequest', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'intent': get_value_for_search_param(resolve_element_from_path(@medication_request_ary[patient], 'intent') { |el| get_value_for_search_param(el).present? }),
            'authoredon': get_value_for_search_param(resolve_element_from_path(@medication_request_ary[patient], 'authoredOn') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('MedicationRequest'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          validate_search_reply(versioned_resource_class('MedicationRequest'), reply, search_params)
          test_medication_inclusion(reply.resource.entry.map(&:resource), search_params)
        end

        skip 'Could not resolve all parameters (patient, intent, authoredon) in any resource.' unless resolved_one
      end

      test :read_interaction do
        metadata do
          id '05'
          name 'Server returns correct MedicationRequest resource from MedicationRequest read interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(
            A server SHALL support the MedicationRequest read interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:MedicationRequest, [:read])
        skip_if_not_found(resource_type: 'MedicationRequest', delayed: false)

        validate_read_reply(@medication_request, versioned_resource_class('MedicationRequest'), check_for_data_absent_reasons)
      end

      test :vread_interaction do
        metadata do
          id '06'
          name 'Server returns correct MedicationRequest resource from MedicationRequest vread interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the MedicationRequest vread interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:MedicationRequest, [:vread])
        skip_if_not_found(resource_type: 'MedicationRequest', delayed: false)

        validate_vread_reply(@medication_request, versioned_resource_class('MedicationRequest'))
      end

      test :history_interaction do
        metadata do
          id '07'
          name 'Server returns correct MedicationRequest resource from MedicationRequest history interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the MedicationRequest history interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:MedicationRequest, [:history])
        skip_if_not_found(resource_type: 'MedicationRequest', delayed: false)

        validate_history_reply(@medication_request, versioned_resource_class('MedicationRequest'))
      end

      test 'Server returns the appropriate resource from the following _includes: MedicationRequest:medication' do
        metadata do
          id '08'
          link 'https://www.hl7.org/fhir/search.html#include'
          optional
          description %(
            A Server SHOULD be capable of supporting the following _includes: MedicationRequest:medication
          )
          versions :r4
        end

        resolved_one = false
        medication_results = false
        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'intent': get_value_for_search_param(resolve_element_from_path(@medication_request_ary[patient], 'intent') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          skip_if_known_include_not_supported('MedicationRequest', 'MedicationRequest:medication')
          search_params['_include'] = 'MedicationRequest:medication'
          reply = get_resource_by_params(versioned_resource_class('MedicationRequest'), search_params)
          assert_response_ok(reply)
          assert_bundle_response(reply)
          medication_results ||= reply&.resource&.entry&.map(&:resource)&.any? { |resource| resource.resourceType == 'Medication' }
        end
        skip 'Could not resolve all parameters (patient, intent) in any resource.' unless resolved_one
        assert medication_results, 'No Medication resources were returned from this search'
      end

      test 'Server returns Provenance resources from MedicationRequest search by patient + intent + _revIncludes: Provenance:target' do
        metadata do
          id '09'
          link 'https://www.hl7.org/fhir/search.html#revinclude'
          description %(
            A Server SHALL be capable of supporting the following _revincludes: Provenance:target
          )
          versions :r4
        end

        skip_if_known_revinclude_not_supported('MedicationRequest', 'Provenance:target')
        skip_if_not_found(resource_type: 'MedicationRequest', delayed: false)

        resolved_one = false

        provenance_results = []
        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'intent': get_value_for_search_param(resolve_element_from_path(@medication_request_ary[patient], 'intent') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          search_params['_revinclude'] = 'Provenance:target'
          reply = get_resource_by_params(versioned_resource_class('MedicationRequest'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          assert_response_ok(reply)
          assert_bundle_response(reply)
          provenance_results += fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
            .select { |resource| resource.resourceType == 'Provenance' }
        end
        save_resource_references(versioned_resource_class('Provenance'), provenance_results)
        save_delayed_sequence_references(provenance_results)
        skip 'Could not resolve all parameters (patient, intent) in any resource.' unless resolved_one
        skip 'No Provenance resources were returned from this search' unless provenance_results.present?
      end

      test :validate_resources do
        metadata do
          id '10'
          name 'MedicationRequest resources returned conform to US Core R4 profiles'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-medicationrequest'
          description %(

            This test checks if the resources returned from prior searches conform to the US Core profiles.
            This includes checking for missing data elements and valueset verification.

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'MedicationRequest', delayed: false)
        test_resources_against_profile('MedicationRequest')
        bindings = [
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/medicationrequest-status',
            path: 'status'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/medicationrequest-intent',
            path: 'intent'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/request-priority',
            path: 'priority'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-medication-codes',
            path: 'medication'
          }
        ]
        invalid_binding_messages = []
        invalid_binding_resources = Set.new
        bindings.select { |binding_def| binding_def[:strength] == 'required' }.each do |binding_def|
          begin
            invalid_bindings = resources_with_invalid_binding(binding_def, @medication_request_ary&.values&.flatten)
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
            invalid_bindings = resources_with_invalid_binding(binding_def, @medication_request_ary&.values&.flatten)
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

      test :validate_medication_resources do
        metadata do
          id '11'
          name 'Medication resources returned conform to US Core R4 profiles'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-medicationrequest'
          description %(

              This test checks if the resources returned from prior searches conform to the US Core profiles.
              This includes checking for missing data elements and valueset verification.

          )
          versions :r4
        end

        medications_found = (@medications || []) + (@contained_medications || [])

        omit 'MedicationRequests did not reference any Medication resources.' if medications_found.blank?

        test_resource_collection('Medication', medications_found)
      end

      test 'All must support elements are provided in the MedicationRequest resources returned.' do
        metadata do
          id '12'
          link 'http://www.hl7.org/fhir/us/core/general-guidance.html#must-support'
          description %(

            US Core Responders SHALL be capable of populating all data elements as part of the query results as specified by the US Core Server Capability Statement.
            This will look through all MedicationRequest resources returned from prior searches to see if any of them provide the following must support elements:

            MedicationRequest.status

            MedicationRequest.intent

            MedicationRequest.reported[x]

            MedicationRequest.medication[x]

            MedicationRequest.subject

            MedicationRequest.encounter

            MedicationRequest.authoredOn

            MedicationRequest.requester

            MedicationRequest.dosageInstruction

            MedicationRequest.dosageInstruction.text

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'MedicationRequest', delayed: false)

        must_support_elements = [
          { path: 'MedicationRequest.status' },
          { path: 'MedicationRequest.intent' },
          { path: 'MedicationRequest.reported' },
          { path: 'MedicationRequest.medication' },
          { path: 'MedicationRequest.subject' },
          { path: 'MedicationRequest.encounter' },
          { path: 'MedicationRequest.authoredOn' },
          { path: 'MedicationRequest.requester' },
          { path: 'MedicationRequest.dosageInstruction' },
          { path: 'MedicationRequest.dosageInstruction.text' }
        ]

        missing_must_support_elements = must_support_elements.reject do |element|
          truncated_path = element[:path].gsub('MedicationRequest.', '')
          @medication_request_ary&.values&.flatten&.any? do |resource|
            value_found = resolve_element_from_path(resource, truncated_path) { |value| element[:fixed_value].blank? || value == element[:fixed_value] }
            value_found.present?
          end
        end
        missing_must_support_elements.map! { |must_support| "#{must_support[:path]}#{': ' + must_support[:fixed_value] if must_support[:fixed_value].present?}" }

        skip_if missing_must_support_elements.present?,
                "Could not find #{missing_must_support_elements.join(', ')} in the #{@medication_request_ary&.values&.flatten&.length} provided MedicationRequest resource(s)"
        @instance.save!
      end

      test 'The server returns expected results when parameters use composite-or' do
        metadata do
          id '13'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-medicationrequest'
          description %(

          )
          versions :r4
        end

        skip_if_known_search_not_supported('MedicationRequest', ['patient', 'intent', 'status'])

        resolved_one = false

        found_second_val = false
        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'intent': get_value_for_search_param(resolve_element_from_path(@medication_request_ary[patient], 'intent') { |el| get_value_for_search_param(el).present? }),
            'status': get_value_for_search_param(resolve_element_from_path(@medication_request_ary[patient], 'status') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          second_status_val = resolve_element_from_path(@medication_request_ary[patient], 'status') { |el| get_value_for_search_param(el) != search_params[:status] }
          next if second_status_val.nil?

          found_second_val = true
          search_params[:status] += ',' + get_value_for_search_param(second_status_val)
          reply = get_resource_by_params(versioned_resource_class('MedicationRequest'), search_params)
          validate_search_reply(versioned_resource_class('MedicationRequest'), reply, search_params)
          assert_response_ok(reply)
          resources_returned = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
          missing_values = search_params[:status].split(',').reject do |val|
            resolve_element_from_path(resources_returned, 'status') { |val_found| val_found == val }
          end
          assert missing_values.blank?, "Could not find #{missing_values.join(',')} values from status in any of the resources returned"
        end
        skip 'Cannot find second value for status to perform a multipleOr search' unless found_second_val
      end

      test 'Every reference within MedicationRequest resource is valid and can be read.' do
        metadata do
          id '14'
          link 'http://hl7.org/fhir/references.html'
          description %(
            This test checks if references found in resources from prior searches can be resolved.
          )
          versions :r4
        end

        skip_if_known_not_supported(:MedicationRequest, [:search, :read])
        skip_if_not_found(resource_type: 'MedicationRequest', delayed: false)

        validated_resources = Set.new
        max_resolutions = 50

        @medication_request_ary&.values&.flatten&.each do |resource|
          validate_reference_resolutions(resource, validated_resources, max_resolutions) if validated_resources.length < max_resolutions
        end
      end
    end
  end
end
