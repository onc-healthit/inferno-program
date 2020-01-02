# frozen_string_literal: true

module Inferno
  module Sequence
    module SharedONCLaunchTests
      def self.included(klass)
        klass.extend(ClassMethods)
      end

      def required_scopes
        []
      end

      def skip_if_no_access_token
        skip_if @instance.token.blank?, 'No access token was received during the SMART launch'
      end

      module ClassMethods
        def required_scope_test(index:, patient_or_user:)
          test :onc_scopes do
            metadata do
              id index
              name "#{patient_or_user.capitalize}-level access with OpenID Connect and Refresh Token scopes used."
              link 'http://www.hl7.org/fhir/smart-app-launch/scopes-and-launch-context/index.html#quick-start'
              description %(
                The scopes being input must follow the guidelines specified in the smart-app-launch guide
              )
            end

            skip_if_auth_failed

            [
              {
                scopes: @instance.scopes,
                received_or_requested: 'requested'
              },
              {
                scopes: @instance.received_scopes,
                received_or_requested: 'received'
              }
            ].each do |metadata|
              scopes = metadata[:scopes].split(' ')
              received_or_requested = metadata[:received_or_requested]

              missing_scopes = required_scopes - scopes
              assert missing_scopes.empty?, "Required scopes were not #{received_or_requested}: #{missing_scopes.join(', ')}"

              scopes -= required_scopes
              # Other 'okay' scopes
              scopes.delete('online_access')

              patient_scope_found = false

              scopes.each do |scope|
                bad_format_message = "#{received_or_requested.capitalize} scope '#{scope}' does not follow the format: #{patient_or_user}/[ resource | * ].[ read | * ]"
                scope_pieces = scope.split('/')

                assert scope_pieces.count == 2, bad_format_message
                assert scope_pieces[0] == patient_or_user, bad_format_message

                resource_access = scope_pieces[1].split('.')
                bad_resource_message = "'#{resource_access[0]}' must be either a valid resource type or '*'"

                assert resource_access.count == 2, bad_format_message
                assert valid_resource_types.include?(resource_access[0]), bad_resource_message
                assert resource_access[1] =~ /^(\*|read)/, bad_format_message

                patient_scope_found = true
              end

              assert patient_scope_found, "#{patient_or_user.capitalize}-level scope in the format: #{patient_or_user}/[ resource | * ].[ read | *] was not #{received_or_requested}."
            end
          end
        end

        def patient_context_test(index:, refresh: false)
          test :patient_context do
            metadata do
              id index
              name 'Patient context provided during token exchange and patient resource can be retrieved'
              link 'http://www.hl7.org/fhir/smart-app-launch/scopes-and-launch-context/index.html#scopes-for-requesting-context-data'
              description %(
                The `patient` field is a String value with a patient id,
                indicating that the app was launched in the context of this FHIR
                Patient
              )
            end

            if refresh
              skip_if_no_refresh_token
              skip_unless @refresh_successful, 'Token was not successfully refreshed'
            else
              skip_if_auth_failed
            end

            skip_if_no_access_token

            skip_if @instance.patient_id.blank?, 'Token response did not contain `patient` field'

            @client.set_bearer_token(@instance.token)
            patient_read_response = @client.read(versioned_resource_class('Patient'), @instance.patient_id)
            assert_response_ok patient_read_response

            patient = patient_read_response.resource
            assert patient.is_a?(versioned_resource_class('Patient')), 'Expected response to be a Patient resource'
          end
        end

        def encounter_context_test(index:, refresh: false)
          test :encounter_context do
            metadata do
              id index
              name 'Encounter context provided during token exchange and encounter resource can be retrieved'
              link 'http://www.hl7.org/fhir/smart-app-launch/scopes-and-launch-context/index.html#scopes-for-requesting-context-data'
              description %(
                The `encounter` field is a String value with a encounter id,
                indicating that the app was launched in the context of this FHIR
                Encounter
              )
            end

            if refresh
              skip_if_no_refresh_token
              skip_unless @refresh_successful, 'Token was not successfully refreshed'
            else
              skip_if_auth_failed
            end

            skip_if_no_access_token

            skip_if @instance.encounter_id.blank?, 'Token response did not contain `encounter` field'

            @client.set_bearer_token(@instance.token)
            encounter_read_response = @client.read(versioned_resource_class('Encounter'), @instance.encounter_id)
            assert_response_ok encounter_read_response

            encounter = encounter_read_response.resource
            assert encounter.is_a?(versioned_resource_class('Encounter')), 'Expected response to be an Encounter resource'
          end
        end
      end
    end
  end
end
