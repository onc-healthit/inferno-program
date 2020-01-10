# frozen_string_literal: true

require_relative '../smart/ehr_launch_sequence'
require_relative './shared_onc_launch_tests'

module Inferno
  module Sequence
    class OncEHRLaunchSequence < EHRLaunchSequence
      extends_sequence EHRLaunchSequence
      include Inferno::Sequence::SharedONCLaunchTests

      title 'ONC EHR Launch Sequence'

      description 'Demonstrate the ONC SMART EHR Launch Sequence.'

      test_id_prefix 'OELS'

      requires :client_id, :confidential_client, :client_secret, :oauth_authorize_endpoint, :oauth_token_endpoint, :scopes, :initiate_login_uri, :redirect_uris

      defines :token, :id_token, :refresh_token, :patient_id

      def valid_resource_types
        [
          '*',
          'Patient',
          'AllergyIntolerance',
          'CarePlan',
          'CareTeam',
          'Condition',
          'Device',
          'DiagnosticReport',
          'DocumentReference',
          'Encounter',
          'Goal',
          'Immunization',
          'Location',
          'Medication',
          'MedicationOrder',
          'MedicationRequest',
          'MedicationStatement',
          'Observation',
          'Organization',
          'Practitioner',
          'PractitionerRole',
          'Procedure',
          'Provenance'
        ]
      end

      def required_scopes
        ['openid', 'fhirUser', 'launch', 'offline_access']
      end

      required_scope_test(index: '12', patient_or_user: 'user')

      patient_context_test(index: '13')

      encounter_context_test(index: '14')

      test :smart_style_url do
        metadata do
          id '15'
          link 'http://www.hl7.org/fhir/smart-app-launch/scopes-and-launch-context/index.html#styling'
          name 'Launch context contains smart_style_url which links to valid JSON'
          description %(
            In order to mimic the style of the SMART host more closely, SMART
            apps can check for the existence of this launch context parameter
            and download the JSON file referenced by the URL value.
          )
        end

        skip_if_auth_failed

        skip_if @token_response_body.blank?, 'No valid token response received'

        assert @token_response_body['smart_style_url'].present?, 'Token response did not contain smart_style_url'

        response = LoggedRestClient.get(@token_response_body['smart_style_url'])
        assert_response_ok(response)
        assert_valid_json(response.body)
      end

      test :need_patient_banner do
        metadata do
          id '16'
          link 'http://www.hl7.org/fhir/smart-app-launch/scopes-and-launch-context/index.html#launch-context-arrives-with-your-access_token'
          name 'Launch context contains need_patient_banner'
          description %(
            `need_patient_banner` is a boolean value indicating whether the app
            was launched in a UX context where a patient banner is required
            (when true) or not required (when false).
          )
        end

        skip_if_auth_failed

        skip_if @token_response_body.blank?, 'No valid token response received'

        assert @token_response_body.key?('need_patient_banner'), 'Token response did not contain need_patient_banner'
      end
    end
  end
end
