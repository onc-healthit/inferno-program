# frozen_string_literal: true

require_relative 'onc_smart_discovery_sequence'

module Inferno
  module Sequence
    class OncStandaloneSMARTDiscoverySequence < OncSMARTDiscoverySequence
      extends_sequence OncSMARTDiscoverySequence

      title 'SMART on FHIR Discovery'

      test_id_prefix 'SA-OSD'

      requires :onc_sl_url
      defines :oauth_authorize_endpoint, :oauth_token_endpoint,
              :oauth_register_endpoint, :onc_sl_oauth_token_endpoint,
              :onc_sl_oauth_authorize_endpoint

      description "Retrieve server's SMART on FHIR configuration"

      details %(
        # Background

        The #{title} Sequence test looks for authorization endpoints and SMART
        capabilities as described by the [SMART App Launch
        Framework](http://hl7.org/fhir/smart-app-launch/).

        # Test Methodology

        This test suite performs two HTTP GETs to examine the SMART on FHIR configuration contained
        in both the `/metadata` and `/.well-known/smart-configuration`
        endpoints.  It ensures that all required fields are present, and that information
        provided is consistent between the two endpoints.  These tests currently require both endpoints
        to be implemented to ensure maximum compatibility with existing clients.

        Optional fields are not required and these tests do NOT flag warnings if they are not
        present.

        For more information regarding SMART App Launch discovery, see:

        * [SMART App Launch Framework](http://hl7.org/fhir/smart-app-launch/index.html)
      )

      def url_property
        'onc_sl_url'
      end

      def after_save_oauth_endpoints(oauth_token_endpoint, oauth_authorize_endpoint)
        # Save the endpoints for use in the Token Revocation test at the end of
        # the ONC Test Method, because we want that to use the endpoints for the
        # Single Patient API set of tests, in case there are different ones for
        # the EHR launch.
        @instance.onc_sl_oauth_token_endpoint = oauth_token_endpoint
        @instance.onc_sl_oauth_authorize_endpoint = oauth_authorize_endpoint
        @instance.save!
      end

      def self.required_smart_capabilities
        [
          'launch-standalone',
          'client-public',
          'client-confidential-symmetric',
          'sso-openid-connect',
          'context-standalone-patient',
          'permission-offline',
          'permission-patient'
        ]
      end
    end
  end
end
