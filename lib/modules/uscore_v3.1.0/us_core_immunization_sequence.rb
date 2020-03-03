# frozen_string_literal: true

require_relative './data_absent_reason_checker'

module Inferno
  module Sequence
    class USCore310ImmunizationSequence < SequenceBase
      include Inferno::DataAbsentReasonChecker

      title 'Immunization'

      description 'Verify that Immunization resources on the FHIR server follow the US Core Implementation Guide'

      test_id_prefix 'USCI'

      requires :token, :patient_ids
      conformance_supports :Immunization

      def validate_resource_item(resource, property, value)
        case property

        when 'patient'
          value_found = resolve_element_from_path(resource, 'patient.reference') { |reference| [value, 'Patient/' + value].include? reference }
          assert value_found.present?, 'patient on resource does not match patient requested'

        when 'status'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'status') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'status on resource does not match status requested'

        when 'date'
          value_found = resolve_element_from_path(resource, 'occurrence') { |date| validate_date_search(value, date) }
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
          assert @instance.server_capabilities&.search_documented?('Immunization'),
                 %(Server returned a status of 400 with an OperationOutcome, but the
                search interaction for this resource is not documented in the
                CapabilityStatement. If this response was due to the server
                requiring a status parameter, the server must document this
                requirement in its CapabilityStatement.)
        end

        ['completed', 'entered-in-error', 'not-done', 'preparation', 'in-progress', 'on-hold', 'stopped', 'unknown'].each do |status_value|
          params_with_status = search_param.merge('status': status_value)
          reply = get_resource_by_params(versioned_resource_class('Immunization'), params_with_status)
          assert_response_ok(reply)
          assert_bundle_response(reply)

          entries = reply.resource.entry.select { |entry| entry.resource.resourceType == 'Immunization' }
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

      test :search_by_patient do
        metadata do
          id '01'
          name 'Server returns expected results from Immunization search by patient'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by patient on the Immunization resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Immunization', ['patient'])
        @immunization_ary = {}
        patient_ids.each do |patient|
          search_params = {
            'patient': patient
          }

          reply = get_resource_by_params(versioned_resource_class('Immunization'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          assert_response_ok(reply)
          assert_bundle_response(reply)

          any_resources = reply&.resource&.entry&.any? { |entry| entry&.resource&.resourceType == 'Immunization' }

          next unless any_resources

          @immunization_ary[patient] = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)

          @immunization = @immunization_ary[patient]
            .find { |resource| resource.resourceType == 'Immunization' }
          @resources_found = @immunization.present?

          save_resource_references(versioned_resource_class('Immunization'), @immunization_ary[patient])
          save_delayed_sequence_references(@immunization_ary[patient])
          validate_reply_entries(@immunization_ary[patient], search_params)
        end

        skip_if_not_found(resource_type: 'Immunization', delayed: false)
      end

      test :search_by_patient_date do
        metadata do
          id '02'
          name 'Server returns expected results from Immunization search by patient+date'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+date on the Immunization resource

              including support for these date comparators: gt, lt, le, ge
          )
          versions :r4
        end

        skip_if_known_search_not_supported('Immunization', ['patient', 'date'])
        skip_if_not_found(resource_type: 'Immunization', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'date': get_value_for_search_param(resolve_element_from_path(@immunization_ary[patient], 'occurrence') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('Immunization'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          validate_search_reply(versioned_resource_class('Immunization'), reply, search_params)

          ['gt', 'lt', 'le', 'ge'].each do |comparator|
            comparator_val = date_comparator_value(comparator, search_params[:date])
            comparator_search_params = search_params.merge('date': comparator_val)
            reply = get_resource_by_params(versioned_resource_class('Immunization'), comparator_search_params)
            validate_search_reply(versioned_resource_class('Immunization'), reply, comparator_search_params)
          end
        end

        skip 'Could not resolve all parameters (patient, date) in any resource.' unless resolved_one
      end

      test :search_by_patient_status do
        metadata do
          id '03'
          name 'Server returns expected results from Immunization search by patient+status'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+status on the Immunization resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Immunization', ['patient', 'status'])
        skip_if_not_found(resource_type: 'Immunization', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'status': get_value_for_search_param(resolve_element_from_path(@immunization_ary[patient], 'status') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('Immunization'), search_params)

          validate_search_reply(versioned_resource_class('Immunization'), reply, search_params)
        end

        skip 'Could not resolve all parameters (patient, status) in any resource.' unless resolved_one
      end

      test :read_interaction do
        metadata do
          id '04'
          name 'Server returns correct Immunization resource from Immunization read interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(
            A server SHALL support the Immunization read interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Immunization, [:read])
        skip_if_not_found(resource_type: 'Immunization', delayed: false)

        validate_read_reply(@immunization, versioned_resource_class('Immunization'), check_for_data_absent_reasons)
      end

      test :vread_interaction do
        metadata do
          id '05'
          name 'Server returns correct Immunization resource from Immunization vread interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the Immunization vread interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Immunization, [:vread])
        skip_if_not_found(resource_type: 'Immunization', delayed: false)

        validate_vread_reply(@immunization, versioned_resource_class('Immunization'))
      end

      test :history_interaction do
        metadata do
          id '06'
          name 'Server returns correct Immunization resource from Immunization history interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the Immunization history interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Immunization, [:history])
        skip_if_not_found(resource_type: 'Immunization', delayed: false)

        validate_history_reply(@immunization, versioned_resource_class('Immunization'))
      end

      test 'Server returns Provenance resources from Immunization search by patient + _revIncludes: Provenance:target' do
        metadata do
          id '07'
          link 'https://www.hl7.org/fhir/search.html#revinclude'
          description %(
            A Server SHALL be capable of supporting the following _revincludes: Provenance:target
          )
          versions :r4
        end

        skip_if_known_revinclude_not_supported('Immunization', 'Provenance:target')
        skip_if_not_found(resource_type: 'Immunization', delayed: false)

        provenance_results = []
        patient_ids.each do |patient|
          search_params = {
            'patient': patient
          }

          search_params['_revinclude'] = 'Provenance:target'
          reply = get_resource_by_params(versioned_resource_class('Immunization'), search_params)

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
          id '08'
          name 'Immunization resources returned conform to US Core R4 profiles'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-immunization'
          description %(

            This test checks if the resources returned from prior searches conform to the US Core profiles.
            This includes checking for missing data elements and valueset verification.

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'Immunization', delayed: false)
        test_resources_against_profile('Immunization')
        bindings = [
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/immunization-status',
            path: 'status'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-vaccines-cvx',
            path: 'vaccineCode'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/ValueSet/immunization-function',
            path: 'performer.function'
          }
        ]
        invalid_binding_messages = []
        invalid_binding_resources = Set.new
        bindings.select { |binding_def| binding_def[:strength] == 'required' }.each do |binding_def|
          begin
            invalid_bindings = resources_with_invalid_binding(binding_def, @immunization_ary&.values&.flatten)
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
            invalid_bindings = resources_with_invalid_binding(binding_def, @immunization_ary&.values&.flatten)
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

      test 'All must support elements are provided in the Immunization resources returned.' do
        metadata do
          id '09'
          link 'http://www.hl7.org/fhir/us/core/general-guidance.html#must-support'
          description %(

            US Core Responders SHALL be capable of populating all data elements as part of the query results as specified by the US Core Server Capability Statement.
            This will look through all Immunization resources returned from prior searches to see if any of them provide the following must support elements:

            Immunization.status

            Immunization.statusReason

            Immunization.vaccineCode

            Immunization.patient

            Immunization.occurrence[x]

            Immunization.primarySource

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'Immunization', delayed: false)

        must_support_elements = [
          { path: 'Immunization.status' },
          { path: 'Immunization.statusReason' },
          { path: 'Immunization.vaccineCode' },
          { path: 'Immunization.patient' },
          { path: 'Immunization.occurrence' },
          { path: 'Immunization.primarySource' }
        ]

        missing_must_support_elements = must_support_elements.reject do |element|
          truncated_path = element[:path].gsub('Immunization.', '')
          @immunization_ary&.values&.flatten&.any? do |resource|
            value_found = resolve_element_from_path(resource, truncated_path) { |value| element[:fixed_value].blank? || value == element[:fixed_value] }
            value_found.present?
          end
        end
        missing_must_support_elements.map! { |must_support| "#{must_support[:path]}#{': ' + must_support[:fixed_value] if must_support[:fixed_value].present?}" }

        skip_if missing_must_support_elements.present?,
                "Could not find #{missing_must_support_elements.join(', ')} in the #{@immunization_ary&.values&.flatten&.length} provided Immunization resource(s)"
        @instance.save!
      end

      test 'Every reference within Immunization resource is valid and can be read.' do
        metadata do
          id '10'
          link 'http://hl7.org/fhir/references.html'
          description %(
            This test checks if references found in resources from prior searches can be resolved.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Immunization, [:search, :read])
        skip_if_not_found(resource_type: 'Immunization', delayed: false)

        validated_resources = Set.new
        max_resolutions = 50

        @immunization_ary&.values&.flatten&.each do |resource|
          validate_reference_resolutions(resource, validated_resources, max_resolutions) if validated_resources.length < max_resolutions
        end
      end
    end
  end
end
