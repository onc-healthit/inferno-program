# frozen_string_literal: true

require_relative './data_absent_reason_checker'
require_relative './profile_definitions/us_core_medicationrequest_definitions'

module Inferno
  module Sequence
    class USCore311MedicationrequestSequence < SequenceBase
      include Inferno::DataAbsentReasonChecker
      include Inferno::USCore311ProfileDefinitions

      title 'MedicationRequest Tests'

      description 'Verify support for the server capabilities required by the US Core MedicationRequest Profile.'

      details %(
        # Background

        The US Core #{title} sequence verifies that the system under test is able to provide correct responses
        for MedicationRequest queries.  These queries must contain resources conforming to US Core MedicationRequest Profile as specified
        in the US Core v3.1.1 Implementation Guide.

        # Testing Methodology


        ## Searching
        This test sequence will first perform each required search associated with this resource. This sequence will perform searches
        with the following parameters:

          * patient + intent
          * patient + intent + status



        ### Search Parameters
        The first search uses the selected patient(s) from the prior launch sequence. Any subsequent searches will look for its
        parameter values from the results of the first search. For example, the `identifier` search in the patient sequence is
        performed by looking for an existing `Patient.identifier` from any of the resources returned in the `_id` search. If a
        value cannot be found this way, the search is skipped.

        ### Search Validation
        Inferno will retrieve up to the first 20 bundle pages of the reply for MedicationRequest resources and save them
        for subsequent tests.
        Each of these resources is then checked to see if it matches the searched parameters in accordance
        with [FHIR search guidelines](https://www.hl7.org/fhir/search.html). The test will fail, for example, if a patient search
        for gender=male returns a female patient.

        ## Must Support
        Each profile has a list of elements marked as "must support". This test sequence expects to see each of these elements
        at least once. If at least one cannot be found, the test will fail. The test will look through the MedicationRequest
        resources found for these elements.

        ## Profile Validation
        Each resource returned from the first search is expected to conform to the [US Core MedicationRequest Profile](http://hl7.org/fhir/us/core/STU3.1.1/StructureDefinition/us-core-medicationrequest).
        Each element is checked against teminology binding and cardinality requirements.

        Elements with a required binding is validated against its bound valueset. If the code/system in the element is not part
        of the valueset, then the test will fail.

        ## Reference Validation
        Each reference within the resources found from the first search must resolve. The test will attempt to read each reference found
        and will fail if any attempted read fails.
      )

      test_id_prefix 'USCMR'

      requires :token, :patient_ids
      conformance_supports :MedicationRequest

      def validate_resource_item(resource, property, value)
        case property

        when 'status'
          values_found = resolve_path(resource, 'status')
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          match_found = values_found.any? { |value_in_resource| values.include? value_in_resource }
          assert match_found, "status in MedicationRequest/#{resource.id} (#{values_found}) does not match status requested (#{value})"

        when 'intent'
          values_found = resolve_path(resource, 'intent')
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          match_found = values_found.any? { |value_in_resource| values.include? value_in_resource }
          assert match_found, "intent in MedicationRequest/#{resource.id} (#{values_found}) does not match intent requested (#{value})"

        when 'patient'
          values_found = resolve_path(resource, 'subject.reference')
          value = value.split('Patient/').last
          match_found = values_found.any? { |reference| [value, 'Patient/' + value, "#{@instance.url}/Patient/#{value}"].include? reference }
          assert match_found, "patient in MedicationRequest/#{resource.id} (#{values_found}) does not match patient requested (#{value})"

        when 'encounter'
          values_found = resolve_path(resource, 'encounter.reference')
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          match_found = values_found.any? { |value_in_resource| values.include? value_in_resource }
          assert match_found, "encounter in MedicationRequest/#{resource.id} (#{values_found}) does not match encounter requested (#{value})"

        when 'authoredon'
          values_found = resolve_path(resource, 'authoredOn')
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          match_found = values_found.any? { |value_in_resource| values.include? value_in_resource }
          assert match_found, "authoredon in MedicationRequest/#{resource.id} (#{values_found}) does not match authoredon requested (#{value})"

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

      def perform_search_with_status(reply, search_param, search_method: :get)
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
          reply = get_resource_by_params(versioned_resource_class('MedicationRequest'), params_with_status, search_method: search_method)
          assert_response_ok(reply)
          assert_bundle_response(reply)

          entries = reply.resource.entry.select { |entry| entry.resource.resourceType == 'MedicationRequest' }
          next if entries.blank?

          search_param.merge!('status': status_value)
          break
        end

        reply
      end

      def patient_ids
        @instance.patient_ids.split(',').map(&:strip)
      end

      @resources_found = false

      test :search_by_patient_intent do
        metadata do
          id '01'
          name 'Server returns valid results for MedicationRequest search by patient+intent.'
          link 'http://hl7.org/fhir/us/core/STU3.1.1/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by patient+intent on the MedicationRequest resource.
            This test will pass if resources are returned and match the search criteria. If none are returned, the test is skipped.

            If any MedicationRequest resources use external references to
            Medications, the search will be repeated with
            _include=MedicationRequest:medication.

            This test verifies that the server supports searching by
            reference using the form `patient=[id]` as well as
            `patient=Patient/[id]`.  The two different forms are expected
            to return the same number of results.  US Core requires that
            both forms are supported by US Core responders.

            Additionally, this test will check that GET and POST search
            methods return the same number of results. Search by POST
            is required by the FHIR R4 specification, and these tests
            interpret search by GET as a requirement of US Core v3.1.1.

            Because this is the first search of the sequence, resources in
            the response will be used for subsequent tests.

          )
          versions :r4
        end

        skip_if_known_search_not_supported('MedicationRequest', ['patient', 'intent'])
        @medication_request_ary = {}
        @resources_found = false
        search_query_variants_tested_once = false
        intent_val = ['proposal', 'plan', 'order', 'original-order', 'reflex-order', 'filler-order', 'instance-order', 'option']
        patient_ids.each do |patient|
          @medication_request_ary[patient] = []
          intent_val.each do |val|
            search_params = { 'patient': patient, 'intent': val }
            reply = get_resource_by_params(versioned_resource_class('MedicationRequest'), search_params)

            reply = perform_search_with_status(reply, search_params, search_method: :get) if reply.code == 400

            assert_response_ok(reply)
            assert_bundle_response(reply)

            next unless reply&.resource&.entry&.any? { |entry| entry&.resource&.resourceType == 'MedicationRequest' }

            @resources_found = true
            resources_returned = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
            types_in_response = Set.new(resources_returned.map { |resource| resource&.resourceType })
            resources_returned.select! { |resource| resource.resourceType == 'MedicationRequest' }
            @medication_request = resources_returned.first
            @medication_request_ary[patient] += resources_returned

            save_resource_references(versioned_resource_class('MedicationRequest'), @medication_request_ary[patient])
            save_delayed_sequence_references(resources_returned, USCore311MedicationrequestSequenceDefinitions::DELAYED_REFERENCES)

            invalid_types_in_response = types_in_response - Set.new(['MedicationRequest', 'OperationOutcome'])
            assert(invalid_types_in_response.empty?,
                   'All resources returned must be of the type MedicationRequest or OperationOutcome, but includes ' + invalid_types_in_response.to_a.join(', '))
            validate_reply_entries(resources_returned, search_params)

            next if search_query_variants_tested_once

            # Search with type of reference variant (patient=Patient/[id])
            search_params_with_type = search_params.merge('patient': "Patient/#{patient}")
            reply = get_resource_by_params(versioned_resource_class('MedicationRequest'), search_params_with_type)

            reply = perform_search_with_status(reply, search_params, search_method: :get) if reply.code == 400

            assert_response_ok(reply)
            assert_bundle_response(reply)

            search_with_type = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
            search_with_type.select! { |resource| resource.resourceType == 'MedicationRequest' }
            assert search_with_type.length == resources_returned.length, 'Expected search by Patient/ID to have the same results as search by ID'

            search_with_type = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
            search_with_type.select! { |resource| resource.resourceType == 'MedicationRequest' }
            assert search_with_type.length == resources_returned.length, 'Expected search by Patient/ID to have the same results as search by ID'

            # Search by POST variant
            reply = get_resource_by_params(versioned_resource_class('MedicationRequest'), search_params, search_method: :post)

            reply = perform_search_with_status(reply, search_params, search_method: :post) if reply.code == 400

            assert_response_ok(reply)
            assert_bundle_response(reply)

            search_by_post_resources = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
            search_by_post_resources.select! { |resource| resource.resourceType == 'MedicationRequest' }
            assert search_by_post_resources.length == resources_returned.length, 'Expected search by POST to have the same results as search by GET'

            test_medication_inclusion(@medication_request_ary[patient], search_params)

            search_query_variants_tested_once = true
          end
        end

        skip_if_not_found(resource_type: 'MedicationRequest', delayed: false)
      end

      test :search_by_patient_intent_status do
        metadata do
          id '02'
          name 'Server returns valid results for MedicationRequest search by patient+intent+status.'
          link 'http://hl7.org/fhir/us/core/STU3.1.1/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by patient+intent+status on the MedicationRequest resource.
            This test will pass if resources are returned and match the search criteria. If none are returned, the test is skipped.

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
          next unless @medication_request_ary[patient].present?

          Array.wrap(@medication_request_ary[patient]).each do |medication_request|
            search_params = {
              'patient': patient,
              'intent': get_value_for_search_param(resolve_element_from_path(medication_request, 'intent') { |el| get_value_for_search_param(el).present? }),
              'status': get_value_for_search_param(resolve_element_from_path(medication_request, 'status') { |el| get_value_for_search_param(el).present? })
            }

            next if search_params.any? { |_param, value| value.nil? }

            resolved_one = true

            reply = get_resource_by_params(versioned_resource_class('MedicationRequest'), search_params)

            validate_search_reply(versioned_resource_class('MedicationRequest'), reply, search_params)

            resources_returned = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
            assert(resources_returned.all? { |resource| ['MedicationRequest', 'OperationOutcome'].include? resource.resourceType },
                   'All resources returned must be of the type MedicationRequest or OperationOutcome')
            resources_returned.reject! { |resource| resource.resourceType == 'OperationOutcome' }
            test_medication_inclusion(resources_returned, search_params)

            break if resolved_one
          end
        end

        skip 'Could not resolve all parameters (patient, intent, status) in any resource.' unless resolved_one
      end

      test :search_by_patient_intent_encounter do
        metadata do
          id '03'
          name 'Server returns valid results for MedicationRequest search by patient+intent+encounter.'
          link 'http://hl7.org/fhir/us/core/STU3.1.1/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+intent+encounter on the MedicationRequest resource.
            This test will pass if resources are returned and match the search criteria. If none are returned, the test is skipped.

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
          next unless @medication_request_ary[patient].present?

          Array.wrap(@medication_request_ary[patient]).each do |medication_request|
            search_params = {
              'patient': patient,
              'intent': get_value_for_search_param(resolve_element_from_path(medication_request, 'intent') { |el| get_value_for_search_param(el).present? }),
              'encounter': get_value_for_search_param(resolve_element_from_path(medication_request, 'encounter') { |el| get_value_for_search_param(el).present? })
            }

            next if search_params.any? { |_param, value| value.nil? }

            resolved_one = true

            reply = get_resource_by_params(versioned_resource_class('MedicationRequest'), search_params)

            reply = perform_search_with_status(reply, search_params, search_method: :get) if reply.code == 400

            validate_search_reply(versioned_resource_class('MedicationRequest'), reply, search_params)

            resources_returned = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
            assert(resources_returned.all? { |resource| ['MedicationRequest', 'OperationOutcome'].include? resource.resourceType },
                   'All resources returned must be of the type MedicationRequest or OperationOutcome')
            resources_returned.reject! { |resource| resource.resourceType == 'OperationOutcome' }
            test_medication_inclusion(resources_returned, search_params)

            break if resolved_one
          end
        end

        skip 'Could not resolve all parameters (patient, intent, encounter) in any resource.' unless resolved_one
      end

      test :search_by_patient_intent_authoredon do
        metadata do
          id '04'
          name 'Server returns valid results for MedicationRequest search by patient+intent+authoredon.'
          link 'http://hl7.org/fhir/us/core/STU3.1.1/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+intent+authoredon on the MedicationRequest resource.
            This test will pass if resources are returned and match the search criteria. If none are returned, the test is skipped.

              This will also test support for these authoredon comparators: gt, ge, lt, le. Comparator values are created by taking
              a authoredon value from a resource returned in the first search of this sequence and adding/subtracting a day. For example, a date
              of 05/05/2020 will create comparator values of lt2020-05-06 and gt2020-05-04

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
          next unless @medication_request_ary[patient].present?

          Array.wrap(@medication_request_ary[patient]).each do |medication_request|
            search_params = {
              'patient': patient,
              'intent': get_value_for_search_param(resolve_element_from_path(medication_request, 'intent') { |el| get_value_for_search_param(el).present? }),
              'authoredon': get_value_for_search_param(resolve_element_from_path(medication_request, 'authoredOn') { |el| get_value_for_search_param(el).present? })
            }

            next if search_params.any? { |_param, value| value.nil? }

            resolved_one = true

            reply = get_resource_by_params(versioned_resource_class('MedicationRequest'), search_params)

            reply = perform_search_with_status(reply, search_params, search_method: :get) if reply.code == 400

            validate_search_reply(versioned_resource_class('MedicationRequest'), reply, search_params)

            resources_returned = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
            assert(resources_returned.all? { |resource| ['MedicationRequest', 'OperationOutcome'].include? resource.resourceType },
                   'All resources returned must be of the type MedicationRequest or OperationOutcome')
            resources_returned.reject! { |resource| resource.resourceType == 'OperationOutcome' }
            test_medication_inclusion(resources_returned, search_params)

            break if resolved_one
          end
        end

        skip 'Could not resolve all parameters (patient, intent, authoredon) in any resource.' unless resolved_one
      end

      test :read_interaction do
        metadata do
          id '05'
          name 'Server returns correct MedicationRequest resource from MedicationRequest read interaction'
          link 'http://hl7.org/fhir/us/core/STU3.1.1/CapabilityStatement-us-core-server.html'
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
          link 'http://hl7.org/fhir/us/core/STU3.1.1/CapabilityStatement-us-core-server.html'
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
          link 'http://hl7.org/fhir/us/core/STU3.1.1/CapabilityStatement-us-core-server.html'
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

      test 'Server returns the appropriate resource from the following patient + intent +  _includes: MedicationRequest:medication' do
        metadata do
          id '08'
          link 'https://www.hl7.org/fhir/search.html#include'
          optional
          description %(

            A Server SHOULD be capable of supporting the following _includes: MedicationRequest:medication
            This test will perform a search for patient + intent + each of the following  _includes: MedicationRequest:medication
            The test will fail unless resources for MedicationRequest:medication are returned in their search.

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

            A Server SHALL be capable of supporting the following _revincludes: Provenance:target.

            This test will perform a search for patient + intent + _revIncludes: Provenance:target and will pass
            if a Provenance resource is found in the reponse.

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

          reply = perform_search_with_status(reply, search_params, search_method: :get) if reply.code == 400

          assert_response_ok(reply)
          assert_bundle_response(reply)
          provenance_results += fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
            .select { |resource| resource.resourceType == 'Provenance' }
        end
        save_resource_references(versioned_resource_class('Provenance'), provenance_results)
        save_delayed_sequence_references(provenance_results, USCore311ProvenanceSequenceDefinitions::DELAYED_REFERENCES)
        skip 'Could not resolve all parameters (patient, intent) in any resource.' unless resolved_one
        skip 'No Provenance resources were returned from this search' unless provenance_results.present?
      end

      test :validate_resources do
        metadata do
          id '10'
          name 'MedicationRequest resources returned during previous tests conform to the US Core MedicationRequest Profile.'
          link 'http://hl7.org/fhir/us/core/STU3.1.1/StructureDefinition/us-core-medicationrequest'
          description %(

            This test verifies resources returned from the first search conform to the [US Core MedicationRequest Profile](http://hl7.org/fhir/us/core/STU3.1.1/StructureDefinition/us-core-medicationrequest).
            It verifies the presence of manditory elements and that elements with required bindgings contain appropriate values.
            CodeableConcept element bindings will fail if none of its codings have a code/system that is part of the bound ValueSet.
            Quantity, Coding, and code element bindings will fail if its code/system is not found in the valueset.

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'MedicationRequest', delayed: false)
        test_resources_against_profile('MedicationRequest')
        bindings = USCore311MedicationrequestSequenceDefinitions::BINDINGS
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
        assert invalid_binding_messages.blank?, "#{invalid_binding_messages.count} invalid required #{'binding'.pluralize(invalid_binding_messages.count)}" \
        " found in #{invalid_binding_resources.count} #{'resource'.pluralize(invalid_binding_resources.count)}: " \
        "#{invalid_binding_messages.join('. ')}"

        bindings.select { |binding_def| binding_def[:strength] == 'extensible' }.each do |binding_def|
          begin
            invalid_bindings = resources_with_invalid_binding(binding_def, @medication_request_ary&.values&.flatten)
            binding_def_new = binding_def
            # If the valueset binding wasn't valid, check if the codes are in the stated codesystem
            if invalid_bindings.present?
              invalid_bindings = resources_with_invalid_binding(binding_def.except(:system), @medication_request_ary&.values&.flatten)
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

      test :validate_medication_resources do
        metadata do
          id '11'
          name 'Medication resources returned conform to US Core v3.1.1 profiles'
          link 'http://hl7.org/fhir/us/core/STU3.1.1/StructureDefinition/us-core-medicationrequest'
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
          link 'http://hl7.org/fhir/us/core/STU3.1.1/general-guidance.html#must-support'
          description %(

            US Core Responders SHALL be capable of populating all data elements as part of the query results as specified by the US Core Server Capability Statement.
            This will look through the MedicationRequest resources found previously for the following must support elements:

            * authoredOn
            * dosageInstruction
            * dosageInstruction.text
            * encounter
            * intent
            * medication[x]
            * reported[x]
            * requester
            * status
            * subject

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'MedicationRequest', delayed: false)
        must_supports = USCore311MedicationrequestSequenceDefinitions::MUST_SUPPORTS

        missing_must_support_elements = must_supports[:elements].reject do |element|
          @medication_request_ary&.values&.flatten&.any? do |resource|
            value_found = resolve_element_from_path(resource, element[:path]) do |value|
              value_without_extensions = value.respond_to?(:to_hash) ? value.to_hash.reject { |key, _| key == 'extension' } : value
              (value_without_extensions.present? || value_without_extensions == false) && (element[:fixed_value].blank? || value == element[:fixed_value])
            end

            # Note that false.present? => false, which is why we need to add this extra check
            value_found.present? || value_found == false
          end
        end
        missing_must_support_elements.map! { |must_support| "#{must_support[:path]}#{': ' + must_support[:fixed_value] if must_support[:fixed_value].present?}" }

        skip_if missing_must_support_elements.present?,
                "Could not find #{missing_must_support_elements.join(', ')} in the #{@medication_request_ary&.values&.flatten&.length} provided MedicationRequest resource(s)"
        @instance.save!
      end

      test 'The server returns results when parameters use composite-or' do
        metadata do
          id '13'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-medicationrequest'
          description %(

            This test will check if the server is capable of returning results for composite search parameters.
            The test will look through the resources returned from the first search to identify two different values
            to use for the parameter being tested. If no two different values can be found, then the test is skipped.
            [FHIR Composite Search Guideline](https://www.hl7.org/fhir/search.html#combining)

          Parameters being tested: status, intent

          )
          versions :r4
        end

        skip_if_known_search_not_supported('MedicationRequest', ['patient', 'intent'])
        resolved_one = false
        composite_or_parameters = ['intent']

        patient_ids.each do |patient|
          next unless @medication_request_ary[patient].present?

          search_params = {
            'patient': patient,
            'intent': 'proposal,plan,order,original-order,reflex-order,filler-order,instance-order,option'
          }

          existing_values = {
            intent: []
          }

          missing_values = {
            intent: []
          }

          composite_or_parameters.each do |param|
            existing_values[param.to_sym] = @medication_request_ary[patient].map(&param.to_sym).compact.uniq
          end

          next if existing_values.values.any?(&:empty?)

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('MedicationRequest'), search_params)
          validate_search_reply(versioned_resource_class('MedicationRequest'), reply, search_params)
          resources_returned = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
          applicable_resources_returned = resources_returned.reject { |entry| entry.class == FHIR::OperationOutcome }
          composite_or_parameters.each do |param|
            missing_values[param.to_sym] = existing_values[param.to_sym] - applicable_resources_returned.map(&param.to_sym)
          end

          missing_value_message = missing_values.reject { |_k, v| v.empty? }.map { |k, v| "#{v.join(',')} values from #{k}" }.join(' and ')

          assert missing_value_message.blank?, "Could not find #{missing_value_message} in any of the resources returned"

          break if resolved_one
        end

        skip_if_known_search_not_supported('MedicationRequest', ['patient', 'intent', 'status'])
        resolved_one = false
        composite_or_parameters = ['intent', 'status']

        patient_ids.each do |patient|
          next unless @medication_request_ary[patient].present?

          search_params = {
            'patient': patient,
            'intent': 'proposal,plan,order,original-order,reflex-order,filler-order,instance-order,option',
            'status': 'active,on-hold,cancelled,completed,entered-in-error,stopped,draft,unknown'
          }

          existing_values = {
            intent: [],
            status: []
          }

          missing_values = {
            intent: [],
            status: []
          }

          composite_or_parameters.each do |param|
            existing_values[param.to_sym] = @medication_request_ary[patient].map(&param.to_sym).compact.uniq
          end

          next if existing_values.values.any?(&:empty?)

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('MedicationRequest'), search_params)
          validate_search_reply(versioned_resource_class('MedicationRequest'), reply, search_params)
          resources_returned = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
          applicable_resources_returned = resources_returned.reject { |entry| entry.class == FHIR::OperationOutcome }
          composite_or_parameters.each do |param|
            missing_values[param.to_sym] = existing_values[param.to_sym] - applicable_resources_returned.map(&param.to_sym)
          end

          missing_value_message = missing_values.reject { |_k, v| v.empty? }.map { |k, v| "#{v.join(',')} values from #{k}" }.join(' and ')

          assert missing_value_message.blank?, "Could not find #{missing_value_message} in any of the resources returned"

          break if resolved_one
        end
      end

      test 'Every reference within MedicationRequest resources can be read.' do
        metadata do
          id '14'
          link 'http://hl7.org/fhir/references.html'
          description %(

            This test will attempt to read the first 50 reference found in the resources from the first search.
            The test will fail if Inferno fails to read any of those references.

          )
          versions :r4
        end

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
