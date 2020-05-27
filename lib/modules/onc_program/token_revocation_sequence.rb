# frozen_string_literal: true

module Inferno
  module Sequence
    class TokenRevocationSequence < SequenceBase
      title 'Token Revocation'
      description 'Demonstrate the Health IT module is capable of revoking access granted to an application.'

      test_id_prefix 'TR'

      requires :onc_sl_url, :token, :refresh_token, :patient_id, :oauth_token_endpoint 

      def encoded_secret(client_id, client_secret)
        "Basic #{Base64.strict_encode64(client_id + ':' + client_secret)}"
      end

      test :validate_rejected do
        metadata do
          id '01'
          name 'Access to Patient resource returns unauthorized after token revocation.'
          link 'http://www.hl7.org/fhir/smart-app-launch/'
          description %(
            This test checks that the Patient resource returns unuathorized after token revocation.
          )
        end
        skip_if @instance.patient_id.nil?, 'Patient ID not provided to test. The patient ID is typically provided during in a SMART launch context.'
        skip_if @instance.token.nil?, 'Bearer token not provided.  This test verifies that the bearer token can no longer be used to access a Patient resource.'

        @client = FHIR::Client.for_testing_instance(@instance, url_property: 'onc_sl_url')
        @client.set_bearer_token(@instance.token) unless @client.nil? || @instance.nil? || @instance.token.nil?
        @client&.monitor_requests

        reply = @client.read(FHIR::Patient, @instance.patient_id)

        assert_response_unauthorized reply
      end

      test :refresh_rejected do
        metadata do
          id '02'
          name 'Token refresh fails after token revocation.'
          link 'http://www.hl7.org/fhir/smart-app-launch/'
          description %(
            This test checks that refreshing token fails after token revokation.
          )
        end
        skip_if @instance.patient_id.nil?, 'Patient ID not provided to test. The patient ID is typically provided during in a SMART launch context.'
        skip_if @instance.refresh_token.nil?, 'Patient ID not provided to test. The patient ID is typically provided during in a SMART launch context.'

        oauth2_params = {
          'grant_type' => 'refresh_token',
          'refresh_token' => @instance.refresh_token
        }
        oauth2_headers = { 'Content-Type' => 'application/x-www-form-urlencoded' }

        oauth2_headers['Authorization'] = encoded_secret(@instance.onc_sl_client_id, @instance.onc_sl_client_secret) if @instance.onc_sl_confidential_client

        token_response = LoggedRestClient.post(@instance.oauth_token_endpoint, oauth2_params, oauth2_headers)

        assert_response_bad_or_unauthorized token_response

      end
    end
  end
end
