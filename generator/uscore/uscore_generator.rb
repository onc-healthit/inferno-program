# frozen_string_literal: true

require_relative './metadata_extractor'
require_relative '../../lib/app/utils/validation'
require_relative '../generator_base'
require_relative './us_core_unit_test_generator'

module Inferno
  module Generator
    class USCoreGenerator < Generator::Base
      include USCoreMetadataExtractor

      PROFILE_URIS = Inferno::ValidationUtil::US_CORE_R4_URIS

      def unit_test_generator
        @unit_test_generator ||= USCoreUnitTestGenerator.new
      end

      def validation_profile_uri(sequence)
        profile_uri = PROFILE_URIS.key(sequence[:profile])
        "Inferno::ValidationUtil::US_CORE_R4_URIS[:#{profile_uri}]" if profile_uri
      end

      def generate
        metadata = extract_metadata
        metadata[:sequences].reject! { |sequence| sequence[:resource] == 'Medication' }
        # first isolate the profiles that don't have patient searches
        mark_delayed_sequences(metadata)
        find_delayed_references(metadata)
        generate_tests(metadata)
        generate_search_validators(metadata)
        metadata[:sequences].each do |sequence|
          generate_sequence(sequence)
          unit_test_generator.generate(sequence, sequence_out_path, metadata[:name])
        end
        generate_verify_access_module(metadata)
        copy_static_files
        generate_module(metadata)
      end

      def copy_static_files
        Dir.glob(File.join(__dir__, 'static', '*')).each do |static_file|
          FileUtils.cp(static_file, sequence_out_path)
        end
        Dir.glob(File.join(__dir__, 'static_test', '*')).each do |static_file|
          FileUtils.cp(static_file, File.join(sequence_out_path, 'test').to_s)
        end
      end

      def generate_search_validators(metadata)
        metadata[:sequences].each do |sequence|
          sequence[:search_validator] = create_search_validation(sequence)
        end
      end

      def generate_tests(metadata)
        metadata[:sequences].each do |sequence|
          puts "Generating test #{sequence[:name]}"

          # read reference if sequence contains no search sequences
          create_read_test(sequence) if sequence[:delayed_sequence]

          unless sequence[:delayed_sequence]
            # make tests for each SHALL and SHOULD search param, SHALL's first
            sequence[:searches]
              .select { |search_param| search_param[:expectation] == 'SHALL' }
              .select { |search_param| search_param[:must_support_or_mandatory] }
              .each { |search_param| create_search_test(sequence, search_param) }

            sequence[:searches]
              .select { |search_param| search_param[:expectation] == 'SHOULD' }
              .select { |search_param| search_param[:must_support_or_mandatory] }
              .each { |search_param| create_search_test(sequence, search_param) }

            sequence[:search_param_descriptions]
              .select { |_, description| description[:chain].present? }
              .each { |search_param, _| create_chained_search_test(sequence, search_param) }

            # make tests for each SHALL and SHOULD interaction
            sequence[:interactions]
              .select { |interaction| ['SHALL', 'SHOULD'].include? interaction[:expectation] }
              .reject { |interaction| interaction[:code] == 'search-type' }
              .each do |interaction|
              # specific edge cases
              interaction[:code] = 'history' if interaction[:code] == 'history-instance'
              next if interaction[:code] == 'read' && sequence[:delayed_sequence]

              create_interaction_test(sequence, interaction)
            end

            create_include_test(sequence) if sequence[:include_params].any?
            create_revinclude_test(sequence) if sequence[:revincludes].any?
          end
          create_resource_profile_test(sequence)
          create_must_support_test(sequence)
          create_multiple_or_test(sequence) unless sequence[:delayed_sequence]
          create_references_resolved_test(sequence)
        end
      end

      def mark_delayed_sequences(metadata)
        metadata[:sequences].each do |sequence|
          non_patient_search = sequence[:resource] != 'Patient' && sequence[:searches].none? { |search| search[:names].include? 'patient' }
          non_uscdi_resources = ['Encounter', 'Location', 'Organization', 'Practitioner', 'PractitionerRole', 'Provenance']
          sequence[:delayed_sequence] = non_patient_search || non_uscdi_resources.include?(sequence[:resource])
        end
        metadata[:delayed_sequences] = metadata[:sequences].select { |seq| seq[:delayed_sequence] }
        metadata[:non_delayed_sequences] = metadata[:sequences].reject { |seq| seq[:resource] == 'Patient' || seq[:delayed_sequence] }
      end

      def find_delayed_references(metadata)
        delayed_profiles = metadata[:sequences]
          .select { |sequence| sequence[:delayed_sequence] }
          .map { |sequence| sequence[:profile] }

        metadata[:sequences].each do |sequence|
          delayed_sequence_references = sequence[:references]
            .select { |ref_def| (ref_def[:profiles] & delayed_profiles).present? }
            .map do |ref_def|
            delayed_resources = (ref_def[:profiles] & delayed_profiles).map do |profile|
              profile_sequence = metadata[:sequences].find { |seq| seq[:profile] == profile }
              profile_sequence[:resource]
            end
            delayed_profile_intersection = {
              path: ref_def[:path].gsub(sequence[:resource] + '.', ''),
              resources: delayed_resources
            }
            delayed_profile_intersection
          end
          sequence[:delayed_references_constant] = "DELAYED_REFERENCES = #{structure_to_string(delayed_sequence_references)}.freeze"
        end
      end

      def find_first_search(sequence)
        sequence[:searches].find { |search_param| search_param[:expectation] == 'SHALL' } ||
          sequence[:searches].find { |search_param| search_param[:expectation] == 'SHOULD' }
      end

      def generate_sequence(sequence)
        puts "Generating #{sequence[:name]}\n"
        file_name = sequence_out_path + '/' + sequence[:name].downcase + '_sequence.rb'
        template = ERB.new(File.read(File.join(__dir__, 'templates/sequence.rb.erb')))
        output =   template.result_with_hash(sequence)
        FileUtils.mkdir_p(sequence_out_path) unless File.directory?(sequence_out_path)
        File.write(file_name, output)

        generate_profile_definition(sequence)
      end

      def generate_profile_definition(sequence)
        file_name = sequence_out_path + '/profile_definitions/' + sequence[:name].downcase + '_definitions.rb'
        template = ERB.new(File.read(File.join(__dir__, 'templates/sequence_definition.rb.erb')))
        output = template.result_with_hash(sequence)
        FileUtils.mkdir_p(sequence_out_path) unless File.directory?(sequence_out_path)
        File.write(file_name, output)
      end

      def create_read_test(sequence)
        test_key = :resource_read
        read_test = {
          tests_that: "Server returns correct #{sequence[:resource]} resource from the #{sequence[:resource]} read interaction",
          key: test_key,
          index: sequence[:tests].length + 1,
          link: 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html',
          description: "This test will attempt to Reference to #{sequence[:resource]} can be resolved and read."
        }

        read_test[:test_code] = %(
              skip_if_known_not_supported(:#{sequence[:resource]}, [:read])

              #{sequence[:resource].underscore}_references = @instance.resource_references.select { |reference| reference.resource_type == '#{sequence[:resource]}' }
              skip 'No #{sequence[:resource]} references found from the prior searches' if #{sequence[:resource].underscore}_references.blank?

              @#{sequence[:resource].underscore}_ary = #{sequence[:resource].underscore}_references.map do |reference|
                validate_read_reply(
                  FHIR::#{sequence[:resource]}.new(id: reference.resource_id),
                  FHIR::#{sequence[:resource]},
                  check_for_data_absent_reasons
                )
              end
              @#{sequence[:resource].underscore} = @#{sequence[:resource].underscore}_ary.first
              @resources_found = @#{sequence[:resource].underscore}.present?)
        sequence[:tests] << read_test

        unit_test_generator.generate_resource_read_test(
          test_key: test_key,
          resource_type: sequence[:resource],
          class_name: sequence[:class_name]
        )
      end

      def create_include_test(sequence)
        first_search = find_first_search(sequence)
        return if first_search.blank?

        include_test = {
          tests_that: "Server returns the appropriate resource from the following #{first_search[:names].join(' + ')} +  _includes: #{sequence[:include_params].join(', ')}",
          index: sequence[:tests].length + 1,
          optional: true,
          link: 'https://www.hl7.org/fhir/search.html#include',
          description: %(
            A Server SHOULD be capable of supporting the following _includes: #{sequence[:include_params].join(', ')}
            This test will perform a search for #{first_search[:names].join(' + ')} + each of the following  _includes: #{sequence[:include_params].join(', ')}
            The test will fail unless resources for #{sequence[:include_params].join(', ')} are returned in their search.
          ),
          test_code: ''
        }
        search_params = first_search.nil? ? 'search_params = {}' : get_search_params(first_search[:names], sequence)
        resolve_param_from_resource = search_params.include? 'get_value_for_search_param'
        if resolve_param_from_resource && !sequence[:delayed_sequence]
          include_test[:test_code] += %(
            resolved_one = false
            medication_results = false
            patient_ids.each do |patient|
          )
        end
        include_test[:test_code] += search_params
        sequence[:include_params].each do |include|
          resource_name = include.split(':').last.capitalize
          resource_variable = "#{resource_name.underscore}_results" # kind of a hack, but works for now - would have to otherwise figure out resource type of target profile
          operator = sequence[:delayed_sequence] ? '=' : '||='
          include_test[:test_code] += %(
            skip_if_known_include_not_supported('#{sequence[:resource]}', '#{include}')
            search_params['_include'] = '#{include}'
            reply = get_resource_by_params(versioned_resource_class('#{sequence[:resource]}'), search_params)
            assert_response_ok(reply)
            assert_bundle_response(reply)
            #{resource_variable} #{operator} reply&.resource&.entry&.map(&:resource)&.any? { |resource| resource.resourceType == '#{resource_name}' }
            #{"assert #{resource_variable}, 'No #{resource_name} resources were returned from this search'" if sequence[:delayed_sequence]}
          )
        end
        if resolve_param_from_resource && !sequence[:delayed_sequence]
          include_test[:test_code] += %(
            end
            #{skip_if_could_not_resolve(first_search[:names])}
            assert medication_results, 'No Medication resources were returned from this search'
          )
        end
        sequence[:tests] << include_test
      end

      def create_revinclude_test(sequence)
        first_search = find_first_search(sequence)
        return if first_search.blank?

        revinclude_test = {
          tests_that: "Server returns Provenance resources from #{sequence[:resource]} search by #{first_search[:names].join(' + ')} + _revIncludes: Provenance:target",
          index: sequence[:tests].length + 1,
          link: 'https://www.hl7.org/fhir/search.html#revinclude',
          description: %(
            A Server SHALL be capable of supporting the following _revincludes: #{sequence[:revincludes].join(', ')}.\n
            This test will perform a search for #{first_search[:names].join(' + ')} + _revIncludes: Provenance:target and will pass
            if a Provenance resource is found in the reponse.
          ),
          test_code: %(
            skip_if_known_revinclude_not_supported('#{sequence[:resource]}', 'Provenance:target')
            #{skip_if_not_found_code(sequence)}
          )
        }
        search_params = get_search_params(first_search[:names], sequence)
        resolve_param_from_resource = search_params.include? 'get_value_for_search_param'
        if resolve_param_from_resource && !sequence[:delayed_sequence]
          revinclude_test[:test_code] += %(
            resolved_one = false
          )
        end

        revinclude = sequence[:revincludes].first
        resource_name = revinclude.split(':').first
        resource_variable = "#{resource_name.underscore}_results"
        revinclude_test[:test_code] += %(
          #{resource_variable} = []
          #{'patient_ids.each do |patient|' unless sequence[:delayed_sequence]}
          #{search_params}
        )
        revinclude_test[:test_code] += %(
              search_params['_revinclude'] = '#{revinclude}'
              reply = get_resource_by_params(versioned_resource_class('#{sequence[:resource]}'), search_params)
              #{status_search_code(sequence, first_search[:names])}
              assert_response_ok(reply)
              assert_bundle_response(reply)
              #{resource_variable} += fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
                .select { |resource| resource.resourceType == '#{resource_name}'}
        )

        revinclude_test[:test_code] += %(
          #{'end' unless sequence[:delayed_sequence]}
          save_resource_references(versioned_resource_class('#{resource_name}'), #{resource_variable})
          save_delayed_sequence_references(#{resource_variable}, #{sequence[:class_name]}Definitions::DELAYED_REFERENCES)
          #{skip_if_could_not_resolve(first_search[:names]) if resolve_param_from_resource && !sequence[:delayed_sequence]}
          skip 'No Provenance resources were returned from this search' unless #{resource_variable}.present?
        )
        sequence[:tests] << revinclude_test
      end

      def sequence_has_status_search?(sequence)
        status_search? sequence[:search_param_descriptions].keys
      end

      def status_search?(params)
        params.any? { |param| param.to_s.include? 'status' }
      end

      def status_search_code(sequence, current_search)
        if sequence_has_status_search?(sequence) && !status_search?(current_search)
          %(
            reply = perform_search_with_status(reply, search_params) if reply.code == 400
          )
        else
          ''
        end
      end

      def status_param_strings(sequence)
        search_param, param_metadata = sequence[:search_param_descriptions]
          .find { |key, _| key.to_s.include? 'status' }

        status_value_string =
          if param_metadata[:multiple_or] == 'SHALL'
            "'#{param_metadata[:values].to_a.join(',')}'"
          else
            param_metadata[:values]
              .map { |value| "'#{value}'" }
              .join(', ')
          end

        {
          param: "'#{search_param}'",
          value: status_value_string
        }
      end

      def perform_search_with_status_code(sequence)
        status_param = status_param_strings(sequence)

        %(
          def perform_search_with_status(reply, search_param)
            begin
              parsed_reply = JSON.parse(reply.body)
              assert parsed_reply['resourceType'] == 'OperationOutcome', 'Server returned a status of 400 without an OperationOutcome.'
            rescue JSON::ParserError
              assert false, 'Server returned a status of 400 without an OperationOutcome.'
            end


            warning do
              assert @instance.server_capabilities&.search_documented?('#{sequence[:resource]}'),
                %(Server returned a status of 400 with an OperationOutcome, but the
                search interaction for this resource is not documented in the
                CapabilityStatement. If this response was due to the server
                requiring a status parameter, the server must document this
                requirement in its CapabilityStatement.)
            end

            [#{status_param[:value]}].each do |status_value|
              params_with_status = search_param.merge(#{status_param[:param]}: status_value)
              reply = get_resource_by_params(versioned_resource_class('#{sequence[:resource]}'), params_with_status)
              assert_response_ok(reply)
              assert_bundle_response(reply)

              entries = reply.resource.entry.select { |entry| entry.resource.resourceType== '#{sequence[:resource]}' }
              next if entries.blank?

              search_param.merge!(#{status_param[:param]}: status_value)
              break
            end

            reply
          end
        )
      end

      def create_search_test(sequence, search_param)
        test_key = :"search_by_#{search_param[:names].map(&:underscore).join('_')}"
        search_test = {
          tests_that: "Server returns valid results for #{sequence[:resource]} search by #{search_param[:names].join('+')}.",
          key: test_key,
          index: sequence[:tests].length + 1,
          link: 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html',
          optional: search_param[:expectation] != 'SHALL',
          description: %(
            A server #{search_param[:expectation]} support searching by #{search_param[:names].join('+')} on the #{sequence[:resource]} resource.
            This test will pass if resources are returned and match the search criteria. If none are returned, the test is skipped.
            )
        }

        find_comparators(search_param[:names], sequence).each do |param, comparators|
          search_test[:description] += %(
              This will also test support for these #{param} comparators: #{comparators.keys.join(', ')}. Comparator values are created by taking
              a #{param} value from a resource returned in the first search of this sequence and adding/subtracting a day. For example, a date
              of 05/05/2020 will create comparator values of lt2020-05-06 and gt2020-05-04
              )
        end

        if sequence[:resource] == 'MedicationRequest'
          search_test[:description] += %(
            If any MedicationRequest resources use external references to
            Medications, the search will be repeated with
            _include=MedicationRequest:medication.
            )
        end

        is_first_search = search_param == find_first_search(sequence)

        search_test[:description] += 'Because this is the first search of the sequence, resources in the response will be used for subsequent tests.' if is_first_search
        comparator_search_code = get_comparator_searches(search_param[:names], sequence)
        token_system_search_code = get_token_system_search_code(search_param[:names], sequence)
        search_test[:test_code] =
          if is_first_search
            # rcs question: are comparators ever be in the first search?
            get_first_search(search_param[:names], sequence)
          else
            search_params = get_search_params(search_param[:names], sequence)
            resolve_param_from_resource = search_params.include? 'get_value_for_search_param'
            resolved_one_str = %(
              resolved_one = false
            )
            reply_code = %(
              #{search_params}
              reply = get_resource_by_params(versioned_resource_class('#{sequence[:resource]}'), search_params)
              #{status_search_code(sequence, search_param[:names])}
              validate_search_reply(versioned_resource_class('#{sequence[:resource]}'), reply, search_params)
              #{'test_medication_inclusion(reply.resource.entry.map(&:resource), search_params)' if sequence[:resource] == 'MedicationRequest'}
              #{comparator_search_code}
              #{token_system_search_code}
            )
            unless sequence[:delayed_sequence]
              reply_code = %(
                patient_ids.each do |patient|
                  #{reply_code}
                end
              )
            end
            %(
              #{skip_if_search_not_supported_code(sequence, search_param[:names])}
              #{skip_if_not_found_code(sequence)}
              #{resolved_one_str if resolve_param_from_resource && !sequence[:delayed_sequence]}
              #{reply_code}
              #{skip_if_could_not_resolve(search_param[:names]) if resolve_param_from_resource && !sequence[:delayed_sequence]}
            )
          end
        sequence[:tests] << search_test

        is_fixed_value_search = fixed_value_search?(search_param[:names], sequence)
        fixed_value_search_param = is_fixed_value_search ? fixed_value_search_param(search_param[:names], sequence) : nil

        unit_test_generator.generate_search_test(
          test_key: test_key,
          resource_type: sequence[:resource],
          search_params: get_search_param_hash(search_param[:names], sequence),
          is_first_search: is_first_search,
          is_fixed_value_search: is_fixed_value_search,
          is_status_search: status_search?(search_param[:names]),
          has_comparator_tests: comparator_search_code.present?,
          has_status_searches: sequence_has_status_search?(sequence),
          fixed_value_search_param: fixed_value_search_param,
          class_name: sequence[:class_name],
          sequence_name: sequence[:name],
          delayed_sequence: sequence[:delayed_sequence],
          status_param: sequence_has_status_search?(sequence) ? status_param_strings(sequence) : {},
          token_param: get_token_param(search_param[:names], sequence)
        )
      end

      def skip_if_search_not_supported_code(sequence, search_params)
        search_param_string = search_params.map { |param| "'#{param}'" }.join(', ')
        "skip_if_known_search_not_supported('#{sequence[:resource]}', [#{search_param_string}])"
      end

      def create_chained_search_test(sequence, search_param)
        # NOTE: This test is currently hard-coded because chained searches are
        # only required for PractitionerRole
        raise StandardError, 'Chained search tests only supported for PractitionerRole' if sequence[:resource] != 'PractitionerRole'

        chained_param_string = sequence[:search_param_descriptions][search_param][:chain]
          .map { |param| "#{search_param}.#{param[:chain]}" }
          .join(' and ')
        search_test = {
          tests_that: "Server returns expected results from #{sequence[:resource]} chained search by #{chained_param_string}",
          key: :"chained_search_by_#{search_param}",
          index: sequence[:tests].length + 1,
          link: 'https://www.hl7.org/fhir/us/core/StructureDefinition-us-core-practitionerrole.html#mandatory-search-parameters',
          optional: false,
          description: %(
            A server SHALL support searching the #{sequence[:resource]} resource
            with the chained parameters #{chained_param_string}
          )
        }

        search_test[:test_code] = %(
          #{skip_if_not_found_code(sequence)}

          practitioner_role = @practitioner_role_ary.find { |role| role.practitioner&.reference.present? }
          skip_if practitioner_role.blank?, 'No PractitionerRoles containing a Practitioner reference were found'

          begin
            practitioner = practitioner_role.practitioner.read
          rescue ClientException => e
            assert false, "Unable to resolve Practitioner reference: \#{e}"
          end

          assert practitioner.resourceType == 'Practitioner', "Expected FHIR Practitioner but found: \#{practitioner.resourceType}"

          name = practitioner.name&.first&.family
          skip_if name.blank?, 'Practitioner has no family name'

          name_search_response = @client.search(FHIR::PractitionerRole, search: { parameters: { 'practitioner.name': name }})
          assert_response_ok(name_search_response)
          assert_bundle_response(name_search_response)

          name_bundle_entries = fetch_all_bundled_resources(name_search_response, check_for_data_absent_reasons)

          practitioner_role_found = name_bundle_entries.any? { |entry| entry.id == practitioner_role.id }
          assert practitioner_role_found, "PractitionerRole with id \#{practitioner_role.id} not found in search results for practitioner.name = \#{name}"

          identifier = practitioner.identifier.first
          skip_if identifier.blank?, 'Practitioner has no identifier'
          identifier_string = "\#{identifier.system}|\#{identifier.value}"

          identifier_search_response = @client.search(
            FHIR::PractitionerRole,
            search: { parameters: { 'practitioner.identifier': identifier_string } }
          )
          assert_response_ok(identifier_search_response)
          assert_bundle_response(identifier_search_response)

          identifier_bundle_entries = fetch_all_bundled_resources(identifier_search_response, check_for_data_absent_reasons)

          practitioner_role_found = identifier_bundle_entries.any? { |entry| entry.id == practitioner_role.id }
          assert practitioner_role_found, "PractitionerRole with id \#{practitioner_role.id} not found in search results for practitioner.identifier = \#{identifier_string}"
        )

        sequence[:tests] << search_test
        # NOTE: unit test has an intermittent failure and is disabled until this
        # failure can be addressed
        # unit_test_generator.generate_chained_search_test(class_name: sequence[:class_name])
      end

      def create_interaction_test(sequence, interaction)
        return if interaction[:code] == 'create'

        test_key = :"#{interaction[:code]}_interaction"
        interaction_test = {
          tests_that: "Server returns correct #{sequence[:resource]} resource from #{sequence[:resource]} #{interaction[:code]} interaction",
          key: test_key,
          index: sequence[:tests].length + 1,
          link: 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html',
          description: "A server #{interaction[:expectation]} support the #{sequence[:resource]} #{interaction[:code]} interaction.",
          optional: interaction[:expectation] != 'SHALL'
        }

        validate_reply_args = [
          "@#{sequence[:resource].underscore}",
          "versioned_resource_class('#{sequence[:resource]}')"
        ]
        validate_reply_args << 'check_for_data_absent_reasons' if interaction[:code] == 'read'
        validate_reply_args_string = validate_reply_args.join(', ')

        interaction_test[:test_code] = %(
              skip_if_known_not_supported(:#{sequence[:resource]}, [:#{interaction[:code]}])
              #{skip_if_not_found_code(sequence)}

              validate_#{interaction[:code]}_reply(#{validate_reply_args_string}))

        sequence[:tests] << interaction_test

        if interaction[:code] == 'read' # rubocop:disable Style/GuardClause
          unit_test_generator.generate_resource_read_test(
            test_key: test_key,
            resource_type: sequence[:resource],
            class_name: sequence[:class_name],
            interaction_test: true
          )
        end
      end

      def create_must_support_test(sequence)
        test = {
          tests_that: "All must support elements are provided in the #{sequence[:resource]} resources returned.",
          index: sequence[:tests].length + 1,
          link: 'http://www.hl7.org/fhir/us/core/general-guidance.html#must-support',
          test_code: '',
          description: %(
            US Core Responders SHALL be capable of populating all data elements as part of the query results as specified by the US Core Server Capability Statement.
            This will look through the #{sequence[:resource]} resources found previously for the following must support elements:
          )
        }

        sequence[:must_supports][:elements].each do |element|
          test[:description] += %(
            * #{element[:path]})
          # class is mapped to local_class in fhir_models. Update this after it
          # has been added to the description so that the description contains
          # the original path
          element[:path] = element[:path].gsub(/(?<!\w)class(?!\w)/, 'local_class')
        end

        must_support_extensions = sequence[:must_supports][:extensions]
        must_support_extensions.each do |extension|
          test[:description] += %(
            * #{extension[:id]})
        end

        must_support_slices = sequence[:must_supports][:slices]
        must_support_slices.each do |slice|
          test[:description] += %(
            * #{slice[:name]})
        end

        sequence[:must_supports][:elements].each { |must_support| must_support[:path]&.gsub!('[x]', '') }
        sequence[:must_supports][:slices].each { |must_support| must_support[:path]&.gsub!('[x]', '') }

        test[:test_code] += %(
          #{skip_if_not_found_code(sequence)}
          must_supports = #{sequence[:class_name]}Definitions::MUST_SUPPORTS
        )
        resource_array = sequence[:delayed_sequence] ? "@#{sequence[:resource].underscore}_ary" : "@#{sequence[:resource].underscore}_ary&.values&.flatten"

        if sequence[:must_supports][:extensions].present?
          test[:test_code] += %(
            missing_must_support_extensions = must_supports[:extensions].reject do |must_support_extension|
              #{resource_array}&.any? do |resource|
                resource.extension.any? { |extension| extension.url == must_support_extension[:url] }
              end
            end
      )
        end

        if sequence[:must_supports][:slices].present?
          test[:test_code] += %(
            missing_slices = must_supports[:slices].reject do |slice|
              @#{sequence[:resource].underscore}_ary#{'&.values&.flatten' unless sequence[:delayed_sequence]}&.any? do |resource|
                slice_found = find_slice(resource, slice[:path], slice[:discriminator])
                slice_found.present?
              end
            end
          )
        end

        if sequence[:must_supports][:elements].present?
          test[:test_code] += %(
            missing_must_support_elements = must_supports[:elements].reject do |element|
              #{resource_array}&.any? do |resource|
                value_found = resolve_element_from_path(resource, element[:path]) do |value|
                  value_without_extensions = value.respond_to?(:to_hash) ? value.to_hash.reject { |key, _| key == 'extension' } : value
                  value_without_extensions.present? && (element[:fixed_value].blank? || value == element[:fixed_value])
                end

                value_found.present?
              end
            end
            missing_must_support_elements.map! { |must_support| "\#{must_support[:path]}\#{': ' + must_support[:fixed_value] if must_support[:fixed_value].present?}" }
          )

          if must_support_extensions.present?
            test[:test_code] += %(
              missing_must_support_elements += missing_must_support_extensions.map { |must_support| must_support[:id] }
            )
          end
          if must_support_slices.present?
            test[:test_code] += %(
              missing_must_support_elements += missing_slices.map { |slice| slice[:name] }
            )
          end

          test[:test_code] += %(
            skip_if missing_must_support_elements.present?,
              "Could not find \#{missing_must_support_elements.join(', ')} in the \#{#{resource_array}&.length} provided #{sequence[:resource]} resource(s)")
        end

        test[:test_code] += %(
          @instance.save!)

        sequence[:tests] << test

        sequence[:must_support_constants] = %(
          MUST_SUPPORTS = #{structure_to_string(sequence[:must_supports])}.freeze
        )
      end

      def structure_to_string(struct)
        if struct.is_a? Hash
          %({
            #{struct.map { |k, v| "#{k}: #{structure_to_string(v)}" }.join(",\n")}
          })
        elsif struct.is_a? Array
          %([
            #{struct.map { |el| structure_to_string(el) }.join(",\n")}
          ])
        elsif struct.is_a? String
          "'#{struct}'"
        else
          "''"
        end
      end

      def create_resource_profile_test(sequence)
        test_key = :validate_resources
        test = {
          tests_that: "#{sequence[:resource]} resources returned from previous search conform to the #{sequence[:profile_name]}.",
          key: test_key,
          index: sequence[:tests].length + 1,
          link: sequence[:profile],
          description: %(
            This test verifies resources returned from the first search conform to the [US Core #{sequence[:resource]} Profile](#{sequence[:profile]}).
            It verifies the presence of manditory elements and that elements with required bindgings contain appropriate values.
            CodeableConcept element bindings will fail if none of its codings have a code/system that is part of the bound ValueSet.
            Quantity, Coding, and code element bindings will fail if its code/system is not found in the valueset.
          )
        }
        profile_uri = validation_profile_uri(sequence)
        test[:test_code] = %(
          #{skip_if_not_found_code(sequence)}
          test_resources_against_profile('#{sequence[:resource]}'#{', ' + profile_uri if profile_uri}))

        if sequence[:required_concepts].present?
          concept_string = sequence[:required_concepts].map { |concept| "'#{concept}'" }.join(' and ')
          test[:description] += %(
            This test also checks that the following CodeableConcepts with
            required ValueSet bindings include a code rather than just text:
            #{concept_string}
          )

          test[:test_code] += %( do |resource|
              #{sequence[:required_concepts].inspect.tr('"', "'")}.flat_map do |path|
                concepts = resolve_path(resource, path)
                next if concepts.blank?

                code_present = concepts.any? { |concept| concept.coding.any? { |coding| coding.code.present? } }

                unless code_present # rubocop:disable Style/IfUnlessModifier
                  "The CodeableConcept at '\#{path}' is bound to a required ValueSet but does not contain any codes."
                end
              end.compact
            end
          )
        end

        bindings = sequence[:bindings]
          .select { |binding_def| ['required', 'extensible'].include? binding_def[:strength] }

        bindings.each do |binding|
          binding[:path].gsub!(/(?<!\w)class(?!\w)/, 'local_class')
        end
        resources_ary_str = sequence[:delayed_sequence] ? "@#{sequence[:resource].underscore}_ary" : "@#{sequence[:resource].underscore}_ary&.values&.flatten"
        if bindings.present?
          sequence[:bindings_constants] = "BINDINGS = #{structure_to_string(bindings)}.freeze"
          test[:test_code] += %(
            bindings = #{sequence[:class_name]}Definitions::BINDINGS
            invalid_binding_messages = []
            invalid_binding_resources = Set.new
            bindings.select { |binding_def| binding_def[:strength] == 'required' }.each do |binding_def|
              begin
                invalid_bindings = resources_with_invalid_binding(binding_def, #{resources_ary_str})
              rescue Inferno::Terminology::UnknownValueSetException => e
                warning do
                  assert false, e.message
                end
                invalid_bindings = []
              end
              invalid_bindings.each { |invalid| invalid_binding_resources << "\#{invalid[:resource]&.resourceType}/\#{invalid[:resource].id}" }
              invalid_binding_messages.concat(invalid_bindings.map{ |invalid| invalid_binding_message(invalid, binding_def)})

            end
            assert invalid_binding_messages.blank?, "\#{invalid_binding_messages.count} invalid required \#{'binding'.pluralize(invalid_binding_messages.count)}" \\
            " found in \#{invalid_binding_resources.count} \#{'resource'.pluralize(invalid_binding_resources.count)}: " \\
            "\#{invalid_binding_messages.join('. ')}"

            bindings.select { |binding_def| binding_def[:strength] == 'extensible' }.each do |binding_def|
              begin
                invalid_bindings = resources_with_invalid_binding(binding_def, #{resources_ary_str})
                binding_def_new = binding_def
                # If the valueset binding wasn't valid, check if the codes are in the stated codesystem
                if invalid_bindings.present?
                  invalid_bindings = resources_with_invalid_binding(binding_def.except(:system), #{resources_ary_str})
                  binding_def_new = binding_def.except(:system)
                end
              rescue Inferno::Terminology::UnknownValueSetException, Inferno::Terminology::ValueSet::UnknownCodeSystemException => e
                warning do
                  assert false, e.message
                end
                invalid_bindings = []
              end
              invalid_binding_messages.concat(invalid_bindings.map{ |invalid| invalid_binding_message(invalid, binding_def_new)})
            end
            warning do
              invalid_binding_messages.each do |error_message|
                assert false, error_message
              end
            end
          )
        end

        sequence[:tests] << test

        if sequence[:resource] == 'MedicationRequest'
          medication_test = {
            tests_that: 'Medication resources returned conform to US Core v3.1.0 profiles',
            key: :validate_medication_resources,
            index: sequence[:tests].length + 1,
            link: 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-medicationrequest',
            description: %(
              This test checks if the resources returned from prior searches conform to the US Core profiles.
              This includes checking for missing data elements and valueset verification.
            )
          }

          medication_test[:test_code] = %(
            medications_found = (@medications || []) + (@contained_medications || [])

            omit 'MedicationRequests did not reference any Medication resources.' if medications_found.blank?

            test_resource_collection('Medication', medications_found)
          )

          sequence[:tests] << medication_test
        end

        if sequence[:required_concepts].present? # rubocop:disable Style/GuardClause
          unit_test_generator.generate_resource_validation_test(
            test_key: test_key,
            resource_type: sequence[:resource],
            class_name: sequence[:class_name],
            sequence_name: sequence[:name],
            required_concepts: sequence[:required_concepts],
            profile_uri: profile_uri
          )
        end
      end

      def create_multiple_or_test(sequence)
        test = {
          tests_that: 'The server returns results when parameters use composite-or',
          index: sequence[:tests].length + 1,
          link: sequence[:profile],
          test_code: '',
          description: %(
            This test will check if the server is capable of returning results for composite search parameters.
            The test will look through the resources returned from the first search to identify two different values
            to use for the parameter being tested. If no two different values can be found, then the test is skipped.
            [FHIR Composite Search Guideline](https://www.hl7.org/fhir/search.html#combining)
          )
        }

        multiple_or_params = get_multiple_or_params(sequence)

        test[:description] += %(
          Parameters being tested: #{multiple_or_params.join(', ')}
        )
        multiple_or_params.each do |param|
          multiple_or_search = sequence[:searches].find { |search| (search[:names].include? param) && search[:expectation] == 'SHALL' }
          next if multiple_or_search.blank?

          second_val_var = "second_#{param}_val"
          resolve_el_str = "#{resolve_element_path(sequence[:search_param_descriptions][param.to_sym], sequence[:delayed_sequence])} { |el| get_value_for_search_param(el) != #{param_value_name(param)} }" # rubocop:disable Layout/LineLength
          search_params = get_search_params(multiple_or_search[:names], sequence)
          resolve_param_from_resource = search_params.include? 'get_value_for_search_param'
          test[:test_code] += %(
            #{skip_if_search_not_supported_code(sequence, multiple_or_search[:names])}
          )
          if resolve_param_from_resource
            test[:test_code] += %(
              resolved_one = false
            )
          end
          test[:test_code] += %(
            found_second_val = false
            patient_ids.each do |patient|
              #{search_params}
              #{second_val_var} = #{resolve_el_str}
              next if #{second_val_var}.nil?
              found_second_val = true
              #{param_value_name(param)} += ',' + get_value_for_search_param(#{second_val_var})
              reply = get_resource_by_params(versioned_resource_class('#{sequence[:resource]}'), search_params)
              validate_search_reply(versioned_resource_class('#{sequence[:resource]}'), reply, search_params)
              assert_response_ok(reply)
              resources_returned = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
              missing_values = #{param_value_name(param)}.split(',').reject do |val|
                resolve_element_from_path(resources_returned, '#{param}') { |val_found| val_found == val }
              end
              assert missing_values.blank?, "Could not find \#{missing_values.join(',')} values from #{param} in any of the resources returned"
            end
            skip 'Cannot find second value for #{param} to perform a multipleOr search' unless found_second_val
          )
        end
        sequence[:tests] << test if test[:test_code].present?
      end

      def get_multiple_or_params(sequence)
        sequence[:search_param_descriptions]
          .select { |_param, description| description[:multiple_or] == 'SHALL' }
          .map { |param, _description| param.to_s }
      end

      def create_references_resolved_test(sequence)
        test = {
          tests_that: "Every reference within #{sequence[:resource]} resources can be read.",
          index: sequence[:tests].length + 1,
          link: 'http://hl7.org/fhir/references.html',
          description: %(
            This test will attempt to read the first 50 reference found in the resources from the first search.
            The test will fail if Inferno fails to read any of those references.
          )
        }

        resource_array = sequence[:delayed_sequence] ? "@#{sequence[:resource].underscore}_ary" : "@#{sequence[:resource].underscore}_ary&.values&.flatten"
        test[:test_code] = %(
              skip_if_known_not_supported(:#{sequence[:resource]}, [:search, :read])
              #{skip_if_not_found_code(sequence)}

              validated_resources = Set.new
              max_resolutions = 50

              #{resource_array}&.each do |resource|
                validate_reference_resolutions(resource, validated_resources, max_resolutions) if validated_resources.length < max_resolutions
              end)
        sequence[:tests] << test
      end

      def resolve_element_path(search_param_description, delayed_sequence)
        element_path = search_param_description[:path].gsub(/(?<!\w)class(?!\w)/, 'local_class')
        path_parts = element_path.split('.')
        resource_val = delayed_sequence ? "@#{path_parts.shift.underscore}_ary" : "@#{path_parts.shift.underscore}_ary[patient]"
        "resolve_element_from_path(#{resource_val}, '#{path_parts.join('.')}')"
      end

      def get_value_path_by_type(type)
        case type
        when 'CodeableConcept'
          '.coding.code'
        when 'Reference'
          '.reference'
        when 'Period'
          '.start'
        when 'Identifier'
          '.value'
        when 'Coding'
          '.code'
        when 'HumanName'
          '.family'
        when 'Address'
          '.city'
        else
          ''
        end
      end

      def param_value_name(param)
        param_key = param.include?('-') ? "'#{param}'" : param
        "search_params[:#{param_key}]"
      end

      def get_first_search(search_parameters, sequence)
        save_resource_references_arguments = [
          "versioned_resource_class('#{sequence[:resource]}')",
          "@#{sequence[:resource].underscore}_ary#{'[patient]' unless sequence[:delayed_sequence]}",
          validation_profile_uri(sequence)
        ].compact.join(', ')

        if fixed_value_search?(search_parameters, sequence)
          get_first_search_with_fixed_values(sequence, search_parameters, save_resource_references_arguments)
        else
          get_first_search_by_patient(sequence, search_parameters, save_resource_references_arguments)
        end
      end

      def fixed_value_search?(search_parameters, sequence)
        search_parameters != ['patient'] &&
          !sequence[:delayed_sequence] &&
          !search_param_constants(search_parameters, sequence)
      end

      def get_first_search_by_patient(sequence, search_parameters, save_resource_references_arguments)
        if sequence[:delayed_sequence]
          %(
            #{skip_if_search_not_supported_code(sequence, search_parameters)}
            #{get_search_params(search_parameters, sequence)}
            reply = get_resource_by_params(versioned_resource_class('#{sequence[:resource]}'), search_params)
            #{status_search_code(sequence, search_parameters)}
            assert_response_ok(reply)
            assert_bundle_response(reply)

            @resources_found = reply&.resource&.entry&.any? { |entry| entry&.resource&.resourceType == '#{sequence[:resource]}' }
            #{skip_if_not_found_code(sequence)}
            search_result_resources = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
            @#{sequence[:resource].underscore}_ary += search_result_resources
            @#{sequence[:resource].underscore} = @#{sequence[:resource].underscore}_ary
              .find { |resource| resource.resourceType == '#{sequence[:resource]}' }

            save_resource_references(#{save_resource_references_arguments})
            save_delayed_sequence_references(@#{sequence[:resource].underscore}_ary, #{sequence[:class_name]}Definitions::DELAYED_REFERENCES)
            validate_reply_entries(search_result_resources, search_params)
          )
        else
          first_search = %(
            #{skip_if_search_not_supported_code(sequence, search_parameters)}
            @#{sequence[:resource].underscore}_ary = {}
            patient_ids.each do |patient|
              #{get_search_params(search_parameters, sequence)}
              reply = get_resource_by_params(versioned_resource_class('#{sequence[:resource]}'), search_params)
              #{status_search_code(sequence, search_parameters)}
              assert_response_ok(reply)
              assert_bundle_response(reply)

              any_resources = reply&.resource&.entry&.any? { |entry| entry&.resource&.resourceType == '#{sequence[:resource]}' }

              next unless any_resources

              @#{sequence[:resource].underscore}_ary[patient] = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
          )

          if sequence[:resource] == 'Device'
            first_search += %(
              @device_ary[patient], non_implantable_devices = @device_ary[patient].partition do |resource|
                device_codes = @instance&.device_codes&.split(',')&.map(&:strip)
                device_codes.blank? || resource&.type&.coding&.any? do |coding|
                  device_codes.include?(coding.code)
                end
              end
              validate_reply_entries(non_implantable_devices, search_params)
              if  @#{sequence[:resource].underscore}_ary[patient].blank? && reply&.resource&.entry&.present?
                @skip_if_not_found_message = "No Devices of the specified type (\#{@instance&.device_codes}) were found"
              end
            )
          end

          search_with_reference_types = %(
            search_params = search_params.merge('patient': "Patient/\#{patient}")
            reply = get_resource_by_params(versioned_resource_class('#{sequence[:resource]}'), search_params)
            assert_response_ok(reply)
            assert_bundle_response(reply)
            search_with_type = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
            assert search_with_type.length == @#{sequence[:resource].underscore}_ary[patient].length, 'Expected search by Patient/ID to have the same results as search by ID'
          )

          first_search + %(
              @#{sequence[:resource].underscore} = @#{sequence[:resource].underscore}_ary[patient]
                .find { |resource| resource.resourceType == '#{sequence[:resource]}' }
              @resources_found = @#{sequence[:resource].underscore}.present?

              save_resource_references(#{save_resource_references_arguments})
              save_delayed_sequence_references(@#{sequence[:resource].underscore}_ary[patient], #{sequence[:class_name]}Definitions::DELAYED_REFERENCES)
              validate_reply_entries(@#{sequence[:resource].underscore}_ary[patient], search_params)
              #{search_with_reference_types unless sequence[:resource] == 'Patient'}
            end

            #{skip_if_not_found_code(sequence)}
          )
        end
      end

      def fixed_value_search_param(search_parameters, sequence)
        name = search_parameters.find { |param| param != 'patient' }
        search_description = sequence[:search_param_descriptions][name.to_sym]
        values = search_description[:values]
        path =
          search_description[:path]
            .split('.')
            .drop(1)
            .map { |path_part| path_part == 'class' ? 'local_class' : path_part }
            .join('.')
        path += get_value_path_by_type(search_description[:type])

        {
          name: name,
          path: path,
          values: values
        }
      end

      def get_first_search_with_fixed_values(sequence, search_parameters, save_resource_references_arguments)
        # assume only patient + one other parameter
        search_param = fixed_value_search_param(search_parameters, sequence)
        find_two_values = get_multiple_or_params(sequence).include? search_param[:name]
        values_variable_name = "#{search_param[:name].tr('-', '_')}_val"
        %(
          #{skip_if_search_not_supported_code(sequence, search_parameters)}
          @#{sequence[:resource].underscore}_ary = {}
          @resources_found = false
          #{'values_found = 0' if find_two_values}
          #{values_variable_name} = [#{search_param[:values].map { |val| "'#{val}'" }.join(', ')}]
          patient_ids.each do |patient|
            @#{sequence[:resource].underscore}_ary[patient] = []
            #{values_variable_name}.each do |val|
              search_params = { 'patient': patient, '#{search_param[:name]}': val }
              reply = get_resource_by_params(versioned_resource_class('#{sequence[:resource]}'), search_params)
              #{status_search_code(sequence, search_parameters)}
              assert_response_ok(reply)
              assert_bundle_response(reply)

              next unless reply&.resource&.entry&.any? { |entry| entry&.resource&.resourceType == '#{sequence[:resource]}' }

              @resources_found = true
              resources_returned = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
              @#{sequence[:resource].underscore} = resources_returned.first
              @#{sequence[:resource].underscore}_ary[patient] += resources_returned
              #{'values_found += 1' if find_two_values}

              save_resource_references(#{save_resource_references_arguments})
              save_delayed_sequence_references(resources_returned, #{sequence[:class_name]}Definitions::DELAYED_REFERENCES)
              validate_reply_entries(resources_returned, search_params)
              #{get_token_system_search_code(search_parameters, sequence)}

              search_params_with_type = search_params.merge('patient': "Patient/\#{patient}")
              reply = get_resource_by_params(versioned_resource_class('#{sequence[:resource]}'), search_params_with_type)
              #{status_search_code(sequence, search_parameters)}
              assert_response_ok(reply)
              assert_bundle_response(reply)
              search_with_type = fetch_all_bundled_resources(reply, check_for_data_absent_reasons)
              assert search_with_type.length == resources_returned.length, 'Expected search by Patient/ID to have the same results as search by ID'

              #{'test_medication_inclusion(@medication_request_ary[patient], search_params)' if sequence[:resource] == 'MedicationRequest'}
              break#{' if values_found == 2' if find_two_values}
            end
          end
          #{skip_if_not_found_code(sequence)})
      end

      def get_search_params(search_parameters, sequence, grab_first_value = false)
        search_params = get_search_param_hash(search_parameters, sequence, grab_first_value)
        search_param_string = %(
          search_params = {
            #{search_params.map { |param, value| search_param_to_string(param, value) }.join(",\n")}
          }
        )

        if search_param_string.include? 'get_value_for_search_param'
          search_param_value_check = if sequence[:delayed_sequence]
                                       "search_params.each { |param, value| skip \"Could not resolve \#{param} in any resource.\" if value.nil? }"
                                     else %(
                                        next if search_params.any? { |_param, value| value.nil? }

                                        resolved_one = true
                                      )
                                     end
          search_param_string = %(
            #{search_param_string}
            #{search_param_value_check}
            )
        end

        search_param_string
      end

      def search_param_to_string(param, value)
        value_string = "'#{value}'" unless value.start_with?('@', 'get_value_for_search_param', 'patient')
        "'#{param}': #{value_string || value}"
      end

      def get_search_param_hash(search_parameters, sequence, grab_first_value = false)
        search_params = search_param_constants(search_parameters, sequence)
        return search_params if search_params.present?

        search_parameters.each_with_object({}) do |param, params|
          search_param_description = sequence[:search_param_descriptions][param.to_sym]
          params[param] =
            if param == 'patient'
              'patient'
            elsif grab_first_value && !sequence[:delayed_sequence]
              search_param_description[:values].first
            else
              "get_value_for_search_param(#{resolve_element_path(search_param_description, sequence[:delayed_sequence])} { |el| get_value_for_search_param(el).present? })"
            end
        end
      end

      def get_token_param(search_params, sequence)
        search_params.find { |param| ['Identifier', 'CodeableConcept', 'Coding'].include? sequence[:search_param_descriptions][param.to_sym][:type] }
      end

      def get_token_system_search_code(search_params, sequence)
        token_param = search_params.find { |param| ['Identifier', 'CodeableConcept', 'Coding'].include? sequence[:search_param_descriptions][param.to_sym][:type] }
        return unless token_param

        param_description = sequence[:search_param_descriptions][token_param.to_sym]
        %(
          value_with_system = get_value_for_search_param(#{resolve_element_path(param_description, sequence[:delayed_sequence])}, true)
          token_with_system_search_params = search_params.merge('#{token_param}': value_with_system)
          reply = get_resource_by_params(versioned_resource_class('#{sequence[:resource]}'), token_with_system_search_params)
          validate_search_reply(versioned_resource_class('#{sequence[:resource]}'), reply, token_with_system_search_params)
        )
      end

      def get_comparator_searches(search_params, sequence)
        search_code = ''
        param_comparators = find_comparators(search_params, sequence)
        param_comparators.each do |param, comparators|
          param_info = sequence[:search_param_descriptions][param.to_sym]
          get_element_string = "#{resolve_element_path(param_info, sequence[:delayed_sequence])} { |el| get_value_for_search_param(el).present? }"
          type = param_info[:type]
          case type
          when 'Period', 'date'
            search_code += %(\n
              [#{comparators.keys.map { |comparator| "'#{comparator}'" }.join(', ')}].each do |comparator|
                comparator_val = date_comparator_value(comparator, #{get_element_string})
                comparator_search_params = search_params.merge('#{param}': comparator_val)
                reply = get_resource_by_params(versioned_resource_class('#{sequence[:resource]}'), comparator_search_params)
                validate_search_reply(versioned_resource_class('#{sequence[:resource]}'), reply, comparator_search_params)
              end)
          end
        end
        search_code
      end

      def find_comparators(search_params, sequence)
        search_params.each_with_object({}) do |param, param_comparators|
          param_info = sequence[:search_param_descriptions][param.to_sym]
          comparators = param_info[:comparators].select { |_comparator, expectation| ['SHALL', 'SHOULD'].include? expectation }
          param_comparators[param] = comparators if comparators.present?
        end
      end

      def skip_if_not_found_code(sequence)
        "skip_if_not_found(resource_type: '#{sequence[:resource]}', delayed: #{sequence[:delayed_sequence]})"
      end

      def skip_if_could_not_resolve(params)
        "skip 'Could not resolve all parameters (#{params.join(', ')}) in any resource.' unless resolved_one"
      end

      def search_param_constants(search_parameters, sequence)
        return { '_id': 'patient' } if search_parameters == ['_id'] && sequence[:resource] == 'Patient'
      end

      def create_search_validation(sequence)
        search_validators = ''
        sequence[:search_param_descriptions].each do |element, definition|
          type = definition[:type]
          path = definition[:path]
            .gsub(/(?<!\w)class(?!\w)/, 'local_class')
            .split('.')
            .drop(1)
            .join('.')
          path += get_value_path_by_type(type) unless ['Period', 'date', 'HumanName', 'Address', 'CodeableConcept', 'Coding', 'Identifier'].include? type
          search_validators += %(
              when '#{element}'
              values_found = resolve_path(resource, '#{path}')
              #{search_param_match_found_code(type, element)}
              assert match_found, "#{element} in #{sequence[:resource]}/\#{resource.id} (\#{values_found}) does not match #{element} requested (\#{value})"
            )
        end

        validate_functions =
          if search_validators.empty?
            ''
          else
            %(
              def validate_resource_item(resource, property, value)
                case property
        #{search_validators}
                end
              end
            )
          end

        validate_functions += test_medication_inclusion_code if sequence[:resource] == 'MedicationRequest'
        validate_functions += perform_search_with_status_code(sequence) if sequence_has_status_search?(sequence)

        validate_functions
      end

      def search_param_match_found_code(type, element)
        case type
        when 'Period', 'date'
          %(match_found = values_found.any? { |date| validate_date_search(value, date) })
        when 'HumanName'
          # When a string search parameter refers to the types HumanName and Address,
          # the search covers the elements of type string, and does not cover elements such as use and period
          # https://www.hl7.org/fhir/search.html#string
          %(value_downcase = value.downcase
            match_found = values_found.any? do |name|
              name&.text&.downcase&.start_with?(value_downcase) ||
                name&.family&.downcase&.include?(value_downcase) ||
                name&.given&.any? { |given| given.downcase.start_with?(value_downcase) } ||
                name&.prefix&.any? { |prefix| prefix.downcase.start_with?(value_downcase) } ||
                name&.suffix&.any? { |suffix| suffix.downcase.start_with?(value_downcase) }
            end)
        when 'Address'
          %(match_found = values_found.any? do |address|
              address&.text&.start_with?(value) ||
              address&.city&.start_with?(value) ||
              address&.state&.start_with?(value) ||
              address&.postalCode&.start_with?(value) ||
              address&.country&.start_with?(value)
            end)
        when 'CodeableConcept'
          %(coding_system = value.split('|').first.empty? ? nil : value.split('|').first
            coding_value = value.split('|').last
            match_found = values_found.any? do |codeable_concept|
              if value.include? '|'
                codeable_concept.coding.any? { |coding| coding.system == coding_system && coding.code == coding_value }
              else
                codeable_concept.coding.any? { |coding| coding.code == value }
              end
            end)
        when 'Identifier'
          %(identifier_system = value.split('|').first.empty? ? nil : value.split('|').first
            identifier_value = value.split('|').last
            match_found = values_found.any? do |identifier|
              identifier.value == identifier_value && (!value.include?('|') || identifier.system == identifier_system)
            end)
        else
          # searching by patient requires special case because we are searching by a resource identifier
          # references can also be URL's, so we made need to resolve those url's
          if ['subject', 'patient'].include? element.to_s
            %(value = value.split('Patient/').last
              match_found = values_found.any? { |reference| [value, 'Patient/' + value, "\#{@instance.url}/Patient/\#{value}"].include? reference })
          else
            %(values = value.split(/(?<!\\\\),/).each { |str| str.gsub!('\\,', ',') }
              match_found = values_found.any? { |value_in_resource| values.include? value_in_resource })
          end
        end
      end

      def test_medication_inclusion_code
        %(
          def test_medication_inclusion(medication_requests, search_params)
            @medications ||= []
            @contained_medications ||= []

            requests_with_external_references =
              medication_requests
                .select { |request| request&.medicationReference&.present? }
                .reject { |request| request&.medicationReference&.reference&.start_with? '#' }

            @contained_medications +=
              medication_requests
                .select { |request| request&.medicationReference&.reference&.start_with? '#' }
                .flat_map(&:contained)
                .select { |resource| resource.resourceType == 'Medication' }

            return if requests_with_external_references.blank?

            search_params.merge!(_include: 'MedicationRequest:medication')
            response = get_resource_by_params(FHIR::MedicationRequest, search_params)
            assert_response_ok(response)
            assert_bundle_response(response)
            requests_with_medications = fetch_all_bundled_resources(response, check_for_data_absent_reasons)

            medications = requests_with_medications.select { |resource| resource.resourceType == 'Medication' }
            assert medications.present?, 'No Medications were included in the search results'

            @medications += medications
            @medications.uniq!(&:id)
          end
        )
      end

      def generate_verify_access_module(module_info)
        module_info[:access_verify_param_map] = {
          patient: 'patient',
          careplan_category: 'assess-plan',
          careteam_status: 'active',
          diagnosticreport_category: 'LAB',
          observation_code: '2708-6',
          medicationrequest_intent: 'order'

        }

        module_info[:access_verify_status_codes] = {
          allergyintolerance: { 'clinical-status' => 'active' },
          careplan: { 'status' => 'active' },
          careteam: { 'status' => 'active' },
          condition: { 'clinical-status' => 'active' },
          diagnosticreport: { 'status' => 'final' },
          documentreference: { 'status' => 'current' },
          encounter: { 'status' => 'finished' },
          goal: { 'status' => 'active' },
          immunization: { 'status' => 'completed' },
          medicationrequest: { 'status' => 'active' },
          observation: { 'status' => 'final' },
          procedure: { 'status' => 'completed' },
          smokingstatus: { 'status' => 'final' }
        }

        ['restricted', 'unrestricted'].each do |restriction|
          file_name = "#{sequence_out_path}/access_verify_#{restriction}_sequence.rb"

          template = ERB.new(File.read(File.join(__dir__, 'templates/access_verify_sequence.rb.erb')))

          module_info[:access_verify_restriction] = restriction
          output = template.result_with_hash(module_info)
          FileUtils.mkdir_p(sequence_out_path) unless File.directory?(sequence_out_path)
          File.write(file_name, output)
        end
      end

      def generate_module(module_info)
        file_name = "#{module_yml_out_path}/#{@path}_module.yml"

        template = ERB.new(File.read(File.join(__dir__, 'templates/module.yml.erb')))
        output = template.result_with_hash(module_info)

        File.write(file_name, output)
      end
    end
  end
end
