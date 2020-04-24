# frozen_string_literal: true

require 'http' # for streaming http client
Dir['lib/modules/uscore_v3.1.0/profile_definitions/*'].sort.each { |file| require './' + file }

module Inferno
  module Sequence
    class BulkDataGroupExportValidationSequence < SequenceBase
      group 'Bulk Data Group Export Validation'

      title 'Group Compartment Export Validation Tests'

      description 'Verify that Group compartment export from the Bulk Data server follow US Core Implementation Guide'

      test_id_prefix 'BDGV'

      requires :bulk_status_output, :bulk_lines_to_validate, :bulk_patient_ids_in_group

      attr_accessor :requires_access_token, :output, :patient_ids_seen, :has_min_patient_count

      MAX_RECENT_LINE_SIZE = 100
      MIN_RESOURCE_COUNT = 2

      US_CORE_R4_URIS = Inferno::ValidationUtil::US_CORE_R4_URIS
      include Inferno::USCore310ProfileDefinitions

      def initialize(instance, client, disable_tls_tests = false, sequence_result = nil)
        super(instance, client, disable_tls_tests, sequence_result)

        return unless @instance.bulk_status_output.present?

        status_response = JSON.parse(@instance.bulk_status_output)
        @output = status_response['output']
        requires_access_token = status_response['requiresAccessToken']
        @requires_access_token = requires_access_token.to_s.downcase == 'true' if requires_access_token.present?
      end

      def test_output_against_profile(klass,
                                      must_supports = [],
                                      output = @output,
                                      bulk_lines_to_validate = @instance.bulk_lines_to_validate)
        skip 'Bulk Data Server response does not have output data' unless output.present?

        lines_to_validate = get_lines_to_validate(bulk_lines_to_validate)

        file = output.find { |item| item['type'] == klass }

        skip "Bulk Data Server export does not have #{klass} data" if file.nil?

        success_count = check_file_request(file, klass, lines_to_validate[:validate_all], lines_to_validate[:lines_to_validate], must_supports)

        pass "Successfully validated #{success_count} resource(s)."
      end

      def get_lines_to_validate(input)
        if input.present? && input == '*'
          validate_all = true
        else
          lines_to_validate = input.to_i
        end

        {
          validate_all: validate_all,
          lines_to_validate: lines_to_validate
        }
      end

      def check_file_request(file, klass, validate_all, lines_to_validate, must_supports)
        headers = { accept: 'application/fhir+ndjson' }
        headers['Authorization'] = "Bearer #{@instance.bulk_access_token}" if @requires_access_token && @instance.bulk_access_token.present?

        @patient_ids_seen = Set.new if klass == 'Patient'

        line_count = 0
        error_collection = {}
        line_collection = []

        request_for_log = {
          method: 'GET',
          url: file['url'],
          headers: headers
        }

        response_for_log = {
          body: String.new
        }

        streamed_ndjson_get(file['url'], headers) do |response, resource|
          assert response.headers['Content-Type'] == 'application/fhir+ndjson', "Content type must be 'application/fhir+ndjson' but is '#{response.headers['Content-type']}"

          break if !validate_all && line_count >= lines_to_validate && (klass != 'Patient' || @has_min_patient_count)

          response_for_log[:code] = response.code unless response_for_log.key?(:code)
          response_for_log[:headers] = response.headers unless response_for_log.key?(:headers)
          line_collection << resource if line_count < MAX_RECENT_LINE_SIZE

          line_count += 1

          @has_min_patient_count = true if line_count >= MIN_RESOURCE_COUNT && klass == 'Patient'

          resource = versioned_resource_class.from_contents(resource)
          resource_type = resource.class.name.demodulize
          assert resource_type == klass, "Resource type \"#{resource_type}\" at line \"#{line_count}\" does not match type defined in output \"#{klass}\")"

          @patient_ids_seen << resource.id if klass == 'Patient'

          p = Inferno::ValidationUtil.guess_profile(resource, @instance.fhir_version.to_sym)
          if p && @instance.fhir_version == 'r4'
            errors = Inferno::RESOURCE_VALIDATOR.validate(resource, versioned_resource_class, p.url)

            # Remove warnings if using internal FHIRModelsValidator. FHIRModelsValidator has an issue with FluentPath.
            errors = [] if errors[:errors].empty? && Inferno::RESOURCE_VALIDATOR.is_a?(Inferno::FHIRModelsValidator)
          else
            warn { assert false, 'No profiles found for this Resource' }
            errors = resource.validate
          end

          if must_supports.present?
            if must_supports.length > 1 && p
              profile_must_support = must_supports.find { |must_support| must_support[:profile] == p.url }
              must_support_info = profile_must_support.present? ? profile_must_support[:must_support_info] : nil
            else
              must_support_info = must_supports.first[:must_support_info]
            end

            if must_support_info.present?
              must_support_info[:elements].reject! do |ms_element|
                resolve_element_from_path(resource, ms_element[:path]) { |value| ms_element[:fixed_value].blank? || value == ms_element[:fixed_value] }
              end

              must_support_info[:extensions].reject! do |ms_extension|
                resource.extension.any? { |extension| extension.url == ms_extension[:url] }
              end

              must_support_info[:slices].reject! do |ms_slice|
                find_slice(resource, ms_slice[:path], ms_slice[:discriminator])
              end
            end
          end

          error_collection[line_count] = errors unless errors.empty?
        end

        unless error_collection.empty?
          response_for_log[:body] = line_collection.join
          LoggedRestClient.record_response(request_for_log, response_for_log)

          index, errors = error_collection.first
          assert false, "#{error_collection.size} / #{line_count} #{klass} resources failed profile validation. The first failed resource is #{klass} ##{index}: \n\n#{errors[:errors].join("\n")}"
        end

        assert_must_supports_found(must_supports) if validate_all || lines_to_validate.positive?

        if file.key?('count') && validate_all
          warning do
            assert file['count'].to_s == line_count.to_s, "Count in status output (#{file['count']}) did not match actual number of resources returned (#{line_count})"
          end
        end

        line_count
      end

      def assert_must_supports_found(must_supports)
        must_supports.each do |must_support|
          error_string = "Could not verify presence#{' for profile ' + must_support[:profile] if must_support[:profile].present?} of the following must support %s: %s"
          missing_must_supports = must_support[:must_support_info]

          missing_elements_list = missing_must_supports[:elements].map { |el| "#{el[:path]}#{': ' + el[:fixed_value] if el[:fixed_value].present?}" }
          assert missing_elements_list.empty?, format(error_string, 'elements', missing_elements_list.join(', '))

          missing_slices_list = missing_must_supports[:slices].map { |slice| slice[:name] }
          assert missing_slices_list.empty?, format(error_string, 'slices', missing_slices_list.join(', '))

          missing_extensions_list = missing_must_supports[:extensions].map { |extension| extension[:id] }
          assert missing_extensions_list.empty?, format(error_string, 'extensions', missing_extensions_list.join(', '))
        end
      end

      def log_and_reraise_if_error(request, response, truncated)
        yield
      rescue StandardError
        response[:body] = "NOTE: RESPONSE TRUNCATED\nINFERNO ONLY DISPLAYS MOST RECENT #{MAX_RECENT_LINE_SIZE} LINES\n\n#{response[:body]}" if truncated
        LoggedRestClient.record_response(request, response)
        raise
      end

      def streamed_ndjson_get(url, headers)
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER # set globally to VERIFY_NONE if disable_verify_peer set
        ctx.set_params
        response = HTTP.headers(headers).get(url, ssl_context: ctx)

        # We need to log the request, but don't know what will be in the body
        # until later.  These serve as simple summaries to get turned into
        # logged requests.

        request_for_log = {
          method: 'GET',
          url: url,
          headers: headers
        }

        response_for_log = {
          code: response.status,
          headers: response.headers,
          body: String.new,
          truncated: false
        }

        # We don't want to keep a huge log of everything that came through,
        # but we also want to show up to a reasonable number.
        recent_lines = []
        line_count = 0

        body = response.body

        next_block = String.new

        until (chunk = body.readpartial).nil?
          next_block << chunk
          resource_list = next_block.lines
          next_block = String.new resource_list.pop
          resource_list.each do |resource|
            recent_lines << resource
            line_count += 1
            recent_lines.shift if line_count > MAX_RECENT_LINE_SIZE

            response_for_log[:body] = recent_lines.join
            log_and_reraise_if_error(request_for_log, response_for_log, line_count > MAX_RECENT_LINE_SIZE) do
              yield(response, resource)
            end
          end
        end

        recent_lines << next_block
        line_count += 1
        recent_lines.shift if line_count > MAX_RECENT_LINE_SIZE
        response_for_log[:body] = recent_lines.join

        log_and_reraise_if_error(request_for_log, response_for_log, line_count > MAX_RECENT_LINE_SIZE) do
          yield(response, next_block)
        end

        if line_count > MAX_RECENT_LINE_SIZE
          response_for_log[:body] = "NOTE: RESPONSE TRUNCATED\nINFERNO ONLY DISPLAYS MOST RECENT #{MAX_RECENT_LINE_SIZE} LINES\n\n#{response_for_log[:body]}"
        end
        LoggedRestClient.record_response(request_for_log, response_for_log)

        line_count
      end

      def get_file(file, use_token: true)
        headers = { accept: 'application/fhir+ndjson' }
        headers['Authorization'] = 'Bearer ' + @instance.bulk_access_token if use_token && @requires_access_token && @instance.bulk_access_token.present?

        url = file['url']
        LoggedRestClient.get(url, headers)
      end

      test :require_tls do
        metadata do
          id '01'
          name 'Bulk Data Server is secured by transport layer security'
          link 'http://hl7.org/fhir/uv/bulkdata/export/index.html#security-considerations'
          description %(
            All exchanges described herein between a client and a server SHALL be secured using Transport Layer Security (TLS) Protocol Version 1.2 (RFC5246)
          )
        end

        skip 'Could not verify this functionality when output is empty' unless @output.present?

        omit_if_tls_disabled

        assert_tls_1_2 @output[0]['url']
        assert_deny_previous_tls @output[0]['url']
      end

      test :require_access_token do
        metadata do
          id '02'
          name 'NDJSON download requires access token if requireAccessToken is true'
          link 'http://hl7.org/fhir/uv/bulkdata/export/index.html#file-request'
          description %(
            If the requiresAccessToken field in the Complete Status body is set to true, the request SHALL include a valid access token.

            [FHIR R4 Security](http://build.fhir.org/security.html#AccessDenied) and
            [The OAuth 2.0 Authorization Framework: Bearer Token Usage](https://tools.ietf.org/html/rfc6750#section-3.1)
            recommend using HTTP status code 401 for invalid token but also allow the actual result be controlled by policy and context.
          )
        end

        skip 'Could not verify this functionality when requireAccessToken is false' unless @requires_access_token
        skip 'Could not verify this functionality when bearer token is not set' if @instance.bulk_access_token.blank?

        reply = get_file(@output[0], use_token: false)

        assert_response_bad_or_unauthorized(reply)
      end

      test :validate_patient do
        metadata do
          id '03'
          name 'Patient resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        must_supports = [
          {
            profile: nil,
            must_support_info: USCore310PatientSequenceDefinitions::MUST_SUPPORTS.dup
          }
        ]
        test_output_against_profile('Patient', must_supports)
      end

      test :validate_two_patients do
        metadata do
          id '04'
          name 'Group export has at least two patients'
          link 'http://ndjson.org/'
          description %(
            This test checks if the Group export has at least two patients.
          )
        end

        assert @has_min_patient_count, 'Group export did not have multple patients.'
      end

      test :validate_patient_ids_in_group do
        metadata do
          id '05'
          name 'Patient IDs match those expected in Group'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient'
          description %(
            This test checks that the list of patient IDs that are expected match those that are returned.
            If no patient ids are provided to the test, then the test will be omitted.
          )
        end

        omit 'No patient ids were given' unless @instance.bulk_patient_ids_in_group.present?

        expected_patients = Set.new(@instance.bulk_patient_ids_in_group.split(',').map(&:strip))

        patient_diff = expected_patients ^ @patient_ids_seen

        assert patient_diff.empty?, "Mismatch between patient ids seen (#{@patient_ids_seen.to_a.join(', ')}) and patient ids expected (#{@instance.bulk_patient_ids_in_group})"
      end

      test :validate_allergyintolerance do
        metadata do
          id '06'
          name 'AllergyIntolerance resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-allergyintolerance'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        must_supports = [
          {
            profile: nil,
            must_support_info: USCore310AllergyintoleranceSequenceDefinitions::MUST_SUPPORTS.dup
          }
        ]
        test_output_against_profile('AllergyIntolerance', must_supports)
      end

      test :validate_careplan do
        metadata do
          id '07'
          name 'CarePlan resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-careplan'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        must_supports = [
          {
            profile: nil,
            must_support_info: USCore310CareplanSequenceDefinitions::MUST_SUPPORTS.dup
          }
        ]
        test_output_against_profile('CarePlan', must_supports)
      end

      test :validate_careteam do
        metadata do
          id '08'
          name 'CareTeam resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-careteam'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        must_supports = [
          {
            profile: nil,
            must_support_info: USCore310CareteamSequenceDefinitions::MUST_SUPPORTS.dup
          }
        ]
        test_output_against_profile('CareTeam', must_supports)
      end

      test :validate_condition do
        metadata do
          id '09'
          name 'Condition resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-condition'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        must_supports = [
          {
            profile: nil,
            must_support_info: USCore310ConditionSequenceDefinitions::MUST_SUPPORTS.dup
          }
        ]
        test_output_against_profile('Condition', must_supports)
      end

      test :validate_device do
        metadata do
          id '10'
          name 'Device resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-implantable-device'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        test_output_against_profile('Device')
      end

      test :validate_diagnosticreport do
        metadata do
          id '11'
          name 'DiagnosticReport resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-diagnosticreport-lab'
          description %(
            This test checks if the resources returned from bulk data export conform to the following US Core profiles. This includes checking for missing data elements and valueset verification.

            * http://hl7.org/fhir/us/core/StructureDefinition/us-core-diagnosticreport-lab
            * http://hl7.org/fhir/us/core/StructureDefinition/us-core-diagnosticreport-note
          )
        end

        must_supports = [
          {
            profile: US_CORE_R4_URIS[:diagnostic_report_lab],
            must_support_info: USCore310DiagnosticreportLabSequenceDefinitions::MUST_SUPPORTS.dup
          },
          {
            profile: US_CORE_R4_URIS[:diagnostic_report_note],
            must_support_info: USCore310DiagnosticreportNoteSequenceDefinitions::MUST_SUPPORTS.dup
          }
        ]
        test_output_against_profile('DiagnosticReport', must_supports)
      end

      test :validate_documentreference do
        metadata do
          id '12'
          name 'DocumentReference resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-documentreference'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        must_supports = [
          {
            profile: nil,
            must_support_info: USCore310DocumentreferenceSequenceDefinitions::MUST_SUPPORTS.dup
          }
        ]
        test_output_against_profile('DocumentReference', must_supports)
      end

      test :validate_encounter do
        metadata do
          id '13'
          name 'Encounter resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-encounter'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        must_supports = [
          {
            profile: nil,
            must_support_info: USCore310EncounterSequenceDefinitions::MUST_SUPPORTS.dup
          }
        ]
        test_output_against_profile('Encounter', must_supports)
      end

      test :validate_goal do
        metadata do
          id '14'
          name 'Goal resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-goal'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        must_supports = [
          {
            profile: nil,
            must_support_info: USCore310GoalSequenceDefinitions::MUST_SUPPORTS.dup
          }
        ]
        test_output_against_profile('Goal', must_supports)
      end

      test :validate_immunization do
        metadata do
          id '15'
          name 'Immunization resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-immunization'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        must_supports = [
          {
            profile: nil,
            must_support_info: USCore310ImmunizationSequenceDefinitions::MUST_SUPPORTS.dup
          }
        ]
        test_output_against_profile('Immunization', must_supports)
      end

      test :validate_medicationrequest do
        metadata do
          id '16'
          name 'MedicationRequest resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-medicationrequest'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        must_supports = [
          {
            profile: nil,
            must_support_info: USCore310MedicationrequestSequenceDefinitions::MUST_SUPPORTS.dup
          }
        ]
        test_output_against_profile('MedicationRequest', must_supports)
      end

      test :validate_observation do
        metadata do
          id '17'
          name 'Observation resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-observation-lab'
          description %(
            This test checks if the resources returned from bulk data export conform to the following US Core profiles. This includes checking for missing data elements and valueset verification.

            * http://hl7.org/fhir/us/core/StructureDefinition/pediatric-bmi-for-age
            * http://hl7.org/fhir/us/core/StructureDefinition/pediatric-weight-for-height
            * http://hl7.org/fhir/us/core/StructureDefinition/us-core-observation-lab
            * http://hl7.org/fhir/us/core/StructureDefinition/us-core-pulse-oximetry
            * http://hl7.org/fhir/us/core/StructureDefinition/us-core-smokingstatus
          )
        end

        must_supports = [
          {
            profile: US_CORE_R4_URIS[:pediatric_bmi_age],
            must_support_info: USCore310PediatricBmiForAgeSequenceDefinitions::MUST_SUPPORTS.dup
          },
          {
            profile: US_CORE_R4_URIS[:pediatric_weight_height],
            must_support_info: USCore310PediatricWeightForHeightSequenceDefinitions::MUST_SUPPORTS.dup
          },
          {
            profile: US_CORE_R4_URIS[:USCore310PulseOximetrySequence],
            must_support_info: USCore310PulseOximetrySequenceDefinitions::MUST_SUPPORTS.dup
          },
          {
            profile: US_CORE_R4_URIS[:lab_results],
            must_support_info: USCore310ObservationLabSequenceDefinitions::MUST_SUPPORTS.dup
          },
          {
            profile: US_CORE_R4_URIS[:smoking_status],
            must_support_info: USCore310SmokingstatusSequenceDefinitions::MUST_SUPPORTS.dup
          }
        ]

        test_output_against_profile('Observation', must_supports)
      end

      test :validate_procedure do
        metadata do
          id '18'
          name 'Procedure resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-procedure'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        must_supports = [
          {
            profile: nil,
            must_support_info: USCore310ProcedureSequenceDefinitions::MUST_SUPPORTS.dup
          }
        ]
        test_output_against_profile('Procedure', must_supports)
      end

      test :validate_location do
        metadata do
          id '19'
          name 'Location resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-location'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        must_supports = [
          {
            profile: nil,
            must_support_info: USCore310LocationSequenceDefinitions::MUST_SUPPORTS.dup
          }
        ]
        test_output_against_profile('Location', must_supports)
      end

      test :validate_medication do
        metadata do
          id '20'
          name 'Medication resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-medication'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        test_output_against_profile('Medication')
      end

      test :validate_organization do
        metadata do
          id '21'
          name 'Organization resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-organization'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        must_supports = [
          {
            profile: nil,
            must_support_info: USCore310OrganizationSequenceDefinitions::MUST_SUPPORTS.dup
          }
        ]
        test_output_against_profile('Organization', must_supports)
      end

      test :validate_practitioner do
        metadata do
          id '22'
          name 'Practitioner resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-practitioner'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        must_supports = [
          {
            profile: nil,
            must_support_info: USCore310PractitionerSequenceDefinitions::MUST_SUPPORTS.dup
          }
        ]
        test_output_against_profile('Practitioner', must_supports)
      end

      test :validate_practitionerrole do
        metadata do
          id '23'
          name 'PractitionerRole resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-practitionerrole'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        must_supports = [
          {
            profile: nil,
            must_support_info: USCore310PractitionerroleSequenceDefinitions::MUST_SUPPORTS.dup
          }
        ]
        test_output_against_profile('PractitionerRole', must_supports)
      end
    end
  end
end
