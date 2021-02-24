# frozen_string_literal: true

module Inferno
  module Sequence
    class OncSMARTDiscoverySequence < SequenceBase
      title 'SMART on FHIR Discovery'

      test_id_prefix 'OSD'

      requires :url
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
        'url'
      end

      def instance_url
        @instance.send(url_property)
      end

      def after_save_oauth_endpoints(oauth_token_endpoint, oauth_authorize_endpoint)
        # run after the oauth endpoints are saved
      end

      # Only require EHR launch related capabilities
      # A separate sequence handles standalone launch

      def self.required_smart_capabilities
        [
          'launch-ehr',
          'client-confidential-symmetric',
          'sso-openid-connect',
          'context-banner',
          'context-style',
          'context-ehr-patient',
          'permission-offline',
          'permission-user'
        ]
      end

      def required_smart_capabilities
        self.class.required_smart_capabilities
      end

      SMART_CAPABILITIES = [
        'launch-ehr',
        'launch-standalone',
        'client-public',
        'client-confidential-symmetric',
        'sso-openid-connect',
        'context-banner',
        'context-style',
        'context-ehr-patient',
        'context-standalone-patient',
        'permission-offline',
        'permission-patient',
        'permission-user'
      ].freeze

      REQUIRED_WELL_KNOWN_FIELDS = [
        'authorization_endpoint',
        'token_endpoint',
        'capabilities'
      ].freeze

      RECOMMENDED_WELL_KNOWN_FIELDS = [
        'scopes_supported',
        'response_types_supported',
        'management_endpoint',
        'introspection_endpoint',
        'revocation_endpoint'
      ].freeze

      SMART_OAUTH_EXTENSION_URL = 'http://fhir-registry.smarthealthit.org/StructureDefinition/oauth-uris'

      REQUIRED_OAUTH_ENDPOINTS = [
        { url: 'authorize', description: 'authorization' },
        { url: 'token', description: 'token' }
      ].freeze

      OPTIONAL_OAUTH_ENDPOINTS = [
        { url: 'register', description: 'dynamic registration' },
        { url: 'manage', description: 'authorization management' },
        { url: 'introspect', description: 'token introspection' },
        { url: 'revoke', description: 'token revocation' }
      ].freeze

      test 'FHIR server makes SMART configuration available from well-known endpoint' do
        metadata do
          id '01'
          link 'http://www.hl7.org/fhir/smart-app-launch/conformance/#using-well-known'
          description %(
            The authorization endpoints accepted by a FHIR resource server can
            be exposed as a Well-Known Uniform Resource Identifier
          )
        end

        @client = FHIR::Client.for_testing_instance(@instance, url_property: url_property)
        @client&.monitor_requests

        well_known_configuration_url = instance_url.chomp('/') + '/.well-known/smart-configuration'
        well_known_configuration_response = LoggedRestClient.get(well_known_configuration_url)
        assert_response_ok(well_known_configuration_response)
        assert_response_content_type(well_known_configuration_response, 'application/json')
        assert_valid_json(well_known_configuration_response.body)

        @well_known_configuration = JSON.parse(well_known_configuration_response.body)
        @well_known_authorize_url = @well_known_configuration['authorization_endpoint']
        @well_known_token_url = @well_known_configuration['token_endpoint']
        @well_known_register_url = @well_known_configuration['registration_endpoint']
        @well_known_manage_url = @well_known_configuration['management_endpoint']
        @well_known_introspect_url = @well_known_configuration['introspection_endpoint']
        @well_known_revoke_url = @well_known_configuration['revocation_endpoint']

        @instance.update(
          oauth_authorize_endpoint: @well_known_authorize_url,
          oauth_token_endpoint: @well_known_token_url,
          oauth_register_endpoint: @well_known_configuration['registration_endpoint']
        )

        assert @well_known_configuration.present?, 'No .well-known/smart-configuration body'
      end

      test :required_well_known_fields do
        metadata do
          id '02'
          name 'Well-known configuration contains required fields'
          link 'http://hl7.org/fhir/smart-app-launch/conformance/index.html#metadata'
          description %(
            The JSON from .well-known/smart-configuration contains the following
            required fields: #{REQUIRED_WELL_KNOWN_FIELDS.map { |field| "`#{field}`" }.join(', ')}
          )
        end

        skip_if @well_known_configuration.blank?, 'No well-known SMART configuration found.'

        missing_fields = REQUIRED_WELL_KNOWN_FIELDS - @well_known_configuration.keys
        assert missing_fields.empty?, "The following required fields are missing: #{missing_fields.join(', ')}"
      end

      test :recommended_well_known_fields do
        metadata do
          id '03'
          name 'Well-known configuration contains recommended fields'
          link 'http://hl7.org/fhir/smart-app-launch/conformance/index.html#metadata'
          optional
          description %(
            The JSON from .well-known/smart-configuration contains the following
            recommended fields: #{RECOMMENDED_WELL_KNOWN_FIELDS.map { |field| "`#{field}`" }.join(', ')}.

            This test is optional because these fields are recommended, not required.
          )
        end

        skip_if @well_known_configuration.blank?, 'No well-known SMART configuration found.'

        missing_fields = RECOMMENDED_WELL_KNOWN_FIELDS - @well_known_configuration.keys
        assert missing_fields.empty?, "The following recommended fields are missing: #{missing_fields.join(', ')}"
      end

      test 'Capability Statement provides OAuth 2.0 endpoints' do
        metadata do
          id '04'
          link 'http://hl7.org/fhir/smart-app-launch/conformance/index.html#using-cs'
          description %(
            If a server requires SMART on FHIR authorization for access, its
            metadata must support automated discovery of OAuth2 endpoints.
          )
        end

        @conformance = @client.conformance_statement
        oauth_metadata = @client.get_oauth2_metadata_from_conformance(false) # strict mode off, don't require server to state smart conformance

        assert oauth_metadata.present?, 'No OAuth 2.0 metadata in server CapabilityStatement'

        REQUIRED_OAUTH_ENDPOINTS.each do |endpoint|
          url = oauth_metadata[:"#{endpoint[:url]}_url"]
          instance_variable_set(:"@conformance_#{endpoint[:url]}_url", url)

          assert url.present?, "No #{endpoint[:description]} URI provided in CapabilityStatement resource"
          assert_valid_http_uri url, "Invalid #{endpoint[:description]} url: '#{url}'"
        end

        warning do
          services = []
          @conformance.try(:rest)&.each do |endpoint|
            endpoint.try(:security).try(:service)&.each do |sec_service|
              sec_service.try(:coding)&.each do |coding|
                services << coding.code
              end
            end
          end

          assert !services.empty?, 'No security services listed. CapabilityStatement.rest.security.service should be SMART-on-FHIR.'
          assert services.any? { |service| service == 'SMART-on-FHIR' }, "CapabilityStatement.rest.security.service set to #{services.map { |e| "'" + e + "'" }.join(', ')}.  It should contain 'SMART-on-FHIR'."
        end

        security_extensions =
          @conformance.rest.first.security&.extension
            &.find { |extension| extension.url == SMART_OAUTH_EXTENSION_URL }
            &.extension

        OPTIONAL_OAUTH_ENDPOINTS.each do |endpoint|
          url =
            security_extensions
              &.find { |extension| extension.url == endpoint[:url] }
              &.value

          # Many of the optional endpoints have very little specified and it is unrealistic
          # to have them implemented in a standard way.  Therefore, instead of providing
          # a warning if they do not exist, only validate that they are valid URLs when they
          # are provided.  This is something we may want to expose in some kind of informational
          # message in the future.

          next unless url.present?

          warning do
            assert_valid_http_uri url, "Invalid #{endpoint[:description]} url: '#{url}'"
            instance_variable_set(:"@conformance_#{endpoint[:url]}_url", url)
          end
        end

        @instance.update(
          oauth_authorize_endpoint: @conformance_authorize_url,
          oauth_token_endpoint: @conformance_token_url,
          oauth_register_endpoint: @conformance_register_url
        )

        after_save_oauth_endpoints(@instance.oauth_token_endpoint, @instance.oauth_authorize_endpoint)
      end

      test 'OAuth 2.0 Endpoints in the conformance statement match those from the well-known configuration' do
        metadata do
          id '05'
          link 'http://hl7.org/fhir/smart-app-launch/conformance/index.html#using-cs'
          description %(
           If a server requires SMART on FHIR authorization for access, its
           metadata must support automated discovery of OAuth2 endpoints.
          )
        end

        REQUIRED_OAUTH_ENDPOINTS.each do |endpoint|
          url = endpoint[:url]
          well_known_url = instance_variable_get(:"@well_known_#{url}_url")
          conformance_url = instance_variable_get(:"@conformance_#{url}_url")

          assert well_known_url == conformance_url, %(
            The #{endpoint[:description]} url is not consistent between the
            well-known configuration and the conformance statement:

            * Well-known #{url} url: #{well_known_url}
            * CapabilityStatement #{url} url: #{conformance_url}
          )
        end
      end

      test :required_capabilities do
        metadata do
          id '06'
          name 'Well-known configuration declares support for required capabilities'
          link 'http://hl7.org/fhir/smart-app-launch/conformance/index.html#core-capabilities'
          description %(
            A SMART on FHIR server SHALL convey its capabilities to app
            developers by listing the SMART core capabilities supported by
            their implementation within the Well-known configuration file.
            This test ensures that the capabilities required by this scenario
            are properly documented in the Well-known file.
          )
        end

        skip_if @well_known_configuration.blank?, 'No well-known SMART configuration found.'

        capabilities = @well_known_configuration['capabilities']
        assert capabilities.is_a?(Array), 'The well-known capabilities are not an array'

        missing_capabilities = required_smart_capabilities - capabilities
        assert missing_capabilities.empty?, "The following capabilities required for this scenario are missing: #{missing_capabilities.join(', ')}"
      end
    end
  end
end
