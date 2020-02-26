# frozen_string_literal: true

require_relative './data_absent_reason_checker'

module Inferno
  module Sequence
    class USCore310DiagnosticreportNoteSequence < SequenceBase
      include Inferno::DataAbsentReasonChecker

      title 'DiagnosticReport for Report and Note exchange Tests'

      description 'Verify that DiagnosticReport resources on the FHIR server follow the US Core Implementation Guide'

      test_id_prefix 'USCDRRN'

      requires :token, :patient_ids
      conformance_supports :DiagnosticReport

      def validate_resource_item(resource, property, value)
        case property

        when 'status'
          value_found = resolve_element_from_path(resource, 'status') { |value_in_resource| value.split(',').include? value_in_resource }
          assert value_found.present?, 'status on resource does not match status requested'

        when 'patient'
          value_found = resolve_element_from_path(resource, 'subject.reference') { |reference| [value, 'Patient/' + value].include? reference }
          assert value_found.present?, 'patient on resource does not match patient requested'

        when 'category'
          value_found = resolve_element_from_path(resource, 'category.coding.code') { |value_in_resource| value.split(',').include? value_in_resource }
          assert value_found.present?, 'category on resource does not match category requested'

        when 'code'
          value_found = resolve_element_from_path(resource, 'code.coding.code') { |value_in_resource| value.split(',').include? value_in_resource }
          assert value_found.present?, 'code on resource does not match code requested'

        when 'date'
          value_found = resolve_element_from_path(resource, 'effective') { |date| validate_date_search(value, date) }
          assert value_found.present?, 'date on resource does not match date requested'

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
          assert @instance.server_capabilities&.search_documented?('DiagnosticReport'),
                 %(Server returned a status of 400 with an OperationOutcome, but the
                search interaction for this resource is not documented in the
                CapabilityStatement. If this response was due to the server
                requiring a status parameter, the server must document this
                requirement in its CapabilityStatement.)
        end

        ['registered,partial,preliminary,final,amended,corrected,appended,cancelled,entered-in-error,unknown'].each do |status_value|
          params_with_status = search_param.merge('status': status_value)
          reply = get_resource_by_params(versioned_resource_class('DiagnosticReport'), params_with_status)
          assert_response_ok(reply)
          assert_bundle_response(reply)

          entries = reply.resource.entry.select { |entry| entry.resource.resourceType == 'DiagnosticReport' }
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

      test :search_by_patient_category do
        metadata do
          id '01'
          name 'Server returns expected results from DiagnosticReport search by patient+category'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by patient+category on the DiagnosticReport resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('DiagnosticReport', ['patient', 'category'])
        @diagnostic_report_ary = {}
        @resources_found = false

        category_val = ['LP29684-5', 'LP29708-2', 'LP7839-6']
        patient_ids.each do |patient|
          @diagnostic_report_ary[patient] = []
          category_val.each do |val|
            search_params = { 'patient': patient, 'category': val }
            reply = get_resource_by_params(versioned_resource_class('DiagnosticReport'), search_params)

            reply = perform_search_with_status(reply, search_params) if reply.code == 400

            assert_response_ok(reply)
            assert_bundle_response(reply)

            next unless reply&.resource&.entry&.any? { |entry| entry&.resource&.resourceType == 'DiagnosticReport' }

            @resources_found = true
            @diagnostic_report = reply.resource.entry
              .find { |entry| entry&.resource&.resourceType == 'DiagnosticReport' }
              .resource
            @diagnostic_report_ary[patient] += fetch_all_bundled_resources(reply, check_for_data_absent_reasons)

            save_resource_references(versioned_resource_class('DiagnosticReport'), @diagnostic_report_ary[patient], Inferno::ValidationUtil::US_CORE_R4_URIS[:diagnostic_report_note])
            save_delayed_sequence_references(@diagnostic_report_ary[patient])
            validate_reply_entries(@diagnostic_report_ary[patient], search_params)

            break
          end
        end
        skip_if_not_found(resource_type: 'DiagnosticReport', delayed: false)
      end

      test :search_by_patient do
        metadata do
          id '02'
          name 'Server returns expected results from DiagnosticReport search by patient'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by patient on the DiagnosticReport resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('DiagnosticReport', ['patient'])
        skip_if_not_found(resource_type: 'DiagnosticReport', delayed: false)

        patient_ids.each do |patient|
          search_params = {
            'patient': patient
          }

          reply = get_resource_by_params(versioned_resource_class('DiagnosticReport'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          validate_search_reply(versioned_resource_class('DiagnosticReport'), reply, search_params)
        end
      end

      test :search_by_patient_code do
        metadata do
          id '03'
          name 'Server returns expected results from DiagnosticReport search by patient+code'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by patient+code on the DiagnosticReport resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('DiagnosticReport', ['patient', 'code'])
        skip_if_not_found(resource_type: 'DiagnosticReport', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'code': get_value_for_search_param(resolve_element_from_path(@diagnostic_report_ary[patient], 'code'))
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('DiagnosticReport'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          validate_search_reply(versioned_resource_class('DiagnosticReport'), reply, search_params)
        end

        skip 'Could not resolve all parameters (patient, code) in any resource.' unless resolved_one
      end

      test :search_by_patient_category_date do
        metadata do
          id '04'
          name 'Server returns expected results from DiagnosticReport search by patient+category+date'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by patient+category+date on the DiagnosticReport resource

              including support for these date comparators: gt, lt, le, ge
          )
          versions :r4
        end

        skip_if_known_search_not_supported('DiagnosticReport', ['patient', 'category', 'date'])
        skip_if_not_found(resource_type: 'DiagnosticReport', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'category': get_value_for_search_param(resolve_element_from_path(@diagnostic_report_ary[patient], 'category')),
            'date': get_value_for_search_param(resolve_element_from_path(@diagnostic_report_ary[patient], 'effective'))
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('DiagnosticReport'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          validate_search_reply(versioned_resource_class('DiagnosticReport'), reply, search_params)

          ['gt', 'lt', 'le', 'ge'].each do |comparator|
            comparator_val = date_comparator_value(comparator, search_params[:date])
            comparator_search_params = search_params.merge('date': comparator_val)
            reply = get_resource_by_params(versioned_resource_class('DiagnosticReport'), comparator_search_params)
            validate_search_reply(versioned_resource_class('DiagnosticReport'), reply, comparator_search_params)
          end
        end

        skip 'Could not resolve all parameters (patient, category, date) in any resource.' unless resolved_one
      end

      test :search_by_patient_status do
        metadata do
          id '05'
          name 'Server returns expected results from DiagnosticReport search by patient+status'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+status on the DiagnosticReport resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('DiagnosticReport', ['patient', 'status'])
        skip_if_not_found(resource_type: 'DiagnosticReport', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'status': get_value_for_search_param(resolve_element_from_path(@diagnostic_report_ary[patient], 'status'))
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('DiagnosticReport'), search_params)

          validate_search_reply(versioned_resource_class('DiagnosticReport'), reply, search_params)
        end

        skip 'Could not resolve all parameters (patient, status) in any resource.' unless resolved_one
      end

      test :search_by_patient_code_date do
        metadata do
          id '06'
          name 'Server returns expected results from DiagnosticReport search by patient+code+date'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+code+date on the DiagnosticReport resource

              including support for these date comparators: gt, lt, le, ge
          )
          versions :r4
        end

        skip_if_known_search_not_supported('DiagnosticReport', ['patient', 'code', 'date'])
        skip_if_not_found(resource_type: 'DiagnosticReport', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'code': get_value_for_search_param(resolve_element_from_path(@diagnostic_report_ary[patient], 'code')),
            'date': get_value_for_search_param(resolve_element_from_path(@diagnostic_report_ary[patient], 'effective'))
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('DiagnosticReport'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          validate_search_reply(versioned_resource_class('DiagnosticReport'), reply, search_params)

          ['gt', 'lt', 'le', 'ge'].each do |comparator|
            comparator_val = date_comparator_value(comparator, search_params[:date])
            comparator_search_params = search_params.merge('date': comparator_val)
            reply = get_resource_by_params(versioned_resource_class('DiagnosticReport'), comparator_search_params)
            validate_search_reply(versioned_resource_class('DiagnosticReport'), reply, comparator_search_params)
          end
        end

        skip 'Could not resolve all parameters (patient, code, date) in any resource.' unless resolved_one
      end

      test :read_interaction do
        metadata do
          id '07'
          name 'Server returns correct DiagnosticReport resource from DiagnosticReport read interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(
            A server SHALL support the DiagnosticReport read interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:DiagnosticReport, [:read])
        skip_if_not_found(resource_type: 'DiagnosticReport', delayed: false)

        validate_read_reply(@diagnostic_report, versioned_resource_class('DiagnosticReport'), check_for_data_absent_reasons)
      end

      test :vread_interaction do
        metadata do
          id '08'
          name 'Server returns correct DiagnosticReport resource from DiagnosticReport vread interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the DiagnosticReport vread interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:DiagnosticReport, [:vread])
        skip_if_not_found(resource_type: 'DiagnosticReport', delayed: false)

        validate_vread_reply(@diagnostic_report, versioned_resource_class('DiagnosticReport'))
      end

      test :history_interaction do
        metadata do
          id '09'
          name 'Server returns correct DiagnosticReport resource from DiagnosticReport history interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the DiagnosticReport history interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:DiagnosticReport, [:history])
        skip_if_not_found(resource_type: 'DiagnosticReport', delayed: false)

        validate_history_reply(@diagnostic_report, versioned_resource_class('DiagnosticReport'))
      end

      test 'Server returns Provenance resources from DiagnosticReport search by patient + category + _revIncludes: Provenance:target' do
        metadata do
          id '10'
          link 'https://www.hl7.org/fhir/search.html#revinclude'
          description %(
            A Server SHALL be capable of supporting the following _revincludes: Provenance:target
          )
          versions :r4
        end

        skip_if_known_revinclude_not_supported('DiagnosticReport', 'Provenance:target')
        skip_if_not_found(resource_type: 'DiagnosticReport', delayed: false)

        resolved_one = false

        provenance_results = []
        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'category': get_value_for_search_param(resolve_element_from_path(@diagnostic_report_ary[patient], 'category'))
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          search_params['_revinclude'] = 'Provenance:target'
          reply = get_resource_by_params(versioned_resource_class('DiagnosticReport'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          assert_response_ok(reply)
          assert_bundle_response(reply)
          provenance_results += fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
            .select { |resource| resource.resourceType == 'Provenance' }
        end
        save_resource_references(versioned_resource_class('Provenance'), provenance_results)
        save_delayed_sequence_references(provenance_results)
        skip 'Could not resolve all parameters (patient, category) in any resource.' unless resolved_one
        skip 'No Provenance resources were returned from this search' unless provenance_results.present?
      end

      test :validate_resources do
        metadata do
          id '11'
          name 'DiagnosticReport resources returned conform to US Core R4 profiles'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-diagnosticreport-note'
          description %(

            This test checks if the resources returned from prior searches conform to the US Core profiles.
            This includes checking for missing data elements and valueset verification.

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'DiagnosticReport', delayed: false)
        test_resources_against_profile('DiagnosticReport', Inferno::ValidationUtil::US_CORE_R4_URIS[:diagnostic_report_note])
        bindings = [
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/diagnostic-report-status',
            path: 'status'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-diagnosticreport-category',
            path: 'category'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-diagnosticreport-report-and-note-codes',
            path: 'code'
          }
        ]
        invalid_bindings = []
        bindings.select { |binding_def| binding_def[:strength] == 'required' }.each do |binding_def|
          invalid_binding_found = find_invalid_binding(binding_def, @diagnostic_report_ary&.values&.flatten)
          invalid_bindings << binding_def[:path] if invalid_binding_found.present?
        end
        assert invalid_bindings.blank?, "invalid required code found: #{invalid_bindings.join(',')}"

        bindings.select { |binding_def| binding_def[:strength] == 'extensible' }.each do |binding_def|
          invalid_binding_found = find_invalid_binding(binding_def, @diagnostic_report_ary&.values&.flatten)
          invalid_bindings << binding_def[:path] if invalid_binding_found.present?
        end
        warning do
          assert invalid_bindings.blank?, "invalid extensible code found: #{invalid_bindings.join(',')}"
        end
      end

      test 'All must support elements are provided in the DiagnosticReport resources returned.' do
        metadata do
          id '12'
          link 'http://www.hl7.org/fhir/us/core/general-guidance.html#must-support'
          description %(

            US Core Responders SHALL be capable of populating all data elements as part of the query results as specified by the US Core Server Capability Statement.
            This will look through all DiagnosticReport resources returned from prior searches to see if any of them provide the following must support elements:

            DiagnosticReport.status

            DiagnosticReport.category

            DiagnosticReport.code

            DiagnosticReport.subject

            DiagnosticReport.encounter

            DiagnosticReport.effective[x]

            DiagnosticReport.issued

            DiagnosticReport.performer

            DiagnosticReport.presentedForm

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'DiagnosticReport', delayed: false)

        must_support_elements = [
          { path: 'DiagnosticReport.status' },
          { path: 'DiagnosticReport.category' },
          { path: 'DiagnosticReport.code' },
          { path: 'DiagnosticReport.subject' },
          { path: 'DiagnosticReport.encounter' },
          { path: 'DiagnosticReport.effective' },
          { path: 'DiagnosticReport.issued' },
          { path: 'DiagnosticReport.performer' },
          { path: 'DiagnosticReport.presentedForm' }
        ]

        missing_must_support_elements = must_support_elements.reject do |element|
          truncated_path = element[:path].gsub('DiagnosticReport.', '')
          @diagnostic_report_ary&.values&.flatten&.any? do |resource|
            value_found = resolve_element_from_path(resource, truncated_path) { |value| element[:fixed_value].blank? || value == element[:fixed_value] }
            value_found.present?
          end
        end
        missing_must_support_elements.map! { |must_support| "#{must_support[:path]}#{': ' + must_support[:fixed_value] if must_support[:fixed_value].present?}" }

        skip_if missing_must_support_elements.present?,
                "Could not find #{missing_must_support_elements.join(', ')} in the #{@diagnostic_report_ary&.values&.flatten&.length} provided DiagnosticReport resource(s)"
        @instance.save!
      end

      test 'Every reference within DiagnosticReport resource is valid and can be read.' do
        metadata do
          id '13'
          link 'http://hl7.org/fhir/references.html'
          description %(
            This test checks if references found in resources from prior searches can be resolved.
          )
          versions :r4
        end

        skip_if_known_not_supported(:DiagnosticReport, [:search, :read])
        skip_if_not_found(resource_type: 'DiagnosticReport', delayed: false)

        validated_resources = Set.new
        max_resolutions = 50

        @diagnostic_report_ary&.values&.flatten&.each do |resource|
          validate_reference_resolutions(resource, validated_resources, max_resolutions) if validated_resources.length < max_resolutions
        end
      end
    end
  end
end
