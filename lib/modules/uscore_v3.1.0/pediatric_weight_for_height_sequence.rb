# frozen_string_literal: true

require_relative './data_absent_reason_checker'

module Inferno
  module Sequence
    class USCore310PediatricWeightForHeightSequence < SequenceBase
      include Inferno::DataAbsentReasonChecker

      title 'Pediatric Weight for Height Observation'

      description 'Verify that Observation resources on the FHIR server follow the US Core Implementation Guide'

      test_id_prefix 'USCPWHO'

      requires :token, :patient_ids
      conformance_supports :Observation

      def validate_resource_item(resource, property, value)
        case property

        when 'status'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'status') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'status on resource does not match status requested'

        when 'category'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'category.coding.code') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'category on resource does not match category requested'

        when 'code'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'code.coding.code') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'code on resource does not match code requested'

        when 'date'
          value_found = resolve_element_from_path(resource, 'effective') { |date| validate_date_search(value, date) }
          assert value_found.present?, 'date on resource does not match date requested'

        when 'patient'
          value_found = resolve_element_from_path(resource, 'subject.reference') { |reference| [value, 'Patient/' + value].include? reference }
          assert value_found.present?, 'patient on resource does not match patient requested'

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
          assert @instance.server_capabilities&.search_documented?('Observation'),
                 %(Server returned a status of 400 with an OperationOutcome, but the
                search interaction for this resource is not documented in the
                CapabilityStatement. If this response was due to the server
                requiring a status parameter, the server must document this
                requirement in its CapabilityStatement.)
        end

        ['registered,preliminary,final,amended,corrected,cancelled,entered-in-error,unknown'].each do |status_value|
          params_with_status = search_param.merge('status': status_value)
          reply = get_resource_by_params(versioned_resource_class('Observation'), params_with_status)
          assert_response_ok(reply)
          assert_bundle_response(reply)

          entries = reply.resource.entry.select { |entry| entry.resource.resourceType == 'Observation' }
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

      test :search_by_patient_code do
        metadata do
          id '01'
          name 'Server returns expected results from Observation search by patient+code'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by patient+code on the Observation resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Observation', ['patient', 'code'])
        @observation_ary = {}
        @resources_found = false

        code_val = ['77606-2']
        patient_ids.each do |patient|
          @observation_ary[patient] = []
          code_val.each do |val|
            search_params = { 'patient': patient, 'code': val }
            reply = get_resource_by_params(versioned_resource_class('Observation'), search_params)

            reply = perform_search_with_status(reply, search_params) if reply.code == 400

            assert_response_ok(reply)
            assert_bundle_response(reply)

            next unless reply&.resource&.entry&.any? { |entry| entry&.resource&.resourceType == 'Observation' }

            @resources_found = true
            resources_returned = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
            @observation = resources_returned.first
            @observation_ary[patient] += resources_returned

            save_resource_references(versioned_resource_class('Observation'), @observation_ary[patient], Inferno::ValidationUtil::US_CORE_R4_URIS[:pediatric_weight_height])
            save_delayed_sequence_references(resources_returned)
            validate_reply_entries(resources_returned, search_params)

            break
          end
        end
        skip_if_not_found(resource_type: 'Observation', delayed: false)
      end

      test :search_by_patient_category_date do
        metadata do
          id '02'
          name 'Server returns expected results from Observation search by patient+category+date'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by patient+category+date on the Observation resource

              including support for these date comparators: gt, lt, le, ge
          )
          versions :r4
        end

        skip_if_known_search_not_supported('Observation', ['patient', 'category', 'date'])
        skip_if_not_found(resource_type: 'Observation', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'category': get_value_for_search_param(resolve_element_from_path(@observation_ary[patient], 'category') { |el| get_value_for_search_param(el).present? }),
            'date': get_value_for_search_param(resolve_element_from_path(@observation_ary[patient], 'effective') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('Observation'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          validate_search_reply(versioned_resource_class('Observation'), reply, search_params)

          ['gt', 'lt', 'le', 'ge'].each do |comparator|
            comparator_val = date_comparator_value(comparator, search_params[:date])
            comparator_search_params = search_params.merge('date': comparator_val)
            reply = get_resource_by_params(versioned_resource_class('Observation'), comparator_search_params)
            validate_search_reply(versioned_resource_class('Observation'), reply, comparator_search_params)
          end
        end

        skip 'Could not resolve all parameters (patient, category, date) in any resource.' unless resolved_one
      end

      test :search_by_patient_category do
        metadata do
          id '03'
          name 'Server returns expected results from Observation search by patient+category'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by patient+category on the Observation resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Observation', ['patient', 'category'])
        skip_if_not_found(resource_type: 'Observation', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'category': get_value_for_search_param(resolve_element_from_path(@observation_ary[patient], 'category') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('Observation'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          validate_search_reply(versioned_resource_class('Observation'), reply, search_params)
        end

        skip 'Could not resolve all parameters (patient, category) in any resource.' unless resolved_one
      end

      test :search_by_patient_code_date do
        metadata do
          id '04'
          name 'Server returns expected results from Observation search by patient+code+date'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+code+date on the Observation resource

              including support for these date comparators: gt, lt, le, ge
          )
          versions :r4
        end

        skip_if_known_search_not_supported('Observation', ['patient', 'code', 'date'])
        skip_if_not_found(resource_type: 'Observation', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'code': get_value_for_search_param(resolve_element_from_path(@observation_ary[patient], 'code') { |el| get_value_for_search_param(el).present? }),
            'date': get_value_for_search_param(resolve_element_from_path(@observation_ary[patient], 'effective') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('Observation'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          validate_search_reply(versioned_resource_class('Observation'), reply, search_params)

          ['gt', 'lt', 'le', 'ge'].each do |comparator|
            comparator_val = date_comparator_value(comparator, search_params[:date])
            comparator_search_params = search_params.merge('date': comparator_val)
            reply = get_resource_by_params(versioned_resource_class('Observation'), comparator_search_params)
            validate_search_reply(versioned_resource_class('Observation'), reply, comparator_search_params)
          end
        end

        skip 'Could not resolve all parameters (patient, code, date) in any resource.' unless resolved_one
      end

      test :search_by_patient_category_status do
        metadata do
          id '05'
          name 'Server returns expected results from Observation search by patient+category+status'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+category+status on the Observation resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Observation', ['patient', 'category', 'status'])
        skip_if_not_found(resource_type: 'Observation', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'category': get_value_for_search_param(resolve_element_from_path(@observation_ary[patient], 'category') { |el| get_value_for_search_param(el).present? }),
            'status': get_value_for_search_param(resolve_element_from_path(@observation_ary[patient], 'status') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('Observation'), search_params)

          validate_search_reply(versioned_resource_class('Observation'), reply, search_params)
        end

        skip 'Could not resolve all parameters (patient, category, status) in any resource.' unless resolved_one
      end

      test :read_interaction do
        metadata do
          id '06'
          name 'Server returns correct Observation resource from Observation read interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(
            A server SHALL support the Observation read interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Observation, [:read])
        skip_if_not_found(resource_type: 'Observation', delayed: false)

        validate_read_reply(@observation, versioned_resource_class('Observation'), check_for_data_absent_reasons)
      end

      test :vread_interaction do
        metadata do
          id '07'
          name 'Server returns correct Observation resource from Observation vread interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the Observation vread interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Observation, [:vread])
        skip_if_not_found(resource_type: 'Observation', delayed: false)

        validate_vread_reply(@observation, versioned_resource_class('Observation'))
      end

      test :history_interaction do
        metadata do
          id '08'
          name 'Server returns correct Observation resource from Observation history interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the Observation history interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Observation, [:history])
        skip_if_not_found(resource_type: 'Observation', delayed: false)

        validate_history_reply(@observation, versioned_resource_class('Observation'))
      end

      test 'Server returns Provenance resources from Observation search by patient + code + _revIncludes: Provenance:target' do
        metadata do
          id '09'
          link 'https://www.hl7.org/fhir/search.html#revinclude'
          description %(
            A Server SHALL be capable of supporting the following _revincludes: Provenance:target
          )
          versions :r4
        end

        skip_if_known_revinclude_not_supported('Observation', 'Provenance:target')
        skip_if_not_found(resource_type: 'Observation', delayed: false)

        resolved_one = false

        provenance_results = []
        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'code': get_value_for_search_param(resolve_element_from_path(@observation_ary[patient], 'code') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          search_params['_revinclude'] = 'Provenance:target'
          reply = get_resource_by_params(versioned_resource_class('Observation'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          assert_response_ok(reply)
          assert_bundle_response(reply)
          provenance_results += fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
            .select { |resource| resource.resourceType == 'Provenance' }
        end
        save_resource_references(versioned_resource_class('Provenance'), provenance_results)
        save_delayed_sequence_references(provenance_results)
        skip 'Could not resolve all parameters (patient, code) in any resource.' unless resolved_one
        skip 'No Provenance resources were returned from this search' unless provenance_results.present?
      end

      test :validate_resources do
        metadata do
          id '10'
          name 'Observation resources returned conform to US Core R4 profiles'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/pediatric-weight-for-height'
          description %(

            This test checks if the resources returned from prior searches conform to the US Core profiles.
            This includes checking for missing data elements and valueset verification.

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'Observation', delayed: false)
        test_resources_against_profile('Observation', Inferno::ValidationUtil::US_CORE_R4_URIS[:pediatric_weight_height])
        bindings = [
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/observation-status',
            path: 'status'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/ValueSet/observation-vitalsignresult',
            path: 'code'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/quantity-comparator',
            path: 'value.comparator'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/ValueSet/data-absent-reason',
            path: 'dataAbsentReason'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/ValueSet/observation-interpretation',
            path: 'interpretation'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/ValueSet/observation-vitalsignresult',
            path: 'component.code'
          },
          {
            type: 'Quantity',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/ucum-vitals-common',
            path: 'component.value'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/ValueSet/data-absent-reason',
            path: 'component.dataAbsentReason'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/ValueSet/observation-interpretation',
            path: 'component.interpretation'
          }
        ]
        invalid_binding_messages = []
        invalid_binding_resources = Set.new
        bindings.select { |binding_def| binding_def[:strength] == 'required' }.each do |binding_def|
          begin
            invalid_bindings = resources_with_invalid_binding(binding_def, @observation_ary&.values&.flatten)
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
            invalid_bindings = resources_with_invalid_binding(binding_def, @observation_ary&.values&.flatten)
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

      test 'All must support elements are provided in the Observation resources returned.' do
        metadata do
          id '11'
          link 'http://www.hl7.org/fhir/us/core/general-guidance.html#must-support'
          description %(

            US Core Responders SHALL be capable of populating all data elements as part of the query results as specified by the US Core Server Capability Statement.
            This will look through all Observation resources returned from prior searches to see if any of them provide the following must support elements:

            Observation.status

            Observation.category

            Observation.category.coding

            Observation.category.coding.system

            Observation.category.coding.code

            Observation.subject

            Observation.effective[x]

            Observation.value[x]

            Observation.value[x].value

            Observation.value[x].unit

            Observation.value[x].system

            Observation.value[x].code

            Observation.category:VSCat

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'Observation', delayed: false)

        must_support_slices = [
          {
            name: 'Observation.category:VSCat',
            path: 'Observation.category',
            discriminator: {
              type: 'value',
              values: [
                {
                  path: 'coding.code',
                  value: 'vital-signs'
                },
                {
                  path: 'coding.system',
                  value: 'http://terminology.hl7.org/CodeSystem/observation-category'
                }
              ]
            }
          }
        ]
        missing_slices = must_support_slices.reject do |slice|
          truncated_path = slice[:path].gsub('Observation.', '')
          @observation_ary&.values&.flatten&.any? do |resource|
            slice_found = find_slice(resource, truncated_path, slice[:discriminator])
            slice_found.present?
          end
        end

        must_support_elements = [
          { path: 'Observation.status' },
          { path: 'Observation.category' },
          { path: 'Observation.category.coding' },
          { path: 'Observation.category.coding.system', fixed_value: 'http://terminology.hl7.org/CodeSystem/observation-category' },
          { path: 'Observation.category.coding.code', fixed_value: 'vital-signs' },
          { path: 'Observation.subject' },
          { path: 'Observation.effective' },
          { path: 'Observation.value' },
          { path: 'Observation.value.value' },
          { path: 'Observation.value.unit' },
          { path: 'Observation.value.system', fixed_value: 'http://unitsofmeasure.org' },
          { path: 'Observation.value.code', fixed_value: '%' }
        ]

        missing_must_support_elements = must_support_elements.reject do |element|
          truncated_path = element[:path].gsub('Observation.', '')
          @observation_ary&.values&.flatten&.any? do |resource|
            value_found = resolve_element_from_path(resource, truncated_path) { |value| element[:fixed_value].blank? || value == element[:fixed_value] }
            value_found.present?
          end
        end
        missing_must_support_elements.map! { |must_support| "#{must_support[:path]}#{': ' + must_support[:fixed_value] if must_support[:fixed_value].present?}" }

        missing_must_support_elements += missing_slices.map { |slice| slice[:name] }

        skip_if missing_must_support_elements.present?,
                "Could not find #{missing_must_support_elements.join(', ')} in the #{@observation_ary&.values&.flatten&.length} provided Observation resource(s)"
        @instance.save!
      end

      test 'Every reference within Observation resource is valid and can be read.' do
        metadata do
          id '12'
          link 'http://hl7.org/fhir/references.html'
          description %(
            This test checks if references found in resources from prior searches can be resolved.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Observation, [:search, :read])
        skip_if_not_found(resource_type: 'Observation', delayed: false)

        validated_resources = Set.new
        max_resolutions = 50

        @observation_ary&.values&.flatten&.each do |resource|
          validate_reference_resolutions(resource, validated_resources, max_resolutions) if validated_resources.length < max_resolutions
        end
      end
    end
  end
end
