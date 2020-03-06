# frozen_string_literal: true

require_relative './data_absent_reason_checker'

module Inferno
  module Sequence
    class USCore310DocumentreferenceSequence < SequenceBase
      include Inferno::DataAbsentReasonChecker

      title 'DocumentReference'

      description 'Verify that DocumentReference resources on the FHIR server follow the US Core Implementation Guide'

      test_id_prefix 'USCDR'

      requires :token, :patient_ids
      conformance_supports :DocumentReference

      def validate_resource_item(resource, property, value)
        case property

        when '_id'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'id') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, '_id on resource does not match _id requested'

        when 'status'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'status') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'status on resource does not match status requested'

        when 'patient'
          value_found = resolve_element_from_path(resource, 'subject.reference') { |reference| [value, 'Patient/' + value].include? reference }
          assert value_found.present?, 'patient on resource does not match patient requested'

        when 'category'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'category.coding.code') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'category on resource does not match category requested'

        when 'type'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'type.coding.code') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'type on resource does not match type requested'

        when 'date'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'date') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'date on resource does not match date requested'

        when 'period'
          value_found = resolve_element_from_path(resource, 'context.period') { |date| validate_date_search(value, date) }
          assert value_found.present?, 'period on resource does not match period requested'

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
          assert @instance.server_capabilities&.search_documented?('DocumentReference'),
                 %(Server returned a status of 400 with an OperationOutcome, but the
                search interaction for this resource is not documented in the
                CapabilityStatement. If this response was due to the server
                requiring a status parameter, the server must document this
                requirement in its CapabilityStatement.)
        end

        ['current,superseded,entered-in-error'].each do |status_value|
          params_with_status = search_param.merge('status': status_value)
          reply = get_resource_by_params(versioned_resource_class('DocumentReference'), params_with_status)
          assert_response_ok(reply)
          assert_bundle_response(reply)

          entries = reply.resource.entry.select { |entry| entry.resource.resourceType == 'DocumentReference' }
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
          name 'Server returns expected results from DocumentReference search by patient'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by patient on the DocumentReference resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('DocumentReference', ['patient'])
        @document_reference_ary = {}
        patient_ids.each do |patient|
          search_params = {
            'patient': patient
          }

          reply = get_resource_by_params(versioned_resource_class('DocumentReference'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          assert_response_ok(reply)
          assert_bundle_response(reply)

          any_resources = reply&.resource&.entry&.any? { |entry| entry&.resource&.resourceType == 'DocumentReference' }

          next unless any_resources

          @document_reference_ary[patient] = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)

          @document_reference = @document_reference_ary[patient]
            .find { |resource| resource.resourceType == 'DocumentReference' }
          @resources_found = @document_reference.present?

          save_resource_references(versioned_resource_class('DocumentReference'), @document_reference_ary[patient])
          save_delayed_sequence_references(@document_reference_ary[patient])
          validate_reply_entries(@document_reference_ary[patient], search_params)
        end

        skip_if_not_found(resource_type: 'DocumentReference', delayed: false)
      end

      test :search_by__id do
        metadata do
          id '02'
          name 'Server returns expected results from DocumentReference search by _id'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by _id on the DocumentReference resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('DocumentReference', ['_id'])
        skip_if_not_found(resource_type: 'DocumentReference', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            '_id': get_value_for_search_param(resolve_element_from_path(@document_reference_ary[patient], 'id') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('DocumentReference'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          validate_search_reply(versioned_resource_class('DocumentReference'), reply, search_params)
        end

        skip 'Could not resolve all parameters (_id) in any resource.' unless resolved_one
      end

      test :search_by_patient_type do
        metadata do
          id '03'
          name 'Server returns expected results from DocumentReference search by patient+type'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by patient+type on the DocumentReference resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('DocumentReference', ['patient', 'type'])
        skip_if_not_found(resource_type: 'DocumentReference', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'type': get_value_for_search_param(resolve_element_from_path(@document_reference_ary[patient], 'type') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('DocumentReference'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          validate_search_reply(versioned_resource_class('DocumentReference'), reply, search_params)
        end

        skip 'Could not resolve all parameters (patient, type) in any resource.' unless resolved_one
      end

      test :search_by_patient_category_date do
        metadata do
          id '04'
          name 'Server returns expected results from DocumentReference search by patient+category+date'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by patient+category+date on the DocumentReference resource

              including support for these date comparators: gt, lt, le, ge
          )
          versions :r4
        end

        skip_if_known_search_not_supported('DocumentReference', ['patient', 'category', 'date'])
        skip_if_not_found(resource_type: 'DocumentReference', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'category': get_value_for_search_param(resolve_element_from_path(@document_reference_ary[patient], 'category') { |el| get_value_for_search_param(el).present? }),
            'date': get_value_for_search_param(resolve_element_from_path(@document_reference_ary[patient], 'date') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('DocumentReference'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          validate_search_reply(versioned_resource_class('DocumentReference'), reply, search_params)
        end

        skip 'Could not resolve all parameters (patient, category, date) in any resource.' unless resolved_one
      end

      test :search_by_patient_category do
        metadata do
          id '05'
          name 'Server returns expected results from DocumentReference search by patient+category'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by patient+category on the DocumentReference resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('DocumentReference', ['patient', 'category'])
        skip_if_not_found(resource_type: 'DocumentReference', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'category': get_value_for_search_param(resolve_element_from_path(@document_reference_ary[patient], 'category') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('DocumentReference'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          validate_search_reply(versioned_resource_class('DocumentReference'), reply, search_params)
        end

        skip 'Could not resolve all parameters (patient, category) in any resource.' unless resolved_one
      end

      test :search_by_patient_type_period do
        metadata do
          id '06'
          name 'Server returns expected results from DocumentReference search by patient+type+period'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+type+period on the DocumentReference resource

              including support for these period comparators: gt, lt, le, ge
          )
          versions :r4
        end

        skip_if_known_search_not_supported('DocumentReference', ['patient', 'type', 'period'])
        skip_if_not_found(resource_type: 'DocumentReference', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'type': get_value_for_search_param(resolve_element_from_path(@document_reference_ary[patient], 'type') { |el| get_value_for_search_param(el).present? }),
            'period': get_value_for_search_param(resolve_element_from_path(@document_reference_ary[patient], 'context.period') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('DocumentReference'), search_params)

          reply = perform_search_with_status(reply, search_params) if reply.code == 400

          validate_search_reply(versioned_resource_class('DocumentReference'), reply, search_params)

          ['gt', 'lt', 'le', 'ge'].each do |comparator|
            comparator_val = date_comparator_value(comparator, search_params[:period])
            comparator_search_params = search_params.merge('period': comparator_val)
            reply = get_resource_by_params(versioned_resource_class('DocumentReference'), comparator_search_params)
            validate_search_reply(versioned_resource_class('DocumentReference'), reply, comparator_search_params)
          end
        end

        skip 'Could not resolve all parameters (patient, type, period) in any resource.' unless resolved_one
      end

      test :search_by_patient_status do
        metadata do
          id '07'
          name 'Server returns expected results from DocumentReference search by patient+status'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+status on the DocumentReference resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('DocumentReference', ['patient', 'status'])
        skip_if_not_found(resource_type: 'DocumentReference', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'patient': patient,
            'status': get_value_for_search_param(resolve_element_from_path(@document_reference_ary[patient], 'status') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('DocumentReference'), search_params)

          validate_search_reply(versioned_resource_class('DocumentReference'), reply, search_params)
        end

        skip 'Could not resolve all parameters (patient, status) in any resource.' unless resolved_one
      end

      test :read_interaction do
        metadata do
          id '08'
          name 'Server returns correct DocumentReference resource from DocumentReference read interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(
            A server SHALL support the DocumentReference read interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:DocumentReference, [:read])
        skip_if_not_found(resource_type: 'DocumentReference', delayed: false)

        validate_read_reply(@document_reference, versioned_resource_class('DocumentReference'), check_for_data_absent_reasons)
      end

      test :vread_interaction do
        metadata do
          id '09'
          name 'Server returns correct DocumentReference resource from DocumentReference vread interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the DocumentReference vread interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:DocumentReference, [:vread])
        skip_if_not_found(resource_type: 'DocumentReference', delayed: false)

        validate_vread_reply(@document_reference, versioned_resource_class('DocumentReference'))
      end

      test :history_interaction do
        metadata do
          id '10'
          name 'Server returns correct DocumentReference resource from DocumentReference history interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the DocumentReference history interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:DocumentReference, [:history])
        skip_if_not_found(resource_type: 'DocumentReference', delayed: false)

        validate_history_reply(@document_reference, versioned_resource_class('DocumentReference'))
      end

      test 'Server returns Provenance resources from DocumentReference search by patient + _revIncludes: Provenance:target' do
        metadata do
          id '11'
          link 'https://www.hl7.org/fhir/search.html#revinclude'
          description %(
            A Server SHALL be capable of supporting the following _revincludes: Provenance:target
          )
          versions :r4
        end

        skip_if_known_revinclude_not_supported('DocumentReference', 'Provenance:target')
        skip_if_not_found(resource_type: 'DocumentReference', delayed: false)

        provenance_results = []
        patient_ids.each do |patient|
          search_params = {
            'patient': patient
          }

          search_params['_revinclude'] = 'Provenance:target'
          reply = get_resource_by_params(versioned_resource_class('DocumentReference'), search_params)

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
          name 'DocumentReference resources returned conform to US Core R4 profiles'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-documentreference'
          description %(

            This test checks if the resources returned from prior searches conform to the US Core profiles.
            This includes checking for missing data elements and valueset verification.

            This test also checks that the following CodeableConcepts with
            required ValueSet bindings include a code rather than just text:
            'type'

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'DocumentReference', delayed: false)
        test_resources_against_profile('DocumentReference') do |resource|
          ['type'].flat_map do |path|
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
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/document-reference-status',
            path: 'status'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/composition-status',
            path: 'docStatus'
          },
          {
            type: 'CodeableConcept',
            strength: 'required',
            system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-documentreference-type',
            path: 'type'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-documentreference-category',
            path: 'category'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/document-relationship-type',
            path: 'relatesTo.code'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/ValueSet/security-labels',
            path: 'securityLabel'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/mimetypes',
            path: 'content.attachment.contentType'
          },
          {
            type: 'Coding',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/ValueSet/formatcodes',
            path: 'content.format'
          }
        ]
        invalid_binding_messages = []
        invalid_binding_resources = Set.new
        bindings.select { |binding_def| binding_def[:strength] == 'required' }.each do |binding_def|
          begin
            invalid_bindings = resources_with_invalid_binding(binding_def, @document_reference_ary&.values&.flatten)
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
            invalid_bindings = resources_with_invalid_binding(binding_def, @document_reference_ary&.values&.flatten)
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

      test 'All must support elements are provided in the DocumentReference resources returned.' do
        metadata do
          id '13'
          link 'http://www.hl7.org/fhir/us/core/general-guidance.html#must-support'
          description %(

            US Core Responders SHALL be capable of populating all data elements as part of the query results as specified by the US Core Server Capability Statement.
            This will look through all DocumentReference resources returned from prior searches to see if any of them provide the following must support elements:

            DocumentReference.identifier

            DocumentReference.status

            DocumentReference.type

            DocumentReference.category

            DocumentReference.subject

            DocumentReference.date

            DocumentReference.author

            DocumentReference.custodian

            DocumentReference.content

            DocumentReference.content.attachment

            DocumentReference.content.attachment.contentType

            DocumentReference.content.attachment.data

            DocumentReference.content.attachment.url

            DocumentReference.content.format

            DocumentReference.context

            DocumentReference.context.encounter

            DocumentReference.context.period

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'DocumentReference', delayed: false)

        must_support_elements = [
          { path: 'DocumentReference.identifier' },
          { path: 'DocumentReference.status' },
          { path: 'DocumentReference.type' },
          { path: 'DocumentReference.category' },
          { path: 'DocumentReference.subject' },
          { path: 'DocumentReference.date' },
          { path: 'DocumentReference.author' },
          { path: 'DocumentReference.custodian' },
          { path: 'DocumentReference.content' },
          { path: 'DocumentReference.content.attachment' },
          { path: 'DocumentReference.content.attachment.contentType' },
          { path: 'DocumentReference.content.attachment.data' },
          { path: 'DocumentReference.content.attachment.url' },
          { path: 'DocumentReference.content.format' },
          { path: 'DocumentReference.context' },
          { path: 'DocumentReference.context.encounter' },
          { path: 'DocumentReference.context.period' }
        ]

        missing_must_support_elements = must_support_elements.reject do |element|
          truncated_path = element[:path].gsub('DocumentReference.', '')
          @document_reference_ary&.values&.flatten&.any? do |resource|
            value_found = resolve_element_from_path(resource, truncated_path) { |value| element[:fixed_value].blank? || value == element[:fixed_value] }
            value_found.present?
          end
        end
        missing_must_support_elements.map! { |must_support| "#{must_support[:path]}#{': ' + must_support[:fixed_value] if must_support[:fixed_value].present?}" }

        skip_if missing_must_support_elements.present?,
                "Could not find #{missing_must_support_elements.join(', ')} in the #{@document_reference_ary&.values&.flatten&.length} provided DocumentReference resource(s)"
        @instance.save!
      end

      test 'Every reference within DocumentReference resource is valid and can be read.' do
        metadata do
          id '14'
          link 'http://hl7.org/fhir/references.html'
          description %(
            This test checks if references found in resources from prior searches can be resolved.
          )
          versions :r4
        end

        skip_if_known_not_supported(:DocumentReference, [:search, :read])
        skip_if_not_found(resource_type: 'DocumentReference', delayed: false)

        validated_resources = Set.new
        max_resolutions = 50

        @document_reference_ary&.values&.flatten&.each do |resource|
          validate_reference_resolutions(resource, validated_resources, max_resolutions) if validated_resources.length < max_resolutions
        end
      end
    end
  end
end
