# frozen_string_literal: true

module Inferno
  module Sequence
    class BulkDataGroupExportValidationSequence < SequenceBase
      group 'Bulk Data Group Export Validation'

      title 'Group Compartment Export Validation Tests'

      description 'Verify that Group compartment export from the Bulk Data server follow US Core Implementation Guide'

      test_id_prefix 'BDGV'

      requires :bulk_status_output, :bulk_lines_to_validate

      def test_output_against_profile(klass,
                                      bulk_status_output = @instance.bulk_status_output,
                                      bulk_lines_to_validate = @instance.bulk_lines_to_validate)

        skip 'Bulk Data Server response does not have output data' unless bulk_status_output.present?

        lines_to_validate = get_lines_to_validate(bulk_lines_to_validate)

        output = JSON.parse(bulk_status_output)

        file = output.find { |item| item['type'] == klass }

        skip "Bulk Data Server export does not have #{klass} data" if file.nil?

        check_file_request(file, klass, lines_to_validate[:validate_all], lines_to_validate[:lines_to_validate])
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

      def check_file_request(file, klass, validate_all, lines_to_validate)
        reply = get_file(file)
        assert_response_content_type(reply, 'application/fhir+ndjson')

        check_ndjson(reply.body, klass, validate_all, lines_to_validate) if validate_all || lines_to_validate.positive?
      end

      def get_file(file)
        headers = { accept: 'application/fhir+ndjson' }
        url = file['url']
        @client.get(url, @client.fhir_headers(headers))
      end

      def check_ndjson(ndjson, klass, validate_all, lines_to_validate)
        return if !validate_all && lines_to_validate < 1

        line_count = 0

        ndjson.each_line do |line|
          break if !validate_all && line_count >= lines_to_validate

          line_count += 1

          resource = versioned_resource_class.from_contents(line)
          resource_type = resource.class.name.demodulize
          assert resource_type == klass, "Resource type \"#{resource_type}\" at line \"#{line_count}\" does not match type defined in output \"#{klass}\")"

          p = Inferno::ValidationUtil.guess_profile(resource, @instance.fhir_version.to_sym)
          if p && @instance.fhir_version == 'r4'
            errors = p.validate_resource(resource)
          else
            warn { assert false, 'No profiles found for this Resource' }
            errors = resource.validate
          end

          # puts "line count: #{line_count}" unless errors.empty?
          assert errors.empty?, errors.to_s
        end
        # puts "line count: #{line_count}"
      end

      test :valiate_patient do
        metadata do
          id '01'
          name 'Patient resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        test_output_against_profile('Patient')
      end

      test :valiate_allergyintolerance do
        metadata do
          id '02'
          name 'AllergyIntolerance resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-allergyintolerance'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        test_output_against_profile('AllergyIntolerance')
      end

      test :valiate_careplan do
        metadata do
          id '03'
          name 'CarePlan resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-careplan'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        test_output_against_profile('CarePlan')
      end

      test :valiate_careteam do
        metadata do
          id '04'
          name 'CareTeam resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-careteam'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        test_output_against_profile('CareTeam')
      end

      test :valiate_condition do
        metadata do
          id '05'
          name 'Condition resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-condition'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        test_output_against_profile('Condition')
      end

      test :valiate_device do
        metadata do
          id '06'
          name 'Device resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-implantable-device'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        test_output_against_profile('Device')
      end

      test :valiate_diagnosticreport do
        metadata do
          id '07'
          name 'DiagnosticReport resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-diagnosticreport-lab'
          description %(
            This test checks if the resources returned from bulk data export conform to the following US Core profiles. This includes checking for missing data elements and valueset verification.

            * http://hl7.org/fhir/us/core/StructureDefinition/us-core-diagnosticreport-lab
            * http://hl7.org/fhir/us/core/StructureDefinition/us-core-diagnosticreport-note
          )
        end

        test_output_against_profile('DiagnosticReport')
      end

      test :valiate_documentreference do
        metadata do
          id '08'
          name 'DocumentReference resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-documentreference'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        test_output_against_profile('DocumentReference')
      end

      test :valiate_encounter do
        metadata do
          id '09'
          name 'Encounter resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-encounter'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        test_output_against_profile('Encounter')
      end

      test :valiate_goal do
        metadata do
          id '10'
          name 'Goal resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-goal'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        test_output_against_profile('Goal')
      end

      test :valiate_immunization do
        metadata do
          id '11'
          name 'Immunization resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-immunization'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        test_output_against_profile('Immunization')
      end

      test :valiate_medicationrequest do
        metadata do
          id '12'
          name 'MedicationRequest resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-medicationrequest'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        test_output_against_profile('MedicationRequest')
      end

      test :valiate_observation do
        metadata do
          id '13'
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
        test_output_against_profile('Observation')
      end

      test :valiate_procedure do
        metadata do
          id '14'
          name 'Procedure resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-procedure'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        test_output_against_profile('Procedure')
      end

      test :valiate_location do
        metadata do
          id '15'
          name 'Location resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-location'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        test_output_against_profile('Location')
      end

      test :valiate_medication do
        metadata do
          id '16'
          name 'Medication resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-medication'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        test_output_against_profile('Medication')
      end

      test :valiate_organization do
        metadata do
          id '17'
          name 'Organization resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-organization'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        test_output_against_profile('Organization')
      end

      test :valiate_practitioner do
        metadata do
          id '18'
          name 'Practitioner resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-practitioner'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        test_output_against_profile('Practitioner')
      end

      test :valiate_practitionerrole do
        metadata do
          id '19'
          name 'PractitionerRole resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-practitionerrole'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        test_output_against_profile('PractitionerRole')
      end
    end
  end
end
