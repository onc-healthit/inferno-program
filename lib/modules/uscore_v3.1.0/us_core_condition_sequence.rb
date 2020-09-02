# frozen_string_literal: true

require_relative './data_absent_reason_checker'
require_relative './profile_definitions/us_core_condition_definitions'

module Inferno
  module Sequence
    class USCore310ConditionSequence < SequenceBase
      include Inferno::DataAbsentReasonChecker
      include Inferno::USCore310ProfileDefinitions

      title 'Condition Tests'

      description 'Verify support for the server capabilities required by the US Core Condition Profile.'

      details %(
        # Background

        The US Core #{title} sequence verifies that the system under test is able to provide correct responses
        for Condition queries.  These queries must contain resources conforming to US Core Condition Profile as specified
        in the US Core v3.1.0 Implementation Guide.

        # Testing Methodology


        ## Searching
        This test sequence will first perform each required search associated with this resource. This sequence will perform searches
        with the following parameters:

          * patient



        ### Search Parameters
        The first search uses the selected patient(s) from the prior launch sequence. Any subsequent searches will look for its
        parameter values from the results of the first search. For example, the `identifier` search in the patient sequence is
        performed by looking for an existing `Patient.identifier` from any of the resources returned in the `_id` search. If a
        value cannot be found this way, the search is skipped.

        ### Search Validation
        Inferno will retrieve up to the first 20 bundle pages of the reply for Condition resources and save them
        for subsequent tests.
        Each of these resources is then checked to see if it matches the searched parameters in accordance
        with [FHIR search guidelines](https://www.hl7.org/fhir/search.html). The test will fail, for example, if a patient search
        for gender=male returns a female patient.

        ## Must Support
        Each profile has a list of elements marked as "must support". This test sequence expects to see each of these elements
        at least once. If at least one cannot be found, the test will fail. The test will look through the Condition
        resources found for these elements.

        ## Profile Validation
        Each resource returned from the first search is expected to conform to the [US Core Condition Profile](http://hl7.org/fhir/us/core/StructureDefinition/us-core-condition).
        Each element is checked against teminology binding and cardinality requirements.

        Elements with a required binding is validated against its bound valueset. If the code/system in the element is not part
        of the valueset, then the test will fail.

        ## Reference Validation
        Each reference within the resources found from the first search must resolve. The test will attempt to read each reference found
        and will fail if any attempted read fails.
      )

      test_id_prefix 'USCC'

      requires :token, :patient_ids
      conformance_supports :Condition

      def validate_resource_item(resource, property, value)
        case property

        when 'category'
          values_found = resolve_path(resource, 'category')
          coding_system = value.split('|').first.empty? ? nil : value.split('|').first
          coding_value = value.split('|').last
          match_found = values_found.any? do |codeable_concept|
            if value.include? '|'
              codeable_concept.coding.any? { |coding| coding.system == coding_system && coding.code == coding_value }
            else
              codeable_concept.coding.any? { |coding| coding.code == value }
            end
          end
          assert match_found, "category in Condition/#{resource.id} (#{values_found}) does not match category requested (#{value})"

        when 'clinical-status'
          values_found = resolve_path(resource, 'clinicalStatus')
          coding_system = value.split('|').first.empty? ? nil : value.split('|').first
          coding_value = value.split('|').last
          match_found = values_found.any? do |codeable_concept|
            if value.include? '|'
              codeable_concept.coding.any? { |coding| coding.system == coding_system && coding.code == coding_value }
            else
              codeable_concept.coding.any? { |coding| coding.code == value }
            end
          end
          assert match_found, "clinical-status in Condition/#{resource.id} (#{values_found}) does not match clinical-status requested (#{value})"

        when 'patient'
          values_found = resolve_path(resource, 'subject.reference')
          value = value.split('Patient/').last
          match_found = values_found.any? { |reference| [value, 'Patient/' + value, "#{@instance.url}/Patient/#{value}"].include? reference }
          assert match_found, "patient in Condition/#{resource.id} (#{values_found}) does not match patient requested (#{value})"

        when 'onset-date'
          values_found = resolve_path(resource, 'onsetDateTime')
          match_found = values_found.any? { |date| validate_date_search(value, date) }
          assert match_found, "onset-date in Condition/#{resource.id} (#{values_found}) does not match onset-date requested (#{value})"

        when 'code'
          values_found = resolve_path(resource, 'code')
          coding_system = value.split('|').first.empty? ? nil : value.split('|').first
          coding_value = value.split('|').last
          match_found = values_found.any? do |codeable_concept|
            if value.include? '|'
              codeable_concept.coding.any? { |coding| coding.system == coding_system && coding.code == coding_value }
            else
              codeable_concept.coding.any? { |coding| coding.code == value }
            end
          end
          assert match_found, "code in Condition/#{resource.id} (#{values_found}) does not match code requested (#{value})"

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
          assert @instance.server_capabilities&.search_documented?('Condition'),
                 %(Server returned a status of 400 with an OperationOutcome, but the
                search interaction for this resource is not documented in the
                CapabilityStatement. If this response was due to the server
                requiring a status parameter, the server must document this
                requirement in its CapabilityStatement.)
        end

        ['active', 'recurrence', 'relapse', 'inactive', 'remission', 'resolved'].each do |status_value|
          params_with_status = search_param.merge('clinical-status': status_value)
          reply = get_resource_by_params(versioned_resource_class('Condition'), params_with_status)
          assert_response_ok(reply)
          assert_bundle_response(reply)

          entries = reply.resource.entry.select { |entry| entry.resource.resourceType == 'Condition' }
          next if entries.blank?

          search_param.merge!('clinical-status': status_value)
          break
        end

        reply
      end

      def patient_ids
        @instance.patient_ids.split(',').map(&:strip)
      end

      @resources_found = false

      test :search_by_patient do
        metadata do
          id '01'
          name 'Server returns valid results for Condition search by patient.'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by patient on the Condition resource.
            This test will pass if resources are returned and match the search criteria. If none are returned, the test is skipped.
            Because this is the first search of the sequence, resources in the response will be used for subsequent tests.
          )
          versions :r4
        end

        skip_if_known_search_not_supported('Condition', ['patient'])
        @condition_ary = {}
        patient_ids.each do |patient|
          search_params = {
            'patient': patient
          }

          reply = get_resource_by_params(versioned_resource_class('Condition'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          assert_response_ok(reply)
          assert_bundle_response(reply)

          any_resources = reply&.resource&.entry&.any? { |entry| entry&.resource&.resourceType == 'Condition' }

          next unless any_resources

          @condition_ary[patient] = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)

          @condition = @condition_ary[patient]
            .find { |resource| resource.resourceType == 'Condition' }
          @resources_found = @condition.present?

          save_resource_references(versioned_resource_class('Condition'), @condition_ary[patient])
          save_delayed_sequence_references(@condition_ary[patient], USCore310ConditionSequenceDefinitions::DELAYED_REFERENCES)
          validate_reply_entries(@condition_ary[patient], search_params)

          search_params = search_params.merge('patient': "Patient/#{patient}")
          reply = get_resource_by_params(versioned_resource_class('Condition'), search_params)
          assert_response_ok(reply)
          assert_bundle_response(reply)
          search_with_type = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
          assert search_with_type.length == @condition_ary[patient].length, 'Expected search by Patient/ID to have the same results as search by ID'
        end

        skip_if_not_found(resource_type: 'Condition', delayed: false)
      end

      test :search_by_patient_category do
        metadata do
          id '02'
          name 'Server returns valid results for Condition search by patient+category.'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+category on the Condition resource.
            This test will pass if resources are returned and match the search criteria. If none are returned, the test is skipped.

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Condition', ['patient', 'category'])
        skip_if_not_found(resource_type: 'Condition', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'category': get_value_for_search_param(resolve_element_from_path(@condition_ary[patient], 'category') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('Condition'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          validate_search_reply(versioned_resource_class('Condition'), reply, search_params)

          value_with_system = get_value_for_search_param(resolve_element_from_path(@condition_ary[patient], 'category'), true)
          token_with_system_search_params = search_params.merge('category': value_with_system)
          reply = get_resource_by_params(versioned_resource_class('Condition'), token_with_system_search_params)
          validate_search_reply(versioned_resource_class('Condition'), reply, token_with_system_search_params)
        end

        skip 'Could not resolve all parameters (patient, category) in any resource.' unless resolved_one
      end

      test :search_by_patient_clinical_status do
        metadata do
          id '03'
          name 'Server returns valid results for Condition search by patient+clinical-status.'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+clinical-status on the Condition resource.
            This test will pass if resources are returned and match the search criteria. If none are returned, the test is skipped.

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Condition', ['patient', 'clinical-status'])
        skip_if_not_found(resource_type: 'Condition', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'clinical-status': get_value_for_search_param(resolve_element_from_path(@condition_ary[patient], 'clinicalStatus') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('Condition'), search_params)

          validate_search_reply(versioned_resource_class('Condition'), reply, search_params)

          value_with_system = get_value_for_search_param(resolve_element_from_path(@condition_ary[patient], 'clinicalStatus'), true)
          token_with_system_search_params = search_params.merge('clinical-status': value_with_system)
          reply = get_resource_by_params(versioned_resource_class('Condition'), token_with_system_search_params)
          validate_search_reply(versioned_resource_class('Condition'), reply, token_with_system_search_params)
        end

        skip 'Could not resolve all parameters (patient, clinical-status) in any resource.' unless resolved_one
      end

      test :search_by_patient_code do
        metadata do
          id '04'
          name 'Server returns valid results for Condition search by patient+code.'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+code on the Condition resource.
            This test will pass if resources are returned and match the search criteria. If none are returned, the test is skipped.

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Condition', ['patient', 'code'])
        skip_if_not_found(resource_type: 'Condition', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'code': get_value_for_search_param(resolve_element_from_path(@condition_ary[patient], 'code') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('Condition'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          validate_search_reply(versioned_resource_class('Condition'), reply, search_params)

          value_with_system = get_value_for_search_param(resolve_element_from_path(@condition_ary[patient], 'code'), true)
          token_with_system_search_params = search_params.merge('code': value_with_system)
          reply = get_resource_by_params(versioned_resource_class('Condition'), token_with_system_search_params)
          validate_search_reply(versioned_resource_class('Condition'), reply, token_with_system_search_params)
        end

        skip 'Could not resolve all parameters (patient, code) in any resource.' unless resolved_one
      end

      test :read_interaction do
        metadata do
          id '05'
          name 'Server returns correct Condition resource from Condition read interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(
            A server SHALL support the Condition read interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Condition, [:read])
        skip_if_not_found(resource_type: 'Condition', delayed: false)

        validate_read_reply(@condition, versioned_resource_class('Condition'), check_for_data_absent_reasons)
      end

      test :vread_interaction do
        metadata do
          id '06'
          name 'Server returns correct Condition resource from Condition vread interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the Condition vread interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Condition, [:vread])
        skip_if_not_found(resource_type: 'Condition', delayed: false)

        validate_vread_reply(@condition, versioned_resource_class('Condition'))
      end

      test :history_interaction do
        metadata do
          id '07'
          name 'Server returns correct Condition resource from Condition history interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the Condition history interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Condition, [:history])
        skip_if_not_found(resource_type: 'Condition', delayed: false)

        validate_history_reply(@condition, versioned_resource_class('Condition'))
      end

      test 'Server returns Provenance resources from Condition search by patient + _revIncludes: Provenance:target' do
        metadata do
          id '08'
          link 'https://www.hl7.org/fhir/search.html#revinclude'
          description %(

            A Server SHALL be capable of supporting the following _revincludes: Provenance:target.

            This test will perform a search for patient + _revIncludes: Provenance:target and will pass
            if a Provenance resource is found in the reponse.

          )
          versions :r4
        end

        skip_if_known_revinclude_not_supported('Condition', 'Provenance:target')
        skip_if_not_found(resource_type: 'Condition', delayed: false)

        provenance_results = []
        patient_ids.each do |patient|
          search_params = {
            'patient': patient
          }

          search_params['_revinclude'] = 'Provenance:target'
          reply = get_resource_by_params(versioned_resource_class('Condition'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          assert_response_ok(reply)
          assert_bundle_response(reply)
          provenance_results += fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
            .select { |resource| resource.resourceType == 'Provenance' }
        end
        save_resource_references(versioned_resource_class('Provenance'), provenance_results)
        save_delayed_sequence_references(provenance_results, USCore310ConditionSequenceDefinitions::DELAYED_REFERENCES)

        skip 'No Provenance resources were returned from this search' unless provenance_results.present?
      end

      test :validate_resources do
        metadata do
          id '09'
          name 'Condition resources returned from previous search conform to the US Core Condition Profile.'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-condition'
          description %(

            This test verifies resources returned from the first search conform to the [US Core Condition Profile](http://hl7.org/fhir/us/core/StructureDefinition/us-core-condition).
            It verifies the presence of manditory elements and that elements with required bindgings contain appropriate values.
            CodeableConcept element bindings will fail if none of its codings have a code/system that is part of the bound ValueSet.
            Quantity, Coding, and code element bindings will fail if its code/system is not found in the valueset.

            This test also checks that the following CodeableConcepts with
            required ValueSet bindings include a code rather than just text:
            'clinicalStatus' and 'verificationStatus'

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'Condition', delayed: false)
        test_resources_against_profile('Condition') do |resource|
          ['clinicalStatus', 'verificationStatus'].flat_map do |path|
            concepts = resolve_path(resource, path)
            next if concepts.blank?

            code_present = concepts.any? { |concept| concept.coding.any? { |coding| coding.code.present? } }

            unless code_present # rubocop:disable Style/IfUnlessModifier
              "The CodeableConcept at '#{path}' is bound to a required ValueSet but does not contain any codes."
            end
          end.compact
        end

        bindings = USCore310ConditionSequenceDefinitions::BINDINGS
        invalid_binding_messages = []
        invalid_binding_resources = Set.new
        bindings.select { |binding_def| binding_def[:strength] == 'required' }.each do |binding_def|
          begin
            invalid_bindings = resources_with_invalid_binding(binding_def, @condition_ary&.values&.flatten)
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
            invalid_bindings = resources_with_invalid_binding(binding_def, @condition_ary&.values&.flatten)
            binding_def_new = binding_def
            # If the valueset binding wasn't valid, check if the codes are in the stated codesystem
            if invalid_bindings.present?
              invalid_bindings = resources_with_invalid_binding(binding_def.except(:system), @condition_ary&.values&.flatten)
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

      test 'All must support elements are provided in the Condition resources returned.' do
        metadata do
          id '10'
          link 'http://www.hl7.org/fhir/us/core/general-guidance.html#must-support'
          description %(

            US Core Responders SHALL be capable of populating all data elements as part of the query results as specified by the US Core Server Capability Statement.
            This will look through the Condition resources found previously for the following must support elements:

            * clinicalStatus
            * verificationStatus
            * category
            * code
            * subject
          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'Condition', delayed: false)
        must_supports = USCore310ConditionSequenceDefinitions::MUST_SUPPORTS

        missing_must_support_elements = must_supports[:elements].reject do |element|
          @condition_ary&.values&.flatten&.any? do |resource|
            value_found = resolve_element_from_path(resource, element[:path]) do |value|
              value_without_extensions = value.respond_to?(:to_hash) ? value.to_hash.reject { |key, _| key == 'extension' } : value
              value_without_extensions.present? && (element[:fixed_value].blank? || value == element[:fixed_value])
            end

            value_found.present?
          end
        end
        missing_must_support_elements.map! { |must_support| "#{must_support[:path]}#{': ' + must_support[:fixed_value] if must_support[:fixed_value].present?}" }

        skip_if missing_must_support_elements.present?,
                "Could not find #{missing_must_support_elements.join(', ')} in the #{@condition_ary&.values&.flatten&.length} provided Condition resource(s)"
        @instance.save!
      end

      test 'Every reference within Condition resources can be read.' do
        metadata do
          id '11'
          link 'http://hl7.org/fhir/references.html'
          description %(

            This test will attempt to read the first 50 reference found in the resources from the first search.
            The test will fail if Inferno fails to read any of those references.

          )
          versions :r4
        end

        skip_if_known_not_supported(:Condition, [:search, :read])
        skip_if_not_found(resource_type: 'Condition', delayed: false)

        validated_resources = Set.new
        max_resolutions = 50

        @condition_ary&.values&.flatten&.each do |resource|
          validate_reference_resolutions(resource, validated_resources, max_resolutions) if validated_resources.length < max_resolutions
        end
      end
    end
  end
end
