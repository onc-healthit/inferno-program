# frozen_string_literal: true

module Inferno
  module Sequence
    class BulkDataGroupExportValidationSequence < SequenceBase

      group 'Bulk Data Group Export Validation'

      title 'Group Compartment Export Validation Tests'

      description 'Verify that Group compartment export from the Bulk Data server follow US Core Implementation Guide'

      test_id_prefix 'BDGV'

      requires :bulk_status_output, :bulk_lines_to_validate

      def test_output_against_profile(klass)
        skip 'Bulk Data Server response does not have output data' unless @instance.bulk_status_output.present?

        if @instance.bulk_lines_to_validate.present? && @instance.bulk_lines_to_validate == '*'
          validate_all = true
        else
          lines_to_validate = @instance.bulk_lines_to_validate.to_i
        end

        output = JSON.parse(@instance.bulk_status_output)

        file = output.find{|item| item['type'] == klass}

        skip "Bulk Data Server export does not have #{klass} data" if file.nil?

        check_file_request(file, klass, validate_all, lines_to_validate)
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
            TThis test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
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
            TThis test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        test_output_against_profile('AllergyIntolerance')
      end

# AllergyIntolerance Tests - 10 tests - Show Details
# Verify that AllergyIntolerance resources on the FHIR server follow the US Core Implementation Guide
# 3
# CarePlan Tests - 12 tests - Show Details
# Verify that CarePlan resources on the FHIR server follow the US Core Implementation Guide
# 4
# CareTeam Tests - 10 tests - Show Details
# Verify that CareTeam resources on the FHIR server follow the US Core Implementation Guide
# 5
# Condition Tests - 13 tests - Show Details
# Verify that Condition resources on the FHIR server follow the US Core Implementation Guide
# 6
# Implantable Device Tests - 10 tests - Show Details
# Verify that Device resources on the FHIR server follow the US Core Implementation Guide
# 7
# DiagnosticReport For Report And Note Exchange Tests - 14 tests - Show Details
# Verify that DiagnosticReport resources on the FHIR server follow the US Core Implementation Guide
# 8
# DiagnosticReport For Laboratory Results Reporting Tests - 14 tests - Show Details
# Verify that DiagnosticReport resources on the FHIR server follow the US Core Implementation Guide
# 9
# DocumentReference Tests - 15 tests - Show Details
# Verify that DocumentReference resources on the FHIR server follow the US Core Implementation Guide
# 10
# Encounter Tests - 15 tests - Show Details
# Verify that Encounter resources on the FHIR server follow the US Core Implementation Guide
# 11
# Goal Tests - 11 tests - Show Details
# Verify that Goal resources on the FHIR server follow the US Core Implementation Guide
# 12
# Immunization Tests - 11 tests - Show Details
# Verify that Immunization resources on the FHIR server follow the US Core Implementation Guide
# 13
# MedicationRequest Tests - 14 tests - Show Details
# Verify that MedicationRequest resources on the FHIR server follow the US Core Implementation Guide
# 14
# Smoking Status Observation Tests - 13 tests - Show Details
# Verify that Observation resources on the FHIR server follow the US Core Implementation Guide
# 15
# Pediatric Weight For Height Observation Tests - 13 tests - Show Details
# Verify that Observation resources on the FHIR server follow the US Core Implementation Guide
# 16
# Laboratory Result Observation Tests - 13 tests - Show Details
# Verify that Observation resources on the FHIR server follow the US Core Implementation Guide
# 17
# Pediatric BMI For Age Observation Tests - 13 tests - Show Details
# Verify that Observation resources on the FHIR server follow the US Core Implementation Guide
# 18
# Pulse Oximetry Tests - 13 tests - Show Details
# Verify that Observation resources on the FHIR server follow the US Core Implementation Guide
# 19
# Procedure Tests - 12 tests - Show Details
# Verify that Procedure resources on the FHIR server follow the US Core Implementation Guide
# 20
# Clinical Notes Guideline Tests - 10 tests - Show Details
# Verify that DocumentReference and DiagnosticReport resources on the FHIR server follow the US Core R4 Clinical Notes Guideline
# 21
# Location Tests - 13 tests - Show Details
# Verify that Location resources on the FHIR server follow the US Core Implementation Guide
# 22
# Medication Tests - 7 tests - Show Details
# Verify that Medication resources on the FHIR server follow the US Core Implementation Guide
# 23
# Organization Tests - 10 tests - Show Details
# Verify that Organization resources on the FHIR server follow the US Core Implementation Guide
# 24
# Practitioner Tests - 10 tests - Show Details
# Verify that Practitioner resources on the FHIR server follow the US Core Implementation Guide
# 25
# PractitionerRole Tests - 11 tests - Show Details
# Verify that PractitionerRole resources on the FHIR server follow the US Core Implementation Guide
# 26
# Provenance Tests - 6 tests - Show Details
    end
  end
end