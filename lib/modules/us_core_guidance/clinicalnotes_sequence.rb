# frozen_string_literal: true

module Inferno
  module Sequence
    class USCoreR4ClinicalNotesSequence < SequenceBase
      group 'US Core R4 Profile Conformance'

      title 'Clinical Notes Guideline Tests'

      description 'Verify that DocumentReference and DiagnosticReport resources on the FHIR server follow the US Core Implementation Guide'

      test_id_prefix 'USCCN'

      requires :token, :patient_ids
      conformance_supports :DocumentReference, :DiagnosticReport

      details %(

        The #{title} Sequence tests DiagnosticReport and DocumentReference resources associated with the provided patient.  The resources
        returned will be checked for consistency against the [US Core Clinical Notes Guidance](https://www.hl7.org/fhir/us/core/clinical-notes-guidance.html)

        In this set of tests, Inferno serves as a FHIR client that attempts to access different types of Clinical Notes
        specified in the Guidance. The provided patient needs to have the following five common clinical notes as DocumentReference resources:

        * Consultation Note (11488-4)
        * Discharge Summary (18842-5)
        * History & Physical Note (34117-2)
        * Procedures Note (28570-0)
        * Progress Note (11506-3)

        The provided patient also needs to have the following three common diagnostic reports as DiagnosticReport resources:

        * Cardiology (LP29708-2)
        * Pathology (LP7839-6)
        * Radiology (LP29684-5)

        In order to enable consistent access to scanned narrative-only clinical reports,
        the US Core server shall expose these reports through both
        DiagnosticReport and DocumentReference by representing the same attachment url.
      )

      attr_accessor :document_attachments, :report_attachments

      def test_clinical_notes
        skip_if_known_not_supported(:DocumentReference, [:search])
        skip_if_known_not_supported(:DiagnosticReport, [:search])

        patient_ids = @instance.patient_ids.split(',')
        clinical_note_errors = []

        patient_ids.each do |patient_id|
          self.document_attachments = {}
          self.report_attachments = {}

          missing_types = check_document_reference_required_type(patient_id)
          missing_categories = check_diagnostic_report_required_category(patient_id)

          break if missing_types.empty? && missing_categories.empty?

          message = "Patient/#{patient_id} does NOT have these required "

          unless missing_types.empty?
            message += "DocumentReference types #{missing_types.join(', ')}"
            message += ' and required ' unless missing_categories.empty?
          end

          message += "DiagnosticReport categories #{missing_categories.join(', ')}"

          clinical_note_errors << message
        end

        skip clinical_note_errors.join("\n* ").to_s if clinical_note_errors.size == patient_ids.size
      end

      def reply_with_status_search(search_params, resource_class, all_status)
        reply = get_resource_by_params(versioned_resource_class(resource_class), search_params)

        # If server require status, server shall return 400
        # https://www.hl7.org/fhir/us/core/general-guidance.html#search-for-servers-requiring-status
        if reply.code == 400
          begin
            parsed_reply = JSON.parse(reply.body)
            assert parsed_reply['resourceType'] == 'OperationOutcome', 'Server returned a status of 400 without an OperationOutcome.'
          rescue JSON::ParserError
            assert false, 'Server returned a status of 400 without an OperationOutcome.'
          end

          warning do
            assert @instance.server_capabilities&.search_documented?(resource_class),
                   %(Server returned a status of 400 with an OperationOutcome, but the
                      search interaction for this resource is not documented in the
                      CapabilityStatement. If this response was due to the server
                      requiring a status parameter, the server must document this
                      requirement in its CapabilityStatement.)
          end

          params_with_status = search_param.merge('status': all_status)
          reply = get_resource_by_params(versioned_resource_class(resource_class), params_with_status)
        end

        assert_response_ok(reply)
        assert_bundle_response(reply)

        fetch_all_bundled_resources(reply)
      end

      def check_document_reference_required_type(patient_id)
        resource_class = :DocumentReference.to_s
        all_status = 'current,superseded,entered-in-error'
        search_params = { 'patient': patient_id }

        resources = reply_with_status_search(search_params, resource_class, all_status)

        parse_document_reference_reply(resources, resource_class)
      end

      def parse_document_reference_reply(resources, resource_class)
        type_required = ['11488-4', '18842-5', '34117-2', '28570-0', '11506-3']
        type_found = []

        resources&.select { |r| r.resourceType == resource_class }&.each do |resource|
          code = resource.type.coding.map { |coding| coding.code if type_required.include?(coding.code) }.compact

          type_found << code.first unless code.empty? || type_found.include?(code.first)

          # Save DocumentReference.content.attachment.url for later test
          resource.content&.select { |content| !document_attachments.key?(content.attachment&.url) }&.each do |content|
            document_attachments[content.attachment.url] = resource.id
          end
        end

        type_required - type_found
      end

      def check_diagnostic_report_required_category(patient_id)
        resource_class = :DiagnosticReport.to_s
        all_status = 'registered,partial,preliminary,final,amended,corrected,appended,cancelled,entered-in-error,unknown'
        search_params = { 'patient': patient_id }

        resources = reply_with_status_search(search_params, resource_class, all_status)

        parse_diagnostic_report_reply(resources, resource_class)
      end

      def parse_diagnostic_report_reply(resources, resource_class)
        category_required = ['LP29708-2', 'LP7839-6', 'LP29684-5']
        category_found = []

        resources&.select { |r| r.resourceType == resource_class }&.each do |resource|
          resource.category&.each do |category|
            code = category.coding.map { |coding| coding.code if category_required.include?(coding.code) }.compact

            unless code.empty?
              category_found << code.first unless category_found.include?(code.first)

              # Save DiagnosticReport.presentedForm.url for later test.
              # Our current understanding is that Inferno only need to test the attachment for the three required DiagonistcReport
              resource.presentedForm&.select { |attachment| !report_attachments.key?(attachment&.url) }&.each do |attachment|
                report_attachments[attachment.url] = resource.id
              end

              break
            end
          end
        end

        category_required - category_found
      end

      test :have_clinical_notes do
        metadata do
          id '01'
          name 'Server shall have minmum five types of DocumentReference and three categories of DiagnosticReport'
          link 'https://www.hl7.org/fhir/us/core/clinical-notes-guidance.html'
          description %(
            US Core Implementation Guide Clinical Notes Guidance defines system SHALL support the following five “Common Clinical Notes”:

            * Consultation Note (11488-4)
            * Discharge Summary (18842-5)
            * History & Physical Note (34117-2)
            * Procedures Note (28570-0)
            * Progress Note (11506-3)

            and three DiagnosticReport categories:

            * Cardiology (LP29708-2)
            * Pathology (LP7839-6)
            * Radiology (LP29684-5)
          )
          versions :r4
        end

        test_clinical_notes
      end

      test :have_matched_attachments do
        metadata do
          id '02'
          name 'DiagnosticReport and DocumentReference reference the same attachment'
          link 'https://www.hl7.org/fhir/us/core/clinical-notes-guidance.html#fhir-resources-to-exchange-clinical-notes'
          description %(
            All presentedForms urls referenced in DiagnosticReports shall have corresponding content attachment urls referenced in DocumentReference.

            There is no single best practice for representing a scanned, or narrative-only report due to the overlapping scope of the underlying resources and
            variability in system implementation. Reports may be represented by either a DocumentReference or a DiagnosticReport. To require Clients query both
            DocumentReference and DiagnosticReport to get all the information for a patient is potentially dangerous if a client doesn’t understand or follow this requirement.

            To simplify the requirement, US Core IG requires servers implement the duplicate reference to allow a client to find a Pathology report, or other Diagnostic Reports,
            in either Resource.
          )
          versions :r4
        end

        skip 'There is no attachment in DocumentReference. Please select another patient.' unless document_attachments&.any?
        skip 'There is no attachment in DiagnosticReport. Please select another patient.' unless report_attachments&.any?

        assert_attachment_matched(report_attachments, document_attachments, 'DiagnosticReport', 'DocumentReference')
      end

      def assert_attachment_matched(source_attachments, target_attachments, source_class, target_class)
        not_matched_urls = source_attachments.keys - target_attachments.keys
        not_matched_attachments = not_matched_urls.map { |url| "#{url} in #{source_class}/#{source_attachments[url]}" }

        assert not_matched_attachments.empty?, "Attachments #{not_matched_attachments.join(', ')} are not referenced in any #{target_class}."
      end
    end
  end
end
