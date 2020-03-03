# frozen_string_literal: true

require_relative './data_absent_reason_checker'

module Inferno
  module Sequence
    class USCore310ConditionSequence < SequenceBase
      include Inferno::DataAbsentReasonChecker

      title 'Condition'

      description 'Verify that Condition resources on the FHIR server follow the US Core Implementation Guide'

      test_id_prefix 'USCC'

      requires :token, :patient_ids
      conformance_supports :Condition

      def validate_resource_item(resource, property, value)
        case property

        when 'category'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'category.coding.code') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'category on resource does not match category requested'

        when 'clinical-status'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'clinicalStatus.coding.code') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'clinical-status on resource does not match clinical-status requested'

        when 'patient'
          value_found = resolve_element_from_path(resource, 'subject.reference') { |reference| [value, 'Patient/' + value].include? reference }
          assert value_found.present?, 'patient on resource does not match patient requested'

        when 'onset-date'
          value_found = resolve_element_from_path(resource, 'onsetDateTime') { |date| validate_date_search(value, date) }
          assert value_found.present?, 'onset-date on resource does not match onset-date requested'

        when 'code'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'code.coding.code') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'code on resource does not match code requested'

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
          name 'Server returns expected results from Condition search by patient'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by patient on the Condition resource

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
          save_delayed_sequence_references(@condition_ary[patient])
          validate_reply_entries(@condition_ary[patient], search_params)
        end

        skip_if_not_found(resource_type: 'Condition', delayed: false)
      end

      test :search_by_patient_category do
        metadata do
          id '02'
          name 'Server returns expected results from Condition search by patient+category'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+category on the Condition resource

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
        end

        skip 'Could not resolve all parameters (patient, category) in any resource.' unless resolved_one
      end

      test :search_by_patient_onset_date do
        metadata do
          id '03'
          name 'Server returns expected results from Condition search by patient+onset-date'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+onset-date on the Condition resource

              including support for these onset-date comparators: gt, lt, le, ge
          )
          versions :r4
        end

        skip_if_known_search_not_supported('Condition', ['patient', 'onset-date'])
        skip_if_not_found(resource_type: 'Condition', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'onset-date': get_value_for_search_param(resolve_element_from_path(@condition_ary[patient], 'onsetDateTime') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('Condition'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          validate_search_reply(versioned_resource_class('Condition'), reply, search_params)

          ['gt', 'lt', 'le', 'ge'].each do |comparator|
            comparator_val = date_comparator_value(comparator, search_params[:'onset-date'])
            comparator_search_params = search_params.merge('onset-date': comparator_val)
            reply = get_resource_by_params(versioned_resource_class('Condition'), comparator_search_params)
            validate_search_reply(versioned_resource_class('Condition'), reply, comparator_search_params)
          end
        end

        skip 'Could not resolve all parameters (patient, onset-date) in any resource.' unless resolved_one
      end

      test :search_by_patient_clinical_status do
        metadata do
          id '04'
          name 'Server returns expected results from Condition search by patient+clinical-status'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+clinical-status on the Condition resource

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
        end

        skip 'Could not resolve all parameters (patient, clinical-status) in any resource.' unless resolved_one
      end

      test :search_by_patient_code do
        metadata do
          id '05'
          name 'Server returns expected results from Condition search by patient+code'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+code on the Condition resource

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
        end

        skip 'Could not resolve all parameters (patient, code) in any resource.' unless resolved_one
      end

      test :read_interaction do
        metadata do
          id '06'
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
          id '07'
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
          id '08'
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
          id '09'
          link 'https://www.hl7.org/fhir/search.html#revinclude'
          description %(
            A Server SHALL be capable of supporting the following _revincludes: Provenance:target
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
        save_delayed_sequence_references(provenance_results)

        skip 'No Provenance resources were returned from this search' unless provenance_results.present?
      end

      test :validate_resources do
        metadata do
          id '10'
          name 'Condition resources returned conform to US Core R4 profiles'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-condition'
          description %(

            This test checks if the resources returned from prior searches conform to the US Core profiles.
            This includes checking for missing data elements and valueset verification.

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

        bindings = [
          {
            type: 'CodeableConcept',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/condition-clinical',
            path: 'clinicalStatus'
          },
          {
            type: 'CodeableConcept',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/condition-ver-status',
            path: 'verificationStatus'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-condition-category',
            path: 'category'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-condition-code',
            path: 'code'
          }
        ]
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
        assert invalid_binding_messages.blank?, "#{invalid_binding_messages.count} invalid required binding(s) found in #{invalid_binding_resources.count} resources:" \
                                                "#{invalid_binding_messages.join('. ')}"

        bindings.select { |binding_def| binding_def[:strength] == 'extensible' }.each do |binding_def|
          begin
            invalid_bindings = resources_with_invalid_binding(binding_def, @condition_ary&.values&.flatten)
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

      test 'All must support elements are provided in the Condition resources returned.' do
        metadata do
          id '11'
          link 'http://www.hl7.org/fhir/us/core/general-guidance.html#must-support'
          description %(

            US Core Responders SHALL be capable of populating all data elements as part of the query results as specified by the US Core Server Capability Statement.
            This will look through all Condition resources returned from prior searches to see if any of them provide the following must support elements:

            Condition.clinicalStatus

            Condition.verificationStatus

            Condition.category

            Condition.code

            Condition.subject

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'Condition', delayed: false)

        must_support_elements = [
          { path: 'Condition.clinicalStatus' },
          { path: 'Condition.verificationStatus' },
          { path: 'Condition.category' },
          { path: 'Condition.code' },
          { path: 'Condition.subject' }
        ]

        missing_must_support_elements = must_support_elements.reject do |element|
          truncated_path = element[:path].gsub('Condition.', '')
          @condition_ary&.values&.flatten&.any? do |resource|
            value_found = resolve_element_from_path(resource, truncated_path) { |value| element[:fixed_value].blank? || value == element[:fixed_value] }
            value_found.present?
          end
        end
        missing_must_support_elements.map! { |must_support| "#{must_support[:path]}#{': ' + must_support[:fixed_value] if must_support[:fixed_value].present?}" }

        skip_if missing_must_support_elements.present?,
                "Could not find #{missing_must_support_elements.join(', ')} in the #{@condition_ary&.values&.flatten&.length} provided Condition resource(s)"
        @instance.save!
      end

      test 'Every reference within Condition resource is valid and can be read.' do
        metadata do
          id '12'
          link 'http://hl7.org/fhir/references.html'
          description %(
            This test checks if references found in resources from prior searches can be resolved.
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
