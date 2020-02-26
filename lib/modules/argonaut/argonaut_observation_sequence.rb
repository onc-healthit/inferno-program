# frozen_string_literal: true

module Inferno
  module Sequence
    class ArgonautObservationSequence < SequenceBase
      SMOKING_STATUS_PROFILE = Inferno::ValidationUtil::ARGONAUT_URIS[:smoking_status]
      OBSERVATION_RESULTS_PROFILE = Inferno::ValidationUtil::ARGONAUT_URIS[:observation_results]

      title 'Observation'

      description 'Verify that Observation resources on the FHIR server follow the Argonaut Data Query Implementation Guide'

      test_id_prefix 'AROB'

      requires :token, :patient_id
      conformance_supports :Observation

      def validate_resource_item(resource, property, value)
        case property
        when 'patient'
          assert resource.subject&.reference&.include?(value), 'Subject on resource does not match patient requested'
        when 'category'
          codings = resource.try(:category).try(:coding)
          assert !codings.nil?, 'Category on resource did not match category requested'
          assert codings.any? { |coding| !coding.try(:code).nil? && coding.try(:code) == value }, 'Category on resource did not match category requested'
        when 'date'
          # todo
        when 'code'
          codings = resource.try(:code).try(:coding)
          assert !codings.nil?, 'Code on resource did not match code requested'
          assert codings.any? { |coding| !coding.try(:code).nil? && coding.try(:code) == value }, 'Code on resource did not match code requested'
        end
      end

      details %(
        # Background

        The #{title} Sequence tests `#{title.gsub(/\s+/, '')}` resources associated with the provided patient.  The resources
        returned will be checked for consistency against the [#{title} Argonaut Profile](https://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-observationresults.html)

        # Test Methodology

        This test suite accesses the server endpoint at `/#{title.gsub(/\s+/, '')}/?category=laboratory&patient={id}` using a `GET` request.
        It parses the #{title} and verifies that it conforms to the profile.

        It collects the following information that is saved in the testing session for use by later tests:

        * List of `#{title.gsub(/\s+/, '')}` resources

        For more information on the #{title}, visit these links:

        * [FHIR DSTU2 #{title}](https://www.hl7.org/fhir/DSTU2/#{title.gsub(/\s+/, '')}.html)
        * [Argonauts #{title} Profile](https://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-observationresults.html)
              )

      @resources_found = false

      test 'Observation Results search without authorization' do
        metadata do
          id '01'
          link 'http://www.fhir.org/guides/argonaut/r2/Conformance-server.html'
          description %(
            An Observation Results search does not work without proper authorization.
          )
          versions :dstu2
        end

        @client.set_no_auth
        skip 'Could not verify this functionality when bearer token is not set' if @instance.token.blank?

        reply = get_resource_by_params(versioned_resource_class('Observation'), patient: @instance.patient_id, category: 'laboratory')
        @client.set_bearer_token(@instance.token)
        assert_response_unauthorized reply
      end

      test 'Server returns expected results from Observation Results search by patient + category' do
        metadata do
          id '02'
          link 'http://www.fhir.org/guides/argonaut/r2/Conformance-server.html'
          description %(
            A server is capable of returning all of a patient's laboratory results queried by category.
          )
          versions :dstu2
        end

        search_params = { patient: @instance.patient_id, category: 'laboratory' }
        reply = get_resource_by_params(versioned_resource_class('Observation'), search_params)
        assert_response_ok(reply)
        assert_bundle_response(reply)

        resource_count = reply.try(:resource).try(:entry).try(:length) || 0
        @resources_found = true if resource_count.positive?

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        @observationresults = reply.try(:resource).try(:entry).try(:first).try(:resource)
        validate_search_reply(versioned_resource_class('Observation'), reply, search_params)
        save_resource_ids_in_bundle(versioned_resource_class('Observation'), reply, OBSERVATION_RESULTS_PROFILE)
      end

      test 'Server returns expected results from Observation Results search by patient + category + date' do
        metadata do
          id '03'
          link 'http://www.fhir.org/guides/argonaut/r2/Conformance-server.html'
          description %(
            A server is capable of returning all of a patient's laboratory results queried by category code and date range.
          )
          versions :dstu2
        end

        skip_if_not_supported(:Observation, [:search, :read])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        assert !@observationresults.nil?, 'Expected valid Observation resource to be present'
        date = @observationresults.try(:effectiveDateTime)
        assert !date.nil?, 'Observation effectiveDateTime not returned'
        search_params = { patient: @instance.patient_id, category: 'laboratory', date: date }
        reply = get_resource_by_params(versioned_resource_class('Observation'), search_params)
        validate_search_reply(versioned_resource_class('Observation'), reply, search_params)
      end

      test 'Server returns expected results from Observation Results search by patient + category + code' do
        metadata do
          id '04'
          link 'http://www.fhir.org/guides/argonaut/r2/Conformance-server.html'
          description %(
            A server is capable of returning all of a patient's laboratory results queried by category and code.
          )
          versions :dstu2
        end

        skip_if_not_supported(:Observation, [:search, :read])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        assert !@observationresults.nil?, 'Expected valid Observation resource to be present'
        code = @observationresults.try(:code).try(:coding).try(:first).try(:code)
        assert !code.nil?, 'Observation code not returned'
        search_params = { patient: @instance.patient_id, category: 'laboratory', code: code }
        reply = get_resource_by_params(versioned_resource_class('Observation'), search_params)
        validate_search_reply(versioned_resource_class('Observation'), reply, search_params)
      end

      test 'Server returns expected results from Observation Results search by patient + category + code + date' do
        metadata do
          id '05'
          optional
          link 'http://www.fhir.org/guides/argonaut/r2/Conformance-server.html'
          description %(
            A server SHOULD be capable of returning all of a patient's laboratory results queried by category and one or more codes and date range.
          )
          versions :dstu2
        end

        skip_if_not_supported(:Observation, [:search, :read])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        assert !@observationresults.nil?, 'Expected valid Observation resource to be present'
        code = @observationresults.try(:code).try(:coding).try(:first).try(:code)
        assert !code.nil?, 'Observation code not returned'
        date = @observationresults.try(:effectiveDateTime)
        assert !date.nil?, 'Observation effectiveDateTime not returned'
        search_params = { patient: @instance.patient_id, category: 'laboratory', code: code, date: date }
        reply = get_resource_by_params(versioned_resource_class('Observation'), search_params)
        validate_search_reply(versioned_resource_class('Observation'), reply, search_params)
      end

      test 'Server rejects Smoking Status search without authorization' do
        metadata do
          id '06'
          link 'http://www.fhir.org/guides/argonaut/r2/Conformance-server.html'
          description %(
            A Smoking Status search does not work without proper authorization.
          )
          versions :dstu2
        end

        skip_if_not_supported(:Observation, [:search, :read])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        @client.set_no_auth
        skip 'Could not verify this functionality when bearer token is not set' if @instance.token.blank?

        reply = get_resource_by_params(versioned_resource_class('Observation'), patient: @instance.patient_id, code: '72166-2')
        @client.set_bearer_token(@instance.token)
        assert_response_unauthorized reply
      end

      test 'Server returns expected results from Smoking Status search by patient + code' do
        metadata do
          id '07'
          link 'http://www.fhir.org/guides/argonaut/r2/Conformance-server.html'
          description %(
            A server is capable of returning a patient's smoking status.
          )
          versions :dstu2
        end

        skip_if_not_supported(:Observation, [:search, :read])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        search_params = { patient: @instance.patient_id, code: '72166-2' }
        reply = get_resource_by_params(versioned_resource_class('Observation'), search_params)
        validate_search_reply(versioned_resource_class('Observation'), reply, search_params)
        save_resource_ids_in_bundle(versioned_resource_class('Observation'), reply, SMOKING_STATUS_PROFILE)
      end

      test 'Observation read resource supported' do
        metadata do
          id '08'
          link 'http://www.fhir.org/guides/argonaut/r2/Conformance-server.html'
          description %(
            All servers SHALL make available the read interactions for the Argonaut Profiles the server chooses to support.
          )
          versions :dstu2
        end

        skip_if_not_supported(:Observation, [:search, :read])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        validate_read_reply(@observationresults, versioned_resource_class('Observation'))
      end

      test 'Observation history resource supported' do
        metadata do
          id '09'
          link 'http://www.fhir.org/guides/argonaut/r2/Conformance-server.html'
          optional
          description %(
            All servers SHOULD make available the vread and history-instance interactions for the Argonaut Profiles the server chooses to support.
          )
          versions :dstu2
        end

        skip_if_not_supported(:Observation, [:history])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        validate_history_reply(@observationresults, versioned_resource_class('Observation'))
      end

      test 'Observation vread resource supported' do
        metadata do
          id '10'
          link 'http://www.fhir.org/guides/argonaut/r2/Conformance-server.html'
          optional
          description %(
            All servers SHOULD make available the vread and history-instance interactions for the Argonaut Profiles the server chooses to support.
          )
          versions :dstu2
        end

        skip_if_not_supported(:Observation, [:vread])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        validate_vread_reply(@observationresults, versioned_resource_class('Observation'))
      end

      test 'Observation Result resources associated with Patient conform to Argonaut profiles' do
        metadata do
          id '11'
          link 'http://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-observationresults.html'
          description %(
            Observation Result resources associated with Patient conform to Argonaut profiles.
          )
          versions :dstu2
        end

        test_resources_against_profile('Observation', OBSERVATION_RESULTS_PROFILE)
        skip_unless @profiles_encountered.include?(OBSERVATION_RESULTS_PROFILE), 'No Observation Results found.'
        assert !@profiles_failed.include?(OBSERVATION_RESULTS_PROFILE), "Observation Results failed validation.<br/>#{@profiles_failed[OBSERVATION_RESULTS_PROFILE]}"
      end

      test 'All references can be resolved' do
        metadata do
          id '12'
          link 'https://www.hl7.org/fhir/DSTU2/references.html'
          description %(
            All references in the Observation resource should be resolveable.
          )
          versions :dstu2
        end

        skip_if_not_supported(:Observation, [:search, :read])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        validate_reference_resolutions(@observationresults)
      end
    end
  end
end
