# frozen_string_literal: true

require_relative './shared_onc_launch_tests'

module Inferno
  module Sequence
    class OncStandaloneTokenRefreshSequence < OncTokenRefreshSequence
      extends_sequence OncTokenRefreshSequence

      title 'Token Refresh'
      test_id_prefix 'SA-OTR'

      title 'Token Refresh'
      description 'Demonstrate token refresh capability.'
      test_id_prefix 'TR'

      requires :onc_sl_url, :onc_sl_client_id, :onc_sl_confidential_client, :onc_sl_client_secret, :refresh_token, :oauth_token_endpoint
      defines :token

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
    end
  end
end
