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

      def test_clinical_notes_document_reference(category_code)
        skip_if_known_not_supported(:DocumentReference, [:search])

        resource_class = 'DocumentReference'
        patient_ids = @instance.patient_ids.split(',')
        self.document_attachments = {} if document_attachments.nil?
        attachments = {}
        all_status = ['current,superseded,entered-in-error']

        patient_ids.each do |patient_id|
          search_params = { 'patient': patient_id, 'type': category_code }

          reply = get_resource_by_params(versioned_resource_class(resource_class), search_params)

          parse_reply_with_source_search(reply, resource_class, attachments, all_status) do |the_reply, the_attachments|
            parse_document_reference_reply(the_reply, the_attachments)
          end
        end

        skip "No #{resource_class} resources with type #{category_code} appear to be available. Please use patients with more information." if attachments.empty?
        document_attachments.merge!(attachments) { |_key, v1, _v2| v1 }
      end

      def parse_reply_with_source_search(reply, resource_class, attachments, source)
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

          source.each do |status_value|
            params_with_status = search_param.merge('status': status_value)
            reply = get_resource_by_params(versioned_resource_class(resource_class), params_with_status)
            yield(reply, attachments)
          end
        else
          yield(reply, attachments)
        end
      end

      def parse_document_reference_reply(reply, attachments)
        assert_response_ok(reply)
        assert_bundle_response(reply)

        return unless reply&.resource&.entry&.any? { |entry| entry&.resource&.resourceType == 'DocumentReference' }

        document_references = fetch_all_bundled_resources(reply)

        document_references&.each do |document|
          document&.content&.select { |content| !attachments.key?(content&.attachment&.url) }&.each do |content|
            attachments[content.attachment.url] = document.id
          end
        end
      end

      def test_clinical_notes_diagnostic_report(category_code)
        skip_if_known_not_supported(:DiagnosticReport, [:search])

        resource_class = 'DiagnosticReport'
        patient_ids = @instance.patient_ids.split(',')
        self.report_attachments = {} if report_attachments.nil?
        attachments = {}
        all_status = ['registered,partial,preliminary,final,amended,corrected,appended,cancelled,entered-in-error,unknown']

        patient_ids.each do |patient_id|
          search_params = { 'patient': patient_id, 'category': category_code }

          reply = get_resource_by_params(versioned_resource_class(resource_class), search_params)

          parse_reply_with_source_search(reply, resource_class, attachments, all_status) do |the_reply, the_attachments|
            parse_diagnostic_report_reply(the_reply, the_attachments)
          end
        end

        skip "No #{resource_class} resources with category #{category_code} appear to be available. Please use patients with more information." if attachments.empty?
        report_attachments.merge!(attachments) { |_key, v1, _v2| v1 }
      end

      def parse_diagnostic_report_reply(reply, attachments)
        assert_response_ok(reply)
        assert_bundle_response(reply)

        return unless reply&.resource&.entry&.any? { |entry| entry&.resource&.resourceType == 'DiagnosticReport' }

        diagnostic_reports = fetch_all_bundled_resources(reply)

        diagnostic_reports&.each do |report|
          report&.presentedForm&.select { |attachment| !attachments.key?(attachment&.url) }&.each do |attachment|
            attachments[attachment.url] = report.id
          end
        end
      end

      test :have_consultation_note do
        metadata do
          id '01'
          name 'Server shall have Consultation Note from DocumentReference search by patient+type'
          link 'https://www.hl7.org/fhir/us/core/clinical-notes-guidance.html'
          description %(
          )
          versions :r4
        end

        test_clinical_notes_document_reference('http://loinc.org|11488-4')
      end

      test :have_discharge_summary do
        metadata do
          id '02'
          name 'Server shall have Discharge Summary from DocumentReference search by patient+type'
          link 'https://www.hl7.org/fhir/us/core/clinical-notes-guidance.html'
          description %(
          )
          versions :r4
        end

        test_clinical_notes_document_reference('http://loinc.org|18842-5')
      end

      test :have_history_note do
        metadata do
          id '03'
          name 'Server shall have History and Physical Note from DocumentReference search by patient+type'
          link 'https://www.hl7.org/fhir/us/core/clinical-notes-guidance.html'
          description %(
          )
          versions :r4
        end

        test_clinical_notes_document_reference('http://loinc.org|34117-2')
      end

      test :have_procedures_note do
        metadata do
          id '04'
          name 'Server returns Procedures Note from DocumentReference search by patient+type'
          link 'https://www.hl7.org/fhir/us/core/clinical-notes-guidance.html'
          description %(
          )
          versions :r4
        end

        test_clinical_notes_document_reference('http://loinc.org|28570-0')
      end

      test :have_progress_note do
        metadata do
          id '05'
          name 'Server returns Progress Note from DocumentReference search by patient+type'
          link 'https://www.hl7.org/fhir/us/core/clinical-notes-guidance.html'
          description %(
          )
          versions :r4
        end

        test_clinical_notes_document_reference('http://loinc.org|11506-3')
      end

      test :have_cardiology_report do
        metadata do
          id '06'
          name 'Server returns Cardiology report from DiagnosticReport search by patient+category'
          link 'https://www.hl7.org/fhir/us/core/clinical-notes-guidance.html'
          description %(
          )
          versions :r4
        end

        test_clinical_notes_diagnostic_report('http://loinc.org|LP29708-2')
      end

      test :have_pathology_report do
        metadata do
          id '07'
          name 'Server returns Pathology report from DiagnosticReport search by patient+category'
          link 'https://www.hl7.org/fhir/us/core/clinical-notes-guidance.html'
          description %(
          )
          versions :r4
        end

        test_clinical_notes_diagnostic_report('http://loinc.org|LP7839-6')
      end

      test :have_radiology_report do
        metadata do
          id '08'
          name 'Server returns Radiology report from DiagnosticReport search by patient+category'
          link 'https://www.hl7.org/fhir/us/core/clinical-notes-guidance.html'
          description %(
          )
          versions :r4
        end

        test_clinical_notes_diagnostic_report('http://loinc.org|LP29684-5')
      end

      test :have_matched_attachments do
        metadata do
          id '09'
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
