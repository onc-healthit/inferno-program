# frozen_string_literal: true

require_relative './data_absent_reason_checker'

module Inferno
  module Sequence
    class USCore310EncounterSequence < SequenceBase
      include Inferno::DataAbsentReasonChecker

      title 'Encounter'

      description 'Verify that Encounter resources on the FHIR server follow the US Core Implementation Guide'

      test_id_prefix 'USCE'

      requires :token, :patient_ids
      conformance_supports :Encounter

      def validate_resource_item(resource, property, value)
        case property

        when '_id'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'id') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, '_id on resource does not match _id requested'

        when 'class'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'local_class.code') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'class on resource does not match class requested'

        when 'date'
          value_found = resolve_element_from_path(resource, 'period') { |date| validate_date_search(value, date) }
          assert value_found.present?, 'date on resource does not match date requested'

        when 'identifier'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'identifier.value') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'identifier on resource does not match identifier requested'

        when 'patient'
          value_found = resolve_element_from_path(resource, 'subject.reference') { |reference| [value, 'Patient/' + value].include? reference }
          assert value_found.present?, 'patient on resource does not match patient requested'

        when 'status'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'status') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'status on resource does not match status requested'

        when 'type'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'type.coding.code') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'type on resource does not match type requested'

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
          assert @instance.server_capabilities&.search_documented?('Encounter'),
                 %(Server returned a status of 400 with an OperationOutcome, but the
                search interaction for this resource is not documented in the
                CapabilityStatement. If this response was due to the server
                requiring a status parameter, the server must document this
                requirement in its CapabilityStatement.)
        end

        ['planned', 'arrived', 'triaged', 'in-progress', 'onleave', 'finished', 'cancelled', 'entered-in-error', 'unknown'].each do |status_value|
          params_with_status = search_param.merge('status': status_value)
          reply = get_resource_by_params(versioned_resource_class('Encounter'), params_with_status)
          assert_response_ok(reply)
          assert_bundle_response(reply)

          entries = reply.resource.entry.select { |entry| entry.resource.resourceType == 'Encounter' }
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
          name 'Server returns expected results from Encounter search by patient'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by patient on the Encounter resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Encounter', ['patient'])
        @encounter_ary = {}
        patient_ids.each do |patient|
          search_params = {
            'patient': patient
          }

          reply = get_resource_by_params(versioned_resource_class('Encounter'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          assert_response_ok(reply)
          assert_bundle_response(reply)

          any_resources = reply&.resource&.entry&.any? { |entry| entry&.resource&.resourceType == 'Encounter' }

          next unless any_resources

          @encounter_ary[patient] = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)

          @encounter = @encounter_ary[patient]
            .find { |resource| resource.resourceType == 'Encounter' }
          @resources_found = @encounter.present?

          save_resource_references(versioned_resource_class('Encounter'), @encounter_ary[patient])
          save_delayed_sequence_references(@encounter_ary[patient])
          validate_reply_entries(@encounter_ary[patient], search_params)
        end

        skip_if_not_found(resource_type: 'Encounter', delayed: false)
      end

      test :search_by__id do
        metadata do
          id '02'
          name 'Server returns expected results from Encounter search by _id'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by _id on the Encounter resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Encounter', ['_id'])
        skip_if_not_found(resource_type: 'Encounter', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            '_id': get_value_for_search_param(resolve_element_from_path(@encounter_ary[patient], 'id') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('Encounter'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          validate_search_reply(versioned_resource_class('Encounter'), reply, search_params)
        end

        skip 'Could not resolve all parameters (_id) in any resource.' unless resolved_one
      end

      test :search_by_date_patient do
        metadata do
          id '03'
          name 'Server returns expected results from Encounter search by date+patient'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by date+patient on the Encounter resource

              including support for these date comparators: gt, lt, le, ge
          )
          versions :r4
        end

        skip_if_known_search_not_supported('Encounter', ['date', 'patient'])
        skip_if_not_found(resource_type: 'Encounter', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'date': get_value_for_search_param(resolve_element_from_path(@encounter_ary[patient], 'period') { |el| get_value_for_search_param(el).present? }),
            'patient': patient
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('Encounter'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          validate_search_reply(versioned_resource_class('Encounter'), reply, search_params)

          ['gt', 'lt', 'le', 'ge'].each do |comparator|
            comparator_val = date_comparator_value(comparator, search_params[:date])
            comparator_search_params = search_params.merge('date': comparator_val)
            reply = get_resource_by_params(versioned_resource_class('Encounter'), comparator_search_params)
            validate_search_reply(versioned_resource_class('Encounter'), reply, comparator_search_params)
          end
        end

        skip 'Could not resolve all parameters (date, patient) in any resource.' unless resolved_one
      end

      test :search_by_identifier do
        metadata do
          id '04'
          name 'Server returns expected results from Encounter search by identifier'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by identifier on the Encounter resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Encounter', ['identifier'])
        skip_if_not_found(resource_type: 'Encounter', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'identifier': get_value_for_search_param(resolve_element_from_path(@encounter_ary[patient], 'identifier') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('Encounter'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          validate_search_reply(versioned_resource_class('Encounter'), reply, search_params)
        end

        skip 'Could not resolve all parameters (identifier) in any resource.' unless resolved_one
      end

      test :search_by_patient_status do
        metadata do
          id '05'
          name 'Server returns expected results from Encounter search by patient+status'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+status on the Encounter resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Encounter', ['patient', 'status'])
        skip_if_not_found(resource_type: 'Encounter', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'status': get_value_for_search_param(resolve_element_from_path(@encounter_ary[patient], 'status') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('Encounter'), search_params)

          validate_search_reply(versioned_resource_class('Encounter'), reply, search_params)
        end

        skip 'Could not resolve all parameters (patient, status) in any resource.' unless resolved_one
      end

      test :search_by_class_patient do
        metadata do
          id '06'
          name 'Server returns expected results from Encounter search by class+patient'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by class+patient on the Encounter resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Encounter', ['class', 'patient'])
        skip_if_not_found(resource_type: 'Encounter', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'class': get_value_for_search_param(resolve_element_from_path(@encounter_ary[patient], 'local_class') { |el| get_value_for_search_param(el).present? }),
            'patient': patient
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('Encounter'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          validate_search_reply(versioned_resource_class('Encounter'), reply, search_params)
        end

        skip 'Could not resolve all parameters (class, patient) in any resource.' unless resolved_one
      end

      test :search_by_patient_type do
        metadata do
          id '07'
          name 'Server returns expected results from Encounter search by patient+type'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+type on the Encounter resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Encounter', ['patient', 'type'])
        skip_if_not_found(resource_type: 'Encounter', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'type': get_value_for_search_param(resolve_element_from_path(@encounter_ary[patient], 'type') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('Encounter'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          validate_search_reply(versioned_resource_class('Encounter'), reply, search_params)
        end

        skip 'Could not resolve all parameters (patient, type) in any resource.' unless resolved_one
      end

      test :read_interaction do
        metadata do
          id '08'
          name 'Server returns correct Encounter resource from Encounter read interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(
            A server SHALL support the Encounter read interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Encounter, [:read])
        skip_if_not_found(resource_type: 'Encounter', delayed: false)

        validate_read_reply(@encounter, versioned_resource_class('Encounter'), check_for_data_absent_reasons)
      end

      test :vread_interaction do
        metadata do
          id '09'
          name 'Server returns correct Encounter resource from Encounter vread interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the Encounter vread interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Encounter, [:vread])
        skip_if_not_found(resource_type: 'Encounter', delayed: false)

        validate_vread_reply(@encounter, versioned_resource_class('Encounter'))
      end

      test :history_interaction do
        metadata do
          id '10'
          name 'Server returns correct Encounter resource from Encounter history interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the Encounter history interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Encounter, [:history])
        skip_if_not_found(resource_type: 'Encounter', delayed: false)

        validate_history_reply(@encounter, versioned_resource_class('Encounter'))
      end

      test 'Server returns Provenance resources from Encounter search by patient + _revIncludes: Provenance:target' do
        metadata do
          id '11'
          link 'https://www.hl7.org/fhir/search.html#revinclude'
          description %(
            A Server SHALL be capable of supporting the following _revincludes: Provenance:target
          )
          versions :r4
        end

        skip_if_known_revinclude_not_supported('Encounter', 'Provenance:target')
        skip_if_not_found(resource_type: 'Encounter', delayed: false)

        provenance_results = []
        patient_ids.each do |patient|
          search_params = {
            'patient': patient
          }

          search_params['_revinclude'] = 'Provenance:target'
          reply = get_resource_by_params(versioned_resource_class('Encounter'), search_params)

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
          id '12'
          name 'Encounter resources returned conform to US Core R4 profiles'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-encounter'
          description %(

            This test checks if the resources returned from prior searches conform to the US Core profiles.
            This includes checking for missing data elements and valueset verification.

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'Encounter', delayed: false)
        test_resources_against_profile('Encounter')
        bindings = [
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/identifier-use',
            path: 'identifier.use'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/ValueSet/identifier-type',
            path: 'identifier.type'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/encounter-status',
            path: 'status'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/encounter-status',
            path: 'statusHistory.status'
          },
          {
            type: 'Coding',
            strength: 'extensible',
            system: 'http://terminology.hl7.org/ValueSet/v3-ActEncounterCode',
            path: 'class'
          },
          {
            type: 'Coding',
            strength: 'extensible',
            system: 'http://terminology.hl7.org/ValueSet/v3-ActEncounterCode',
            path: 'classHistory.class'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-encounter-type',
            path: 'type'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/ValueSet/encounter-participant-type',
            path: 'participant.type'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/encounter-location-status',
            path: 'location.status'
          }
        ]
        invalid_binding_messages = []
        invalid_binding_resources = Set.new
        bindings.select { |binding_def| binding_def[:strength] == 'required' }.each do |binding_def|
          begin
            invalid_bindings = resources_with_invalid_binding(binding_def, @encounter_ary&.values&.flatten)
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
            invalid_bindings = resources_with_invalid_binding(binding_def, @encounter_ary&.values&.flatten)
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

      test 'All must support elements are provided in the Encounter resources returned.' do
        metadata do
          id '13'
          link 'http://www.hl7.org/fhir/us/core/general-guidance.html#must-support'
          description %(

            US Core Responders SHALL be capable of populating all data elements as part of the query results as specified by the US Core Server Capability Statement.
            This will look through all Encounter resources returned from prior searches to see if any of them provide the following must support elements:

            Encounter.identifier

            Encounter.identifier.system

            Encounter.identifier.value

            Encounter.status

            Encounter.class

            Encounter.type

            Encounter.subject

            Encounter.participant

            Encounter.participant.type

            Encounter.participant.period

            Encounter.participant.individual

            Encounter.period

            Encounter.reasonCode

            Encounter.hospitalization

            Encounter.hospitalization.dischargeDisposition

            Encounter.location

            Encounter.location.location

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'Encounter', delayed: false)

        must_support_elements = [
          { path: 'Encounter.identifier' },
          { path: 'Encounter.identifier.system' },
          { path: 'Encounter.identifier.value' },
          { path: 'Encounter.status' },
          { path: 'Encounter.local_class' },
          { path: 'Encounter.type' },
          { path: 'Encounter.subject' },
          { path: 'Encounter.participant' },
          { path: 'Encounter.participant.type' },
          { path: 'Encounter.participant.period' },
          { path: 'Encounter.participant.individual' },
          { path: 'Encounter.period' },
          { path: 'Encounter.reasonCode' },
          { path: 'Encounter.hospitalization' },
          { path: 'Encounter.hospitalization.dischargeDisposition' },
          { path: 'Encounter.location' },
          { path: 'Encounter.location.location' }
        ]

        missing_must_support_elements = must_support_elements.reject do |element|
          truncated_path = element[:path].gsub('Encounter.', '')
          @encounter_ary&.values&.flatten&.any? do |resource|
            value_found = resolve_element_from_path(resource, truncated_path) { |value| element[:fixed_value].blank? || value == element[:fixed_value] }
            value_found.present?
          end
        end
        missing_must_support_elements.map! { |must_support| "#{must_support[:path]}#{': ' + must_support[:fixed_value] if must_support[:fixed_value].present?}" }

        skip_if missing_must_support_elements.present?,
                "Could not find #{missing_must_support_elements.join(', ')} in the #{@encounter_ary&.values&.flatten&.length} provided Encounter resource(s)"
        @instance.save!
      end

      test 'Every reference within Encounter resource is valid and can be read.' do
        metadata do
          id '14'
          link 'http://hl7.org/fhir/references.html'
          description %(
            This test checks if references found in resources from prior searches can be resolved.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Encounter, [:search, :read])
        skip_if_not_found(resource_type: 'Encounter', delayed: false)

        validated_resources = Set.new
        max_resolutions = 50

        @encounter_ary&.values&.flatten&.each do |resource|
          validate_reference_resolutions(resource, validated_resources, max_resolutions) if validated_resources.length < max_resolutions
        end
      end
    end
  end
end
