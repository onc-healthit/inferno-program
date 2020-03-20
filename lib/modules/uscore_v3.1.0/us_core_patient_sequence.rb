# frozen_string_literal: true

require_relative './data_absent_reason_checker'

module Inferno
  module Sequence
    class USCore310PatientSequence < SequenceBase
      include Inferno::DataAbsentReasonChecker

      title 'Patient'

      description 'Verify that Patient resources on the FHIR server follow the US Core Implementation Guide'

      test_id_prefix 'USCP'

      requires :token, :patient_ids
      conformance_supports :Patient

      def validate_resource_item(resource, property, value)
        case property

        when '_id'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'id') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, '_id on resource does not match _id requested'

        when 'birthdate'
          value_found = resolve_element_from_path(resource, 'birthDate') { |date| validate_date_search(value, date) }
          assert value_found.present?, 'birthdate on resource does not match birthdate requested'

        when 'family'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'name.family') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'family on resource does not match family requested'

        when 'gender'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'gender') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'gender on resource does not match gender requested'

        when 'given'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'name.given') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'given on resource does not match given requested'

        when 'identifier'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'identifier.value') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'identifier on resource does not match identifier requested'

        when 'name'
          value = value.downcase
          value_found = resolve_element_from_path(resource, 'name') do |name|
            name&.text&.start_with?(value) ||
              name&.family&.downcase&.include?(value) ||
              name&.given&.any? { |given| given.downcase.start_with?(value) } ||
              name&.prefix&.any? { |prefix| prefix.downcase.start_with?(value) } ||
              name&.suffix&.any? { |suffix| suffix.downcase.start_with?(value) }
          end
          assert value_found.present?, 'name on resource does not match name requested'

        end
      end

      details %(
        The #{title} Sequence tests `#{title.gsub(/\s+/, '')}` resources associated with the provided patient.
      )

      def patient_ids
        @instance.patient_ids.split(',').map(&:strip)
      end

      @resources_found = false

      MUST_SUPPORTS = {
        extensions: [
          {
            id: 'Patient.extension:race',
            url: 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-race'
          },
          {
            id: 'Patient.extension:ethnicity',
            url: 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity'
          },
          {
            id: 'Patient.extension:birthsex',
            url: 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-birthsex'
          }
        ],
        slices: [],
        elements: [
          {
            path: 'identifier'
          },
          {
            path: 'identifier.system'
          },
          {
            path: 'identifier.value'
          },
          {
            path: 'name'
          },
          {
            path: 'name.family'
          },
          {
            path: 'name.given'
          },
          {
            path: 'telecom'
          },
          {
            path: 'telecom.system'
          },
          {
            path: 'telecom.value'
          },
          {
            path: 'telecom.use'
          },
          {
            path: 'gender'
          },
          {
            path: 'birthDate'
          },
          {
            path: 'address'
          },
          {
            path: 'address.line'
          },
          {
            path: 'address.city'
          },
          {
            path: 'address.state'
          },
          {
            path: 'address.postalCode'
          },
          {
            path: 'address.period'
          },
          {
            path: 'communication'
          },
          {
            path: 'communication.language'
          }
        ]
      }.freeze

      test :search_by__id do
        metadata do
          id '01'
          name 'Server returns expected results from Patient search by _id'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by _id on the Patient resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Patient', ['_id'])
        @patient_ary = {}
        patient_ids.each do |patient|
          search_params = {
            '_id': patient
          }

          reply = get_resource_by_params(versioned_resource_class('Patient'), search_params)

          assert_response_ok(reply)
          assert_bundle_response(reply)

          any_resources = reply&.resource&.entry&.any? { |entry| entry&.resource&.resourceType == 'Patient' }

          next unless any_resources

          @patient_ary[patient] = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)

          @patient = @patient_ary[patient]
            .find { |resource| resource.resourceType == 'Patient' }
          @resources_found = @patient.present?

          save_resource_references(versioned_resource_class('Patient'), @patient_ary[patient])
          save_delayed_sequence_references(@patient_ary[patient])
          validate_reply_entries(@patient_ary[patient], search_params)
        end

        skip_if_not_found(resource_type: 'Patient', delayed: false)
      end

      test :search_by_identifier do
        metadata do
          id '02'
          name 'Server returns expected results from Patient search by identifier'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by identifier on the Patient resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Patient', ['identifier'])
        skip_if_not_found(resource_type: 'Patient', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'identifier': get_value_for_search_param(resolve_element_from_path(@patient_ary[patient], 'identifier') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('Patient'), search_params)

          validate_search_reply(versioned_resource_class('Patient'), reply, search_params)
        end

        skip 'Could not resolve all parameters (identifier) in any resource.' unless resolved_one
      end

      test :search_by_name do
        metadata do
          id '03'
          name 'Server returns expected results from Patient search by name'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by name on the Patient resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Patient', ['name'])
        skip_if_not_found(resource_type: 'Patient', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'name': get_value_for_search_param(resolve_element_from_path(@patient_ary[patient], 'name') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('Patient'), search_params)

          validate_search_reply(versioned_resource_class('Patient'), reply, search_params)
        end

        skip 'Could not resolve all parameters (name) in any resource.' unless resolved_one
      end

      test :search_by_gender_name do
        metadata do
          id '04'
          name 'Server returns expected results from Patient search by gender+name'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by gender+name on the Patient resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Patient', ['gender', 'name'])
        skip_if_not_found(resource_type: 'Patient', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'gender': get_value_for_search_param(resolve_element_from_path(@patient_ary[patient], 'gender') { |el| get_value_for_search_param(el).present? }),
            'name': get_value_for_search_param(resolve_element_from_path(@patient_ary[patient], 'name') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('Patient'), search_params)

          validate_search_reply(versioned_resource_class('Patient'), reply, search_params)
        end

        skip 'Could not resolve all parameters (gender, name) in any resource.' unless resolved_one
      end

      test :search_by_birthdate_name do
        metadata do
          id '05'
          name 'Server returns expected results from Patient search by birthdate+name'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by birthdate+name on the Patient resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Patient', ['birthdate', 'name'])
        skip_if_not_found(resource_type: 'Patient', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'birthdate': get_value_for_search_param(resolve_element_from_path(@patient_ary[patient], 'birthDate') { |el| get_value_for_search_param(el).present? }),
            'name': get_value_for_search_param(resolve_element_from_path(@patient_ary[patient], 'name') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('Patient'), search_params)

          validate_search_reply(versioned_resource_class('Patient'), reply, search_params)
        end

        skip 'Could not resolve all parameters (birthdate, name) in any resource.' unless resolved_one
      end

      test :search_by_birthdate_family do
        metadata do
          id '06'
          name 'Server returns expected results from Patient search by birthdate+family'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by birthdate+family on the Patient resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Patient', ['birthdate', 'family'])
        skip_if_not_found(resource_type: 'Patient', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'birthdate': get_value_for_search_param(resolve_element_from_path(@patient_ary[patient], 'birthDate') { |el| get_value_for_search_param(el).present? }),
            'family': get_value_for_search_param(resolve_element_from_path(@patient_ary[patient], 'name.family') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('Patient'), search_params)

          validate_search_reply(versioned_resource_class('Patient'), reply, search_params)
        end

        skip 'Could not resolve all parameters (birthdate, family) in any resource.' unless resolved_one
      end

      test :search_by_family_gender do
        metadata do
          id '07'
          name 'Server returns expected results from Patient search by family+gender'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by family+gender on the Patient resource

          )
          versions :r4
        end

        skip_if_known_search_not_supported('Patient', ['family', 'gender'])
        skip_if_not_found(resource_type: 'Patient', delayed: false)

        resolved_one = false

        patient_ids.each do |patient|
          search_params = {
            'family': get_value_for_search_param(resolve_element_from_path(@patient_ary[patient], 'name.family') { |el| get_value_for_search_param(el).present? }),
            'gender': get_value_for_search_param(resolve_element_from_path(@patient_ary[patient], 'gender') { |el| get_value_for_search_param(el).present? })
          }

          next if search_params.any? { |_param, value| value.nil? }

          resolved_one = true

          reply = get_resource_by_params(versioned_resource_class('Patient'), search_params)

          validate_search_reply(versioned_resource_class('Patient'), reply, search_params)
        end

        skip 'Could not resolve all parameters (family, gender) in any resource.' unless resolved_one
      end

      test :read_interaction do
        metadata do
          id '08'
          name 'Server returns correct Patient resource from Patient read interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(
            A server SHALL support the Patient read interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Patient, [:read])
        skip_if_not_found(resource_type: 'Patient', delayed: false)

        validate_read_reply(@patient, versioned_resource_class('Patient'), check_for_data_absent_reasons)
      end

      test :vread_interaction do
        metadata do
          id '09'
          name 'Server returns correct Patient resource from Patient vread interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the Patient vread interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Patient, [:vread])
        skip_if_not_found(resource_type: 'Patient', delayed: false)

        validate_vread_reply(@patient, versioned_resource_class('Patient'))
      end

      test :history_interaction do
        metadata do
          id '10'
          name 'Server returns correct Patient resource from Patient history interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the Patient history interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Patient, [:history])
        skip_if_not_found(resource_type: 'Patient', delayed: false)

        validate_history_reply(@patient, versioned_resource_class('Patient'))
      end

      test 'Server returns Provenance resources from Patient search by _id + _revIncludes: Provenance:target' do
        metadata do
          id '11'
          link 'https://www.hl7.org/fhir/search.html#revinclude'
          description %(
            A Server SHALL be capable of supporting the following _revincludes: Provenance:target
          )
          versions :r4
        end

        skip_if_known_revinclude_not_supported('Patient', 'Provenance:target')
        skip_if_not_found(resource_type: 'Patient', delayed: false)

        provenance_results = []
        patient_ids.each do |patient|
          search_params = {
            '_id': patient
          }

          search_params['_revinclude'] = 'Provenance:target'
          reply = get_resource_by_params(versioned_resource_class('Patient'), search_params)

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
          name 'Patient resources returned conform to US Core R4 profiles'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient'
          description %(

            This test checks if the resources returned from prior searches conform to the US Core profiles.
            This includes checking for missing data elements and valueset verification.

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'Patient', delayed: false)
        test_resources_against_profile('Patient')
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
            system: 'http://hl7.org/fhir/ValueSet/name-use',
            path: 'name.use'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/contact-point-system',
            path: 'telecom.system'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/contact-point-use',
            path: 'telecom.use'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/administrative-gender',
            path: 'gender'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/address-use',
            path: 'address.use'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/address-type',
            path: 'address.type'
          },
          {
            type: 'string',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-usps-state',
            path: 'address.state'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/ValueSet/marital-status',
            path: 'maritalStatus'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/ValueSet/patient-contactrelationship',
            path: 'contact.relationship'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/administrative-gender',
            path: 'contact.gender'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/us/core/ValueSet/simple-language',
            path: 'communication.language'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/link-type',
            path: 'link.type'
          },
          {
            type: 'Coding',
            strength: 'required',
            system: 'http://hl7.org/fhir/us/core/ValueSet/omb-race-category',
            path: 'value',
            extensions: [
              'http://hl7.org/fhir/us/core/StructureDefinition/us-core-race',
              'ombCategory'
            ]
          },
          {
            type: 'Coding',
            strength: 'required',
            system: 'http://hl7.org/fhir/us/core/ValueSet/detailed-race',
            path: 'value',
            extensions: [
              'http://hl7.org/fhir/us/core/StructureDefinition/us-core-race',
              'detailed'
            ]
          },
          {
            type: 'Coding',
            strength: 'required',
            system: 'http://hl7.org/fhir/us/core/ValueSet/omb-ethnicity-category',
            path: 'value',
            extensions: [
              'http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity',
              'ombCategory'
            ]
          },
          {
            type: 'Coding',
            strength: 'required',
            system: 'http://hl7.org/fhir/us/core/ValueSet/detailed-ethnicity',
            path: 'value',
            extensions: [
              'http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity',
              'detailed'
            ]
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/us/core/ValueSet/birthsex',
            path: 'value',
            extensions: [
              'http://hl7.org/fhir/us/core/StructureDefinition/us-core-birthsex'
            ]
          }
        ]
        invalid_binding_messages = []
        invalid_binding_resources = Set.new
        bindings.select { |binding_def| binding_def[:strength] == 'required' }.each do |binding_def|
          begin
            invalid_bindings = resources_with_invalid_binding(binding_def, @patient_ary&.values&.flatten)
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
            invalid_bindings = resources_with_invalid_binding(binding_def, @patient_ary&.values&.flatten)
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

      test 'All must support elements are provided in the Patient resources returned.' do
        metadata do
          id '13'
          link 'http://www.hl7.org/fhir/us/core/general-guidance.html#must-support'
          description %(

            US Core Responders SHALL be capable of populating all data elements as part of the query results as specified by the US Core Server Capability Statement.
            This will look through all Patient resources returned from prior searches to see if any of them provide the following must support elements:

            identifier

            identifier.system

            identifier.value

            name

            name.family

            name.given

            telecom

            telecom.system

            telecom.value

            telecom.use

            gender

            birthDate

            address

            address.line

            address.city

            address.state

            address.postalCode

            address.period

            communication

            communication.language

            Patient.extension:race

            Patient.extension:ethnicity

            Patient.extension:birthsex

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'Patient', delayed: false)

        missing_must_support_extensions = MUST_SUPPORTS[:extensions].reject do |must_support_extension|
          @patient_ary&.values&.flatten&.any? do |resource|
            resource.extension.any? { |extension| extension.url == must_support_extension[:url] }
          end
        end

        missing_must_support_elements = MUST_SUPPORTS[:elements].reject do |element|
          @patient_ary&.values&.flatten&.any? do |resource|
            value_found = resolve_element_from_path(resource, element[:path]) { |value| element[:fixed_value].blank? || value == element[:fixed_value] }
            value_found.present?
          end
        end
        missing_must_support_elements.map! { |must_support| "#{must_support[:path]}#{': ' + must_support[:fixed_value] if must_support[:fixed_value].present?}" }

        missing_must_support_elements += missing_must_support_extensions.map { |must_support| must_support[:id] }

        skip_if missing_must_support_elements.present?,
                "Could not find #{missing_must_support_elements.join(', ')} in the #{@patient_ary&.values&.flatten&.length} provided Patient resource(s)"
        @instance.save!
      end

      test 'Every reference within Patient resource is valid and can be read.' do
        metadata do
          id '14'
          link 'http://hl7.org/fhir/references.html'
          description %(
            This test checks if references found in resources from prior searches can be resolved.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Patient, [:search, :read])
        skip_if_not_found(resource_type: 'Patient', delayed: false)

        validated_resources = Set.new
        max_resolutions = 50

        @patient_ary&.values&.flatten&.each do |resource|
          validate_reference_resolutions(resource, validated_resources, max_resolutions) if validated_resources.length < max_resolutions
        end
      end
    end
  end
end
