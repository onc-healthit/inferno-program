# frozen_string_literal: true

module Inferno
  module Sequence
    class ONCAccessVerifyRestrictedSequence < SequenceBase
      title 'Restricted Resource Type Access'

      description 'Verify that access to resource types can be restricted to app.'
      test_id_prefix 'AVR'

      details %(

        The following are required to be seen:

          * AllergyIntolerance

          * CarePlan

          * CareTeam

          * Condition

          * Device

          * DiagnosticReport

          * DocumentReference

          * Encounter

          * Goal

          * Immunization

          * MedicationRequest

          * Observation

          * Procedure


      )

      requires :onc_sl_url, :token, :patient_id, :received_scopes

      def scopes
        @instance.received_scopes || @instance.onc_sl_restricted_scopes
      end

      def url_property
        'onc_sl_url'
      end

      def scope_granting_access(resource, scopes)
        scopes.split(' ').find do |scope|
          scope.start_with?("patient/#{resource}", 'patient/*') && scope.end_with?('*', 'read')
        end
      end

      test :validate_right_scopes do
        metadata do
          id '01'
          name 'Verify scope provided do not contain all resource types'

          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end

        skip_if @instance.received_scopes.nil?, 'No SMART scopes were provided to the test.'

        all_resources = [
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
          'MedicationRequest',
          'Observation',
          'Procedure'
        ]

        allowed_resources = all_resources.select { |resource| scope_granting_access(resource, scopes).present? }
        denied_resources = all_resources - allowed_resources

        assert denied_resources.present?, "This test requires at least one resource to be denied, but the provided scope '#{@instance.received_scopes}' grants access to all resource types."
        pass "Resources to be denied: #{denied_resources.join(',')}"
      end

      test :validate_patient_authorization do
        metadata do
          id '02'
          name 'Patient resources on the FHIR server follow the US Core Implementation Guide'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient'
          description %(
            This test checks if the resources returned from bulk data export conform to the US Core profiles. This includes checking for missing data elements and valueset verification.
          )
        end
        skip_if @instance.patient_id.nil?, 'Patient ID not provided to test. The patient ID is typically provided during in a SMART launch context.'
        skip_if @instance.received_scopes.nil?, 'No scopes were received.'

        @client = FHIR::Client.for_testing_instance(@instance, url_property: url_property)
        @client.set_bearer_token(@instance.token) unless @client.nil? || @instance.nil? || @instance.token.nil?
        @client&.monitor_requests

        reply = @client.read(FHIR::Patient, @instance.patient_id)

        access_allowed_scope = scope_granting_access('Patient', scopes)

        if access_allowed_scope.present?
          assert_response_ok reply
          pass "Access granted by scope #{access_allowed_scope} and request properly returned #{reply&.response&.dig(:code)}"
        else
          assert_response_unauthorized reply
        end
      end

      test :validate_allergyintolerance_authorization do
        metadata do
          id '03'
          name 'Access to AllergyIntolerance resources are restricted properly based on patient-selected scope'
          link 'http://www.hl7.org/fhir/smart-app-launch/scopes-and-launch-context/index.html'
          description %(
          )
        end

        skip_if @instance.patient_id.nil?, 'Patient ID not provided to test.'
        skip_if @instance.received_scopes.nil?, 'No scopes were received.'

        params = {
          patient: @instance.patient_id
        }

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: params
          }
        }
        reply = @client.search('AllergyIntolerance', options)
        access_allowed_scope = scope_granting_access('AllergyIntolerance', scopes)

        if access_allowed_scope.present?

          if reply.code == 400
            error_message = 'Server is expected to grant access to the resource.  A search without a status can return an HTTP 400 status, but must also must include an OperationOutcome. No OperationOutcome is present in the body of the response.'
            begin
              parsed_reply = JSON.parse(reply.body)
              assert parsed_reply['resourceType'] == 'OperationOutcome', error_message
            rescue JSON::ParserError
              assert false, error_message
            end

            options.merge!(access_verify_status_codes[sequence[:resource].downcase])
            reply = @client.search('AllergyIntolerance', options)
          end

          assert_response_ok reply
          pass "Access granted by scope #{access_allowed_scope} and request properly returned #{reply&.response&.dig(:code)}"

        else
          assert_response_unauthorized reply
        end
      end

      test :validate_careplan_authorization do
        metadata do
          id '04'
          name 'Access to CarePlan resources are restricted properly based on patient-selected scope'
          link 'http://www.hl7.org/fhir/smart-app-launch/scopes-and-launch-context/index.html'
          description %(
          )
        end

        skip_if @instance.patient_id.nil?, 'Patient ID not provided to test.'
        skip_if @instance.received_scopes.nil?, 'No scopes were received.'

        params = {
          patient: @instance.patient_id,
          category: 'assess-plan'
        }

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: params
          }
        }
        reply = @client.search('CarePlan', options)
        access_allowed_scope = scope_granting_access('CarePlan', scopes)

        if access_allowed_scope.present?

          if reply.code == 400
            error_message = 'Server is expected to grant access to the resource.  A search without a status can return an HTTP 400 status, but must also must include an OperationOutcome. No OperationOutcome is present in the body of the response.'
            begin
              parsed_reply = JSON.parse(reply.body)
              assert parsed_reply['resourceType'] == 'OperationOutcome', error_message
            rescue JSON::ParserError
              assert false, error_message
            end

            options.merge!(access_verify_status_codes[sequence[:resource].downcase])
            reply = @client.search('CarePlan', options)
          end

          assert_response_ok reply
          pass "Access granted by scope #{access_allowed_scope} and request properly returned #{reply&.response&.dig(:code)}"

        else
          assert_response_unauthorized reply
        end
      end

      test :validate_careteam_authorization do
        metadata do
          id '05'
          name 'Access to CareTeam resources are restricted properly based on patient-selected scope'
          link 'http://www.hl7.org/fhir/smart-app-launch/scopes-and-launch-context/index.html'
          description %(
          )
        end

        skip_if @instance.patient_id.nil?, 'Patient ID not provided to test.'
        skip_if @instance.received_scopes.nil?, 'No scopes were received.'

        params = {
          patient: @instance.patient_id,
          status: 'active'
        }

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: params
          }
        }
        reply = @client.search('CareTeam', options)
        access_allowed_scope = scope_granting_access('CareTeam', scopes)

        if access_allowed_scope.present?

          if reply.code == 400
            error_message = 'Server is expected to grant access to the resource.  A search without a status can return an HTTP 400 status, but must also must include an OperationOutcome. No OperationOutcome is present in the body of the response.'
            begin
              parsed_reply = JSON.parse(reply.body)
              assert parsed_reply['resourceType'] == 'OperationOutcome', error_message
            rescue JSON::ParserError
              assert false, error_message
            end

            options.merge!(access_verify_status_codes[sequence[:resource].downcase])
            reply = @client.search('CareTeam', options)
          end

          assert_response_ok reply
          pass "Access granted by scope #{access_allowed_scope} and request properly returned #{reply&.response&.dig(:code)}"

        else
          assert_response_unauthorized reply
        end
      end

      test :validate_condition_authorization do
        metadata do
          id '06'
          name 'Access to Condition resources are restricted properly based on patient-selected scope'
          link 'http://www.hl7.org/fhir/smart-app-launch/scopes-and-launch-context/index.html'
          description %(
          )
        end

        skip_if @instance.patient_id.nil?, 'Patient ID not provided to test.'
        skip_if @instance.received_scopes.nil?, 'No scopes were received.'

        params = {
          patient: @instance.patient_id
        }

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: params
          }
        }
        reply = @client.search('Condition', options)
        access_allowed_scope = scope_granting_access('Condition', scopes)

        if access_allowed_scope.present?

          if reply.code == 400
            error_message = 'Server is expected to grant access to the resource.  A search without a status can return an HTTP 400 status, but must also must include an OperationOutcome. No OperationOutcome is present in the body of the response.'
            begin
              parsed_reply = JSON.parse(reply.body)
              assert parsed_reply['resourceType'] == 'OperationOutcome', error_message
            rescue JSON::ParserError
              assert false, error_message
            end

            options.merge!(access_verify_status_codes[sequence[:resource].downcase])
            reply = @client.search('Condition', options)
          end

          assert_response_ok reply
          pass "Access granted by scope #{access_allowed_scope} and request properly returned #{reply&.response&.dig(:code)}"

        else
          assert_response_unauthorized reply
        end
      end

      test :validate_device_authorization do
        metadata do
          id '07'
          name 'Access to Device resources are restricted properly based on patient-selected scope'
          link 'http://www.hl7.org/fhir/smart-app-launch/scopes-and-launch-context/index.html'
          description %(
          )
        end

        skip_if @instance.patient_id.nil?, 'Patient ID not provided to test.'
        skip_if @instance.received_scopes.nil?, 'No scopes were received.'

        params = {
          patient: @instance.patient_id
        }

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: params
          }
        }
        reply = @client.search('Device', options)
        access_allowed_scope = scope_granting_access('Device', scopes)

        if access_allowed_scope.present?

          assert_response_ok reply
          pass "Access granted by scope #{access_allowed_scope} and request properly returned #{reply&.response&.dig(:code)}"

        else
          assert_response_unauthorized reply
        end
      end

      test :validate_diagnosticreport_authorization do
        metadata do
          id '08'
          name 'Access to DiagnosticReport resources are restricted properly based on patient-selected scope'
          link 'http://www.hl7.org/fhir/smart-app-launch/scopes-and-launch-context/index.html'
          description %(
          )
        end

        skip_if @instance.patient_id.nil?, 'Patient ID not provided to test.'
        skip_if @instance.received_scopes.nil?, 'No scopes were received.'

        params = {
          patient: @instance.patient_id,
          category: 'LAB'
        }

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: params
          }
        }
        reply = @client.search('DiagnosticReport', options)
        access_allowed_scope = scope_granting_access('DiagnosticReport', scopes)

        if access_allowed_scope.present?

          if reply.code == 400
            error_message = 'Server is expected to grant access to the resource.  A search without a status can return an HTTP 400 status, but must also must include an OperationOutcome. No OperationOutcome is present in the body of the response.'
            begin
              parsed_reply = JSON.parse(reply.body)
              assert parsed_reply['resourceType'] == 'OperationOutcome', error_message
            rescue JSON::ParserError
              assert false, error_message
            end

            options.merge!(access_verify_status_codes[sequence[:resource].downcase])
            reply = @client.search('DiagnosticReport', options)
          end

          assert_response_ok reply
          pass "Access granted by scope #{access_allowed_scope} and request properly returned #{reply&.response&.dig(:code)}"

        else
          assert_response_unauthorized reply
        end
      end

      test :validate_documentreference_authorization do
        metadata do
          id '09'
          name 'Access to DocumentReference resources are restricted properly based on patient-selected scope'
          link 'http://www.hl7.org/fhir/smart-app-launch/scopes-and-launch-context/index.html'
          description %(
          )
        end

        skip_if @instance.patient_id.nil?, 'Patient ID not provided to test.'
        skip_if @instance.received_scopes.nil?, 'No scopes were received.'

        params = {
          patient: @instance.patient_id
        }

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: params
          }
        }
        reply = @client.search('DocumentReference', options)
        access_allowed_scope = scope_granting_access('DocumentReference', scopes)

        if access_allowed_scope.present?

          if reply.code == 400
            error_message = 'Server is expected to grant access to the resource.  A search without a status can return an HTTP 400 status, but must also must include an OperationOutcome. No OperationOutcome is present in the body of the response.'
            begin
              parsed_reply = JSON.parse(reply.body)
              assert parsed_reply['resourceType'] == 'OperationOutcome', error_message
            rescue JSON::ParserError
              assert false, error_message
            end

            options.merge!(access_verify_status_codes[sequence[:resource].downcase])
            reply = @client.search('DocumentReference', options)
          end

          assert_response_ok reply
          pass "Access granted by scope #{access_allowed_scope} and request properly returned #{reply&.response&.dig(:code)}"

        else
          assert_response_unauthorized reply
        end
      end

      test :validate_encounter_authorization do
        metadata do
          id '10'
          name 'Access to Encounter resources are restricted properly based on patient-selected scope'
          link 'http://www.hl7.org/fhir/smart-app-launch/scopes-and-launch-context/index.html'
          description %(
          )
        end

        skip_if @instance.patient_id.nil?, 'Patient ID not provided to test.'
        skip_if @instance.received_scopes.nil?, 'No scopes were received.'

        params = {
          patient: @instance.patient_id
        }

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: params
          }
        }
        reply = @client.search('Encounter', options)
        access_allowed_scope = scope_granting_access('Encounter', scopes)

        if access_allowed_scope.present?

          if reply.code == 400
            error_message = 'Server is expected to grant access to the resource.  A search without a status can return an HTTP 400 status, but must also must include an OperationOutcome. No OperationOutcome is present in the body of the response.'
            begin
              parsed_reply = JSON.parse(reply.body)
              assert parsed_reply['resourceType'] == 'OperationOutcome', error_message
            rescue JSON::ParserError
              assert false, error_message
            end

            options.merge!(access_verify_status_codes[sequence[:resource].downcase])
            reply = @client.search('Encounter', options)
          end

          assert_response_ok reply
          pass "Access granted by scope #{access_allowed_scope} and request properly returned #{reply&.response&.dig(:code)}"

        else
          assert_response_unauthorized reply
        end
      end

      test :validate_goal_authorization do
        metadata do
          id '11'
          name 'Access to Goal resources are restricted properly based on patient-selected scope'
          link 'http://www.hl7.org/fhir/smart-app-launch/scopes-and-launch-context/index.html'
          description %(
          )
        end

        skip_if @instance.patient_id.nil?, 'Patient ID not provided to test.'
        skip_if @instance.received_scopes.nil?, 'No scopes were received.'

        params = {
          patient: @instance.patient_id
        }

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: params
          }
        }
        reply = @client.search('Goal', options)
        access_allowed_scope = scope_granting_access('Goal', scopes)

        if access_allowed_scope.present?

          if reply.code == 400
            error_message = 'Server is expected to grant access to the resource.  A search without a status can return an HTTP 400 status, but must also must include an OperationOutcome. No OperationOutcome is present in the body of the response.'
            begin
              parsed_reply = JSON.parse(reply.body)
              assert parsed_reply['resourceType'] == 'OperationOutcome', error_message
            rescue JSON::ParserError
              assert false, error_message
            end

            options.merge!(access_verify_status_codes[sequence[:resource].downcase])
            reply = @client.search('Goal', options)
          end

          assert_response_ok reply
          pass "Access granted by scope #{access_allowed_scope} and request properly returned #{reply&.response&.dig(:code)}"

        else
          assert_response_unauthorized reply
        end
      end

      test :validate_immunization_authorization do
        metadata do
          id '12'
          name 'Access to Immunization resources are restricted properly based on patient-selected scope'
          link 'http://www.hl7.org/fhir/smart-app-launch/scopes-and-launch-context/index.html'
          description %(
          )
        end

        skip_if @instance.patient_id.nil?, 'Patient ID not provided to test.'
        skip_if @instance.received_scopes.nil?, 'No scopes were received.'

        params = {
          patient: @instance.patient_id
        }

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: params
          }
        }
        reply = @client.search('Immunization', options)
        access_allowed_scope = scope_granting_access('Immunization', scopes)

        if access_allowed_scope.present?

          if reply.code == 400
            error_message = 'Server is expected to grant access to the resource.  A search without a status can return an HTTP 400 status, but must also must include an OperationOutcome. No OperationOutcome is present in the body of the response.'
            begin
              parsed_reply = JSON.parse(reply.body)
              assert parsed_reply['resourceType'] == 'OperationOutcome', error_message
            rescue JSON::ParserError
              assert false, error_message
            end

            options.merge!(access_verify_status_codes[sequence[:resource].downcase])
            reply = @client.search('Immunization', options)
          end

          assert_response_ok reply
          pass "Access granted by scope #{access_allowed_scope} and request properly returned #{reply&.response&.dig(:code)}"

        else
          assert_response_unauthorized reply
        end
      end

      test :validate_medicationrequest_authorization do
        metadata do
          id '13'
          name 'Access to MedicationRequest resources are restricted properly based on patient-selected scope'
          link 'http://www.hl7.org/fhir/smart-app-launch/scopes-and-launch-context/index.html'
          description %(
          )
        end

        skip_if @instance.patient_id.nil?, 'Patient ID not provided to test.'
        skip_if @instance.received_scopes.nil?, 'No scopes were received.'

        params = {
          patient: @instance.patient_id,
          intent: 'order'
        }

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: params
          }
        }
        reply = @client.search('MedicationRequest', options)
        access_allowed_scope = scope_granting_access('MedicationRequest', scopes)

        if access_allowed_scope.present?

          if reply.code == 400
            error_message = 'Server is expected to grant access to the resource.  A search without a status can return an HTTP 400 status, but must also must include an OperationOutcome. No OperationOutcome is present in the body of the response.'
            begin
              parsed_reply = JSON.parse(reply.body)
              assert parsed_reply['resourceType'] == 'OperationOutcome', error_message
            rescue JSON::ParserError
              assert false, error_message
            end

            options.merge!(access_verify_status_codes[sequence[:resource].downcase])
            reply = @client.search('MedicationRequest', options)
          end

          assert_response_ok reply
          pass "Access granted by scope #{access_allowed_scope} and request properly returned #{reply&.response&.dig(:code)}"

        else
          assert_response_unauthorized reply
        end
      end

      test :validate_observation_authorization do
        metadata do
          id '14'
          name 'Access to Observation resources are restricted properly based on patient-selected scope'
          link 'http://www.hl7.org/fhir/smart-app-launch/scopes-and-launch-context/index.html'
          description %(
          )
        end

        skip_if @instance.patient_id.nil?, 'Patient ID not provided to test.'
        skip_if @instance.received_scopes.nil?, 'No scopes were received.'

        params = {
          patient: @instance.patient_id,
          code: '2708-6'
        }

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: params
          }
        }
        reply = @client.search('Observation', options)
        access_allowed_scope = scope_granting_access('Observation', scopes)

        if access_allowed_scope.present?

          if reply.code == 400
            error_message = 'Server is expected to grant access to the resource.  A search without a status can return an HTTP 400 status, but must also must include an OperationOutcome. No OperationOutcome is present in the body of the response.'
            begin
              parsed_reply = JSON.parse(reply.body)
              assert parsed_reply['resourceType'] == 'OperationOutcome', error_message
            rescue JSON::ParserError
              assert false, error_message
            end

            options.merge!(access_verify_status_codes[sequence[:resource].downcase])
            reply = @client.search('Observation', options)
          end

          assert_response_ok reply
          pass "Access granted by scope #{access_allowed_scope} and request properly returned #{reply&.response&.dig(:code)}"

        else
          assert_response_unauthorized reply
        end
      end

      test :validate_procedure_authorization do
        metadata do
          id '15'
          name 'Access to Procedure resources are restricted properly based on patient-selected scope'
          link 'http://www.hl7.org/fhir/smart-app-launch/scopes-and-launch-context/index.html'
          description %(
          )
        end

        skip_if @instance.patient_id.nil?, 'Patient ID not provided to test.'
        skip_if @instance.received_scopes.nil?, 'No scopes were received.'

        params = {
          patient: @instance.patient_id
        }

        options = {
          search: {
            flag: false,
            compartment: nil,
            parameters: params
          }
        }
        reply = @client.search('Procedure', options)
        access_allowed_scope = scope_granting_access('Procedure', scopes)

        if access_allowed_scope.present?

          if reply.code == 400
            error_message = 'Server is expected to grant access to the resource.  A search without a status can return an HTTP 400 status, but must also must include an OperationOutcome. No OperationOutcome is present in the body of the response.'
            begin
              parsed_reply = JSON.parse(reply.body)
              assert parsed_reply['resourceType'] == 'OperationOutcome', error_message
            rescue JSON::ParserError
              assert false, error_message
            end

            options.merge!(access_verify_status_codes[sequence[:resource].downcase])
            reply = @client.search('Procedure', options)
          end

          assert_response_ok reply
          pass "Access granted by scope #{access_allowed_scope} and request properly returned #{reply&.response&.dig(:code)}"

        else
          assert_response_unauthorized reply
        end
      end
    end
  end
end
