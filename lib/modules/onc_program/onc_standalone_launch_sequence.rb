# frozen_string_literal: true

require_relative '../smart/standalone_launch_sequence'
require_relative './shared_onc_launch_tests'

module Inferno
  module Sequence
    class OncStandaloneLaunchSequence < StandaloneLaunchSequence
      extends_sequence StandaloneLaunchSequence
      include Inferno::Sequence::SharedONCLaunchTests

      title 'ONC Standalone Launch Sequence'

      description 'Demonstrate the ONC SMART Standalone Launch Sequence.'

      test_id_prefix 'OSLS'

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
        ['openid', 'fhirUser', 'launch/patient', 'launch/encounter', 'offline_access']
      end

      required_scope_test(index: '10', patient_or_user: 'patient')

      test :unauthorized_read do
        metadata do
          id '11'
          name 'Server rejects unauthorized access'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html#behavior'
          description %(
            A server SHALL reject any unauthorized requests by returning an HTTP
            401 unauthorized response code.
          )
          versions :r4
        end

        @client.set_no_auth
        skip_if_auth_failed

        reply = @client.read(FHIR::Patient, @instance.patient_id)
        @client.set_bearer_token(@instance.token)

        assert_response_unauthorized reply
      end

      patient_context_test(index: '12')

      encounter_context_test(index: '13')
    end
  end
end
