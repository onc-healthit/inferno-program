# frozen_string_literal: true

require_relative './data_absent_reason_checker'

module Inferno
  module Sequence
    class USCore310CareplanSequence < SequenceBase
      include Inferno::DataAbsentReasonChecker

      title 'CarePlan'

      description 'Verify that CarePlan resources on the FHIR server follow the US Core Implementation Guide'

      test_id_prefix 'USCCP'

      requires :token, :patient_ids
      conformance_supports :CarePlan

      def validate_resource_item(resource, property, value)
        case property

        when 'category'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'category.coding.code') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'category on resource does not match category requested'

        when 'date'
          value_found = resolve_element_from_path(resource, 'period') { |date| validate_date_search(value, date) }
          assert value_found.present?, 'date on resource does not match date requested'

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
          assert @instance.server_capabilities&.search_documented?('CarePlan'),
                 %(Server returned a status of 400 with an OperationOutcome, but the
                search interaction for this resource is not documented in the
                CapabilityStatement. If this response was due to the server
                requiring a status parameter, the server must document this
                requirement in its CapabilityStatement.)
        end

        ['draft,active,on-hold,revoked,completed,entered-in-error,unknown'].each do |status_value|
          params_with_status = search_param.merge('status': status_value)
          reply = get_resource_by_params(versioned_resource_class('CarePlan'), params_with_status)
          assert_response_ok(reply)
          assert_bundle_response(reply)

          entries = reply.resource.entry.select { |entry| entry.resource.resourceType == 'CarePlan' }
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
          name 'Server returns expected results from CarePlan search by patient+category'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by patient+category on the CarePlan resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('CarePlan', ['patient', 'category'])
        @care_plan_ary = {}
        @resources_found = false

        category_val = ['assess-plan']
        patient_ids.each do |patient|
          @care_plan_ary[patient] = []
          category_val.each do |val|
            search_params = { 'patient': patient, 'category': val }
            reply = get_resource_by_params(versioned_resource_class('CarePlan'), search_params)

            reply = perform_search_with_status(reply, search_params) if reply.code == 400

            assert_response_ok(reply)
            assert_bundle_response(reply)

            next unless reply&.resource&.entry&.any? { |entry| entry&.resource&.resourceType == 'CarePlan' }

            @resources_found = true
            resources_returned = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
            @care_plan = resources_returned.first
            @care_plan_ary[patient] += resources_returned

            save_resource_references(versioned_resource_class('CarePlan'), @care_plan_ary[patient])
            save_delayed_sequence_references(resources_returned)
            validate_reply_entries(resources_returned, search_params)

            break
          end
        end
        skip_if_not_found(resource_type: 'CarePlan', delayed: false)
      end

      test :search_by_patient_category_date do
        metadata do
          id '02'
          name 'Server returns expected results from CarePlan search by patient+category+date'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+category+date on the CarePlan resource

              including support for these date comparators: gt, lt, le, ge
          )
          versions :r4
        end

        skip_if_known_search_not_supported('CarePlan', ['patient', 'category', 'date'])
        skip_if_not_found(resource_type: 'CarePlan', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'category': get_value_for_search_param(resolve_element_from_path(@care_plan_ary[patient], 'category') { |el| get_value_for_search_param(el).present? }),
            'date': get_value_for_search_param(resolve_element_from_path(@care_plan_ary[patient], 'period') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('CarePlan'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          validate_search_reply(versioned_resource_class('CarePlan'), reply, search_params)

          ['gt', 'lt', 'le', 'ge'].each do |comparator|
            comparator_val = date_comparator_value(comparator, search_params[:date])
            comparator_search_params = search_params.merge('date': comparator_val)
            reply = get_resource_by_params(versioned_resource_class('CarePlan'), comparator_search_params)
            validate_search_reply(versioned_resource_class('CarePlan'), reply, comparator_search_params)
          end
        end

        skip 'Could not resolve all parameters (patient, category, date) in any resource.' unless resolved_one
      end

      test :search_by_patient_category_status_date do
        metadata do
          id '03'
          name 'Server returns expected results from CarePlan search by patient+category+status+date'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+category+status+date on the CarePlan resource

              including support for these date comparators: gt, lt, le, ge
          )
          versions :r4
        end

        skip_if_known_search_not_supported('CarePlan', ['patient', 'category', 'status', 'date'])
        skip_if_not_found(resource_type: 'CarePlan', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'category': get_value_for_search_param(resolve_element_from_path(@care_plan_ary[patient], 'category') { |el| get_value_for_search_param(el).present? }),
            'status': get_value_for_search_param(resolve_element_from_path(@care_plan_ary[patient], 'status') { |el| get_value_for_search_param(el).present? }),
            'date': get_value_for_search_param(resolve_element_from_path(@care_plan_ary[patient], 'period') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('CarePlan'), search_params)

          validate_search_reply(versioned_resource_class('CarePlan'), reply, search_params)

          ['gt', 'lt', 'le', 'ge'].each do |comparator|
            comparator_val = date_comparator_value(comparator, search_params[:date])
            comparator_search_params = search_params.merge('date': comparator_val)
            reply = get_resource_by_params(versioned_resource_class('CarePlan'), comparator_search_params)
            validate_search_reply(versioned_resource_class('CarePlan'), reply, comparator_search_params)
          end
        end

        skip 'Could not resolve all parameters (patient, category, status, date) in any resource.' unless resolved_one
      end

      test :search_by_patient_category_status do
        metadata do
          id '04'
          name 'Server returns expected results from CarePlan search by patient+category+status'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+category+status on the CarePlan resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('CarePlan', ['patient', 'category', 'status'])
        skip_if_not_found(resource_type: 'CarePlan', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'category': get_value_for_search_param(resolve_element_from_path(@care_plan_ary[patient], 'category') { |el| get_value_for_search_param(el).present? }),
            'status': get_value_for_search_param(resolve_element_from_path(@care_plan_ary[patient], 'status') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('CarePlan'), search_params)

          validate_search_reply(versioned_resource_class('CarePlan'), reply, search_params)
        end

        skip 'Could not resolve all parameters (patient, category, status) in any resource.' unless resolved_one
      end

      test :read_interaction do
        metadata do
          id '05'
          name 'Server returns correct CarePlan resource from CarePlan read interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(
            A server SHALL support the CarePlan read interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:CarePlan, [:read])
        skip_if_not_found(resource_type: 'CarePlan', delayed: false)

        validate_read_reply(@care_plan, versioned_resource_class('CarePlan'), check_for_data_absent_reasons)
      end

      test :vread_interaction do
        metadata do
          id '06'
          name 'Server returns correct CarePlan resource from CarePlan vread interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the CarePlan vread interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:CarePlan, [:vread])
        skip_if_not_found(resource_type: 'CarePlan', delayed: false)

        validate_vread_reply(@care_plan, versioned_resource_class('CarePlan'))
      end

      test :history_interaction do
        metadata do
          id '07'
          name 'Server returns correct CarePlan resource from CarePlan history interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the CarePlan history interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:CarePlan, [:history])
        skip_if_not_found(resource_type: 'CarePlan', delayed: false)

        validate_history_reply(@care_plan, versioned_resource_class('CarePlan'))
      end

      test 'Server returns Provenance resources from CarePlan search by patient + category + _revIncludes: Provenance:target' do
        metadata do
          id '08'
          link 'https://www.hl7.org/fhir/search.html#revinclude'
          description %(
            A Server SHALL be capable of supporting the following _revincludes: Provenance:target
          )
          versions :r4
        end

        skip_if_known_revinclude_not_supported('CarePlan', 'Provenance:target')
        skip_if_not_found(resource_type: 'CarePlan', delayed: false)

        resolved_one = false

        provenance_results = []
        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'category': get_value_for_search_param(resolve_element_from_path(@care_plan_ary[patient], 'category') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          search_params['_revinclude'] = 'Provenance:target'
          reply = get_resource_by_params(versioned_resource_class('CarePlan'), search_params)

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
          id '09'
          name 'CarePlan resources returned conform to US Core R4 profiles'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-careplan'
          description %(

            This test checks if the resources returned from prior searches conform to the US Core profiles.
            This includes checking for missing data elements and valueset verification.

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'CarePlan', delayed: false)
        test_resources_against_profile('CarePlan')
        bindings = [
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-narrative-status',
            path: 'text.status'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/request-status',
            path: 'status'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/care-plan-intent',
            path: 'intent'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/care-plan-activity-kind',
            path: 'activity.detail.kind'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/care-plan-activity-status',
            path: 'activity.detail.status'
          }
        ]
        invalid_binding_messages = []
        invalid_binding_resources = Set.new
        bindings.select { |binding_def| binding_def[:strength] == 'required' }.each do |binding_def|
          begin
            invalid_bindings = resources_with_invalid_binding(binding_def, @care_plan_ary&.values&.flatten)
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
            invalid_bindings = resources_with_invalid_binding(binding_def, @care_plan_ary&.values&.flatten)
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

      test 'All must support elements are provided in the CarePlan resources returned.' do
        metadata do
          id '10'
          link 'http://www.hl7.org/fhir/us/core/general-guidance.html#must-support'
          description %(

            US Core Responders SHALL be capable of populating all data elements as part of the query results as specified by the US Core Server Capability Statement.
            This will look through all CarePlan resources returned from prior searches to see if any of them provide the following must support elements:

            CarePlan.text

            CarePlan.text.status

            CarePlan.status

            CarePlan.intent

            CarePlan.category

            CarePlan.subject

            CarePlan.category:AssessPlan

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'CarePlan', delayed: false)

        must_support_slices = [
          {
            name: 'CarePlan.category:AssessPlan',
            path: 'CarePlan.category',
            discriminator: {
              type: 'patternCodeableConcept',
              path: '',
              code: 'assess-plan',
              system: 'http://hl7.org/fhir/us/core/CodeSystem/careplan-category'
            }
          }
        ]
        missing_slices = must_support_slices.reject do |slice|
          truncated_path = slice[:path].gsub('CarePlan.', '')
          @care_plan_ary&.values&.flatten&.any? do |resource|
            slice_found = find_slice(resource, truncated_path, slice[:discriminator])
            slice_found.present?
          end
        end

        must_support_elements = [
          { path: 'CarePlan.text' },
          { path: 'CarePlan.text.status' },
          { path: 'CarePlan.status' },
          { path: 'CarePlan.intent' },
          { path: 'CarePlan.category' },
          { path: 'CarePlan.subject' }
        ]

        missing_must_support_elements = must_support_elements.reject do |element|
          truncated_path = element[:path].gsub('CarePlan.', '')
          @care_plan_ary&.values&.flatten&.any? do |resource|
            value_found = resolve_element_from_path(resource, truncated_path) { |value| element[:fixed_value].blank? || value == element[:fixed_value] }
            value_found.present?
          end
        end
        missing_must_support_elements.map! { |must_support| "#{must_support[:path]}#{': ' + must_support[:fixed_value] if must_support[:fixed_value].present?}" }

        missing_must_support_elements += missing_slices.map { |slice| slice[:name] }

        skip_if missing_must_support_elements.present?,
                "Could not find #{missing_must_support_elements.join(', ')} in the #{@care_plan_ary&.values&.flatten&.length} provided CarePlan resource(s)"
        @instance.save!
      end

      test 'Every reference within CarePlan resource is valid and can be read.' do
        metadata do
          id '11'
          link 'http://hl7.org/fhir/references.html'
          description %(
            This test checks if references found in resources from prior searches can be resolved.
          )
          versions :r4
        end

        skip_if_known_not_supported(:CarePlan, [:search, :read])
        skip_if_not_found(resource_type: 'CarePlan', delayed: false)

        validated_resources = Set.new
        max_resolutions = 50

        @care_plan_ary&.values&.flatten&.each do |resource|
          validate_reference_resolutions(resource, validated_resources, max_resolutions) if validated_resources.length < max_resolutions
        end
      end
    end
  end
end
