# frozen_string_literal: true

module Inferno
  module Sequence
    class ONCVisualInspectionSequence < SequenceBase
      title 'Visual Inspection and Attestation'
      description 'Verify conformance to portions of the test procedure that are not automated.'

      test_id_prefix 'ATT'

      requires :onc_visual_single_registration,
               :onc_visual_single_registration_notes,
               :onc_visual_multi_registration,
               :onc_visual_multi_registration_notes,
               :onc_visual_single_scopes,
               :onc_visual_single_scopes_notes,
               :onc_visual_single_offline_access,
               :onc_visual_single_offline_access_notes,
               :onc_visual_refresh_timeout,
               :onc_visual_refresh_timeout_notes,
               :onc_visual_introspection,
               :onc_visual_introspection_notes,
               :onc_visual_data_without_omission,
               :onc_visual_data_without_omission_notes,
               :onc_visual_multi_scopes_no_greater,
               :onc_visual_multi_scopes_no_greater_notes,
               :onc_visual_documentation,
               :onc_visual_documentation_notes,
               :onc_visual_jwks_cache,
               :onc_visual_jwks_cache_notes,
               :onc_visual_jwks_token_revocation,
               :onc_visual_jwks_token_revocation_notes,
               :onc_visual_patient_period,
               :onc_visual_patient_period_notes,
               :onc_visual_native_application,
               :onc_visual_native_application_notes

      test 'Health IT Module demonstrated support for application registration for single patients.' do
        metadata do
          id '01'
          link 'https://www.federalregister.gov/documents/2020/05/01/2020-07419/21st-century-cures-act-interoperability-information-blocking-and-the-onc-health-it-certification'
          description %(
            Health IT Module demonstrated support for application registration for single patients.
          )
        end

        assert @instance.onc_visual_single_registration == 'true', 'Health IT Module did not demonstrate support for application registration for single patients.'
        pass @instance.onc_visual_single_registration_notes if @instance.onc_visual_single_registration_notes.present?
      end

      test 'Health IT Module demonstrated support for application registration for multiple patients.' do
        metadata do
          id '02'
          link 'https://www.federalregister.gov/documents/2020/05/01/2020-07419/21st-century-cures-act-interoperability-information-blocking-and-the-onc-health-it-certification'
          description %(
            Health IT Module demonstrated support for supports application registration for multiple patients.
          )
        end

        assert @instance.onc_visual_multi_registration == 'true', 'Health IT Module did not demonstrate support for application registration for multiple patients.'
        pass @instance.onc_visual_multi_registration_notes if @instance.onc_visual_multi_registration_notes.present?
      end

      test 'Health IT Module demonstrated a graphical user interface for user to authorize FHIR resources.' do
        metadata do
          id '03'
          link 'https://www.federalregister.gov/documents/2020/05/01/2020-07419/21st-century-cures-act-interoperability-information-blocking-and-the-onc-health-it-certification'
          description %(
            Health IT Module demonstrated a graphical user interface for user to authorize FHIR resources
          )
        end

        assert @instance.onc_visual_single_scopes == 'true', 'Health IT Module did not demonstrate a graphical user interface for user to authorize FHIR resources'
        pass @instance.onc_visual_single_scopes_notes if @instance.onc_visual_single_scopes_notes.present?
      end

      test 'Health IT Module informed patient when "offline_access" scope is being granted during authorization.' do
        metadata do
          id '04'
          link 'https://www.federalregister.gov/documents/2020/05/01/2020-07419/21st-century-cures-act-interoperability-information-blocking-and-the-onc-health-it-certification'
          description %(
            Health IT Module informed patient when "offline_access" scope is being granted during authorization.
          )
        end

        assert @instance.onc_visual_single_offline_access == 'true', 'Health IT Module did not inform patient when offline access scope is being granted during authorization.'
        pass @instance.onc_visual_single_offline_access_notes if @instance.onc_visual_single_offline_access_notes.present?
      end

      test 'Health IT Module attested that refresh tokens are valid for a period of no shorter than three months.' do
        metadata do
          id '05'
          link 'https://www.federalregister.gov/documents/2020/05/01/2020-07419/21st-century-cures-act-interoperability-information-blocking-and-the-onc-health-it-certification'
          description %(
            Health IT Module attested that refresh tokens are valid for a period of no shorter than three months.
          )
        end

        assert @instance.onc_visual_refresh_timeout == 'true', 'Health IT Module did not attest that refresh tokens are valid for a period of no shorter than three months.'
        pass @instance.onc_visual_refresh_timeout_notes if @instance.onc_visual_refresh_timeout_notes.present?
      end

      test 'Health IT developer demonstrated the ability of the Health IT Module / authorization server to validate token it has issued.' do
        metadata do
          id '06'
          link 'https://www.federalregister.gov/documents/2020/05/01/2020-07419/21st-century-cures-act-interoperability-information-blocking-and-the-onc-health-it-certification'
          description %(
            Health IT developer demonstrated the ability of the Health IT Module / authorization server to validate token it has issued
          )
        end

        assert @instance.onc_visual_introspection == 'true', 'Health IT Module did not demonstrate the ability of the Health IT Module / authorization server to validate token it has issued'
        pass @instance.onc_visual_introspection_notes if @instance.onc_visual_introspection_notes.present?
      end

      test 'Tester verifies that all information is accurate and without omission.' do
        metadata do
          id '07'
          link 'https://www.federalregister.gov/documents/2020/05/01/2020-07419/21st-century-cures-act-interoperability-information-blocking-and-the-onc-health-it-certification'
          description %(
            Tester verifies that all information is accurate and without omission.
          )
        end

        assert @instance.onc_visual_data_without_omission == 'true', 'Tester did not verify that all information is accurate and without omission.'
        pass @instance.onc_visual_data_without_omission_notes if @instance.onc_visual_data_without_omission_notes.present?
      end

      test 'Information returned no greater than scopes pre-authorized for multi-patient queries.' do
        metadata do
          id '08'
          link 'https://www.federalregister.gov/documents/2020/05/01/2020-07419/21st-century-cures-act-interoperability-information-blocking-and-the-onc-health-it-certification'
          description %(
            Information returned no greater than scopes pre-authorized for multi-patient queries.
          )
        end

        assert @instance.onc_visual_multi_scopes_no_greater == 'true', 'Tester did not verify that all information is accurate and without omission.'
        pass @instance.onc_visual_multi_scopes_no_greater_notes if @instance.onc_visual_multi_scopes_no_greater_notes.present?
      end

      test 'Health IT developer demonstrated the documentation is available at a publicly accessible URL.' do
        metadata do
          id '09'
          link 'https://www.federalregister.gov/documents/2020/05/01/2020-07419/21st-century-cures-act-interoperability-information-blocking-and-the-onc-health-it-certification'
          description %(
            Health IT developer demonstrated the documentation is available at a publicly accessible URL.
          )
        end

        assert @instance.onc_visual_documentation == 'true', 'Health IT developer did not demonstrate the documentation is available at a publicly accessible URL.'
        pass @instance.onc_visual_documentation_notes if @instance.onc_visual_documentation_notes.present?
      end

      test 'Health IT developer confirms the Health IT module does not cache the JWK Set received via a TLS-protected URL for longer than the cache-control header received by an application indicates.' do
        metadata do
          id '10'
          link 'https://www.federalregister.gov/documents/2020/05/01/2020-07419/21st-century-cures-act-interoperability-information-blocking-and-the-onc-health-it-certification'
          description %(
            The Health IT developer confirms the Health IT module does not cache the JWK Set received via a TLS-protected URL for longer than the cache-control header indicates.
          )
        end

        assert @instance.onc_visual_jwks_cache == 'true', 'Health IT developer did not confirm that the JWK Sets are not cached for longer than appropriate.'
        pass @instance.onc_visual_jwks_cache_notes if @instance.onc_visual_jwks_cache_notes.present?
      end

      test 'Health IT developer demonstrates support for the Patient Demographics Suffix USCDI v1 element.' do
        metadata do
          id '11'
          link 'https://www.healthit.gov/isa/united-states-core-data-interoperability-uscdi'
          description %(
            ONC certification criteria states that all USCDI v1 data classes and elements need to be supported, including Patient
            Demographics - Suffix.However, US Core v3.1.1 does not tag the relevant element
            (Patient.name.suffix) as MUST SUPPORT. The Health IT developer must demonstrate support
            for this USCDI v1 element as described in the US Core Patient Profile implementation guidance.
          )
        end

        assert @instance.onc_visual_patient_suffix == 'true', 'Health IT developer did not demonstrate that Patient Demographics Suffix is supported.'
        pass @instance.onc_visual_patient_suffix_notes if @instance.onc_visual_patient_suffix_notes.present?
      end

      test 'Health IT developer demonstrates support for the Patient Demographics Previous Name USCDI v1 element.' do
        metadata do
          id '12'
          link 'https://www.healthit.gov/isa/united-states-core-data-interoperability-uscdi'
          description %(
            ONC certification criteria states that all USCDI v1 data classes and elements need to be supported, including Patient
            Demographics - Previous Name. However, US Core v3.1.1 does not tag the relevant element
            (Patient.name.period) as MUST SUPPORT. The Health IT developer must demonstrate support
            for this USCDI v1 element as described in the US Core Patient Profile implementation guidance.
          )
        end

        assert @instance.onc_visual_patient_period == 'true', 'Health IT developer did not demonstrate that Patient Demographics Previous Name is supported.'
        pass @instance.onc_visual_patient_period_notes if @instance.onc_visual_patient_period_notes.present?
      end

      test 'Health IT developer demonstrates support for issuing refresh tokens to native applications.' do
        metadata do
          id '13'
          link 'https://www.federalregister.gov/documents/2020/11/04/2020-24376/information-blocking-and-the-onc-health-it-certification-program-extension-of-compliance-dates-and'
          description %(
            The health IT developer demonstrates the ability of the Health IT
            Module to grant a refresh token valid for a period of no less
            than three months to native applications capable of storing a
            refresh token.

            This cannot be tested in an automated way because the health IT
            developer may require use of additional security mechanisms within
            the OAuth 2.0 authorization flow to ensure authorization is sufficiently
            secure for native applications.
          )
        end

        assert @instance.onc_visual_native_application == 'true', 'Health IT developer did not demonstrate support for issuing refresh tokens to native applications.'
        pass @instance.onc_visual_native_application_notes if @instance.onc_visual_native_application_notes.present?
      end
    end
  end
end
