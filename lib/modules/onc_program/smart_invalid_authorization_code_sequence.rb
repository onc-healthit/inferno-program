# frozen_string_literal: true

require_relative './shared_onc_launch_tests'

module Inferno
  module Sequence
    class SMARTInvalidAuthorizationCodeSequence < SequenceBase
      include Inferno::Sequence::SharedONCLaunchTests

      title 'SMART App Launch Error: Invalid Authorization Code'
      description 'Demonstrate that the server properly validates Authorization code'

      test_id_prefix 'SIAC'

      requires :onc_sl_client_id,
               :onc_sl_confidential_client,
               :onc_sl_client_secret,
               :onc_sl_scopes,
               :oauth_authorize_endpoint,
               :oauth_token_endpoint,
               :initiate_login_uri,
               :redirect_uris

      show_uris

      details %(
        # Background

        The Invalid AuthorizationCode Sequence verifies that a SMART Launch Sequence,
        specifically the [Standalone
        Launch](http://hl7.org/fhir/smart-app-launch/#standalone-launch-sequence)
        Sequence, does not work in the case where the client sends an invalid
        Authorization code during launch.  This must fail to ensure
        that a genuine bearer token is not leaked to a counterfit resource server.

        This test is not included as part of a regular SMART Launch Sequence
        because some servers may revoke current authorization code after the test.
      )

      def url_property
        'onc_sl_url'
      end

      def instance_url
        @instance.send(url_property)
      end

      def instance_client_id
        @instance.onc_sl_client_id
      end

      def instance_confidential_client
        @instance.onc_sl_confidential_client
      end

      def instance_client_secret
        @instance.onc_sl_client_secret
      end

      def instance_scopes
        @instance.onc_sl_scopes
      end

      test 'OAuth server redirects client browser to app redirect URI' do
        metadata do
          id '01'
          link 'http://www.hl7.org/fhir/smart-app-launch/'
          description %(
            Client browser redirected from OAuth server to redirect URI of
            client app as described in SMART authorization sequence.
          )
        end
        @instance.save
        @instance.update(state: SecureRandom.uuid)

        oauth2_params = {
          'response_type' => 'code',
          'client_id' => @instance.onc_sl_client_id,
          'redirect_uri' => @instance.redirect_uris,
          'scope' => instance_scopes,
          'state' => @instance.state,
          'aud' => @instance.onc_sl_url
        }

        oauth_authorize_endpoint = @instance.oauth_authorize_endpoint

        oauth2_auth_query = oauth_authorize_endpoint

        oauth2_auth_query += if oauth_authorize_endpoint.include? '?'
                               '&'
                             else
                               '?'
                             end

        oauth2_params.each do |key, value|
          oauth2_auth_query += "#{key}=#{CGI.escape(value)}&"
        end

        redirect oauth2_auth_query[0..-2], 'redirect'
      end

      code_and_state_received_test(index: '02')
      invalid_code_test(index: '03')
      invalid_client_id_test(index: '04')
    end
  end
end
