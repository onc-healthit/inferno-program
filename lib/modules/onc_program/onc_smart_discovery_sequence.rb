# frozen_string_literal: true

require_relative '../smart/smart_discovery_sequence'

module Inferno
  module Sequence
    class ONCSMARTDiscoverySequence < SMARTDiscoverySequence
      extends_sequence SMARTDiscoverySequence

      title 'SMART on FHIR Discovery'

      test_id_prefix 'OSD'

      requires :url

      description "Retrieve server's SMART on FHIR configuration"

      details %(
        # Background

        The #{title} Sequence test looks for authorization endpoints and SMART
        capabilities as described by the [SMART App Launch
        Framework](http://hl7.org/fhir/smart-app-launch/conformance/index.html).
        The SMART launch framework uses OAuth 2.0 to *authorize* apps, like
        Inferno, to access certain information on a FHIR server. The
        authorization service accessed at the endpoint allows users to give
        these apps permission without sharing their credentials with the
        application itself. Instead, the application receives an access token
        which allows it to access resources on the server. The access token
        itself has a limited lifetime and permission scopes associated with it.
        A refresh token may also be provided to the application in order to
        obtain another access token. Unlike access tokens, a refresh token is
        not shared with the resource server. If OpenID Connect is used, an id
        token may be provided as well. The id token can be used to
        *authenticate* the user. The id token is digitally signed and allows the
        identity of the user to be verified.

        # Test Methodology

        This test suite will examine the SMART on FHIR configuration contained
        in both the `/metadata` and `/.well-known/smart-configuration`
        endpoints.

        For more information see:

        * [SMART App Launch Framework](http://hl7.org/fhir/smart-app-launch/index.html)
        * [The OAuth 2.0 Authorization Framework](https://tools.ietf.org/html/rfc6749)
        * [OpenID Connect Core](https://openid.net/specs/openid-connect-core-1_0.html)
      )

      REQUIRED_SMART_CAPABILITIES = [
        'launch-ehr',
        'launch-standalone',
        'client-public',
        'client-confidential-symmetric',
        'sso-openid-connect',
        'context-banner',
        'context-style',
        'context-ehr-patient',
        'context-standalone-patient',
        'context-standalone-encounter',
        'permission-offline',
        'permission-patient',
        'permission-user'
      ].freeze

      test :required_capabilities do
        metadata do
          id '06'
          name 'Well-known configuration declares support for required capabilities'
          link 'http://hl7.org/fhir/smart-app-launch/conformance/index.html#core-capabilities'
          description %(
            A SMART on FHIR server SHALL convey its capabilities to app
            developers by listing a set of the capabilities. The following
            capabilities are required: #{REQUIRED_SMART_CAPABILITIES.join(', ')}
          )
        end

        skip_if @well_known_configuration.blank?, 'No well-known SMART configuration found.'

        capabilities = @well_known_configuration['capabilities']
        assert capabilities.is_a?(Array), 'The well-known capabilities are not an array'

        missing_capabilities = REQUIRED_SMART_CAPABILITIES - capabilities
        assert missing_capabilities.empty?, "The following required capabilities are missing: #{missing_capabilities.join(', ')}"
      end
    end
  end
end
