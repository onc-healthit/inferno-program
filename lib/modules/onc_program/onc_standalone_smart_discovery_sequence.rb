# frozen_string_literal: true

require_relative 'onc_smart_discovery_sequence'

module Inferno
  module Sequence
    class OncStandaloneSMARTDiscoverySequence < OncSMARTDiscoverySequence
      extends_sequence OncSMARTDiscoverySequence

      title 'SMART on FHIR Discovery'

      test_id_prefix 'SA-OSD'

      requires :onc_sl_url
      defines :oauth_authorize_endpoint, :oauth_token_endpoint, :oauth_register_endpoint

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
        @instance.onc_sl_oauth_token_endpoint = oauth_token_endpoint
        @instance.onc_sl_oauth_authorize_endpoint = oauth_authorize_endpoint
        @instance.save!
      end
    end
  end
end
