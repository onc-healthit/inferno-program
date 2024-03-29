# frozen_string_literal: true

require_relative '../ext/bloomer'
require_relative 'valueset'
require 'bloomer'
require 'bloomer/msgpackable'
require_relative 'fhir_package_manager'
require_relative 'terminology_configuration'
require 'fileutils'

module Inferno
  class Terminology
    SKIP_SYS = [
      'http://hl7.org/fhir/ValueSet/message-events', # has 0 codes
      'http://hl7.org/fhir/ValueSet/care-team-category', # has 0 codes
      'http://hl7.org/fhir/ValueSet/action-participant-role', # has 0 codes
      'http://hl7.org/fhir/ValueSet/example-filter', # has fake property acme-plasma
      'http://hl7.org/fhir/ValueSet/all-distance-units', # UCUM filter "canonical"
      'http://hl7.org/fhir/ValueSet/all-time-units', # UCUM filter "canonical"
      'http://hl7.org/fhir/ValueSet/example-intensional', # Unhandled filter parent =
      'http://hl7.org/fhir/ValueSet/use-context', # ValueSet contains an unknown ValueSet
      'http://hl7.org/fhir/ValueSet/media-modality', # ValueSet contains an unknown ValueSet
      'http://hl7.org/fhir/ValueSet/example-hierarchical' # Example valueset with fake codes
    ].freeze

    # Code systems to "preprocess" prior to validation, and the function to use
    PREPROCESS_FUNCS = {
      'urn:ietf:bcp:13' => Inferno::Terminology::BCP13.method(:preprocess_code)
    }.freeze

    PACKAGE_DIR = File.join('tmp', 'terminology', 'fhir')

    @known_valuesets = {}
    @valueset_ids = nil
    @loaded_code_systems = nil

    @loaded_validators = {}
    @missing_validators = nil
    class << self; attr_reader :loaded_validators, :known_valuesets; end

    def self.load_fhir_r4
      FileUtils.mkdir_p PACKAGE_DIR
      FHIRPackageManager.get_package('hl7.fhir.r4.core#4.0.1', PACKAGE_DIR, ['ValueSet', 'CodeSystem'])
    end

    def self.load_us_core
      FileUtils.mkdir_p PACKAGE_DIR
      FHIRPackageManager.get_package('hl7.fhir.us.core#3.1.1', PACKAGE_DIR, ['ValueSet', 'CodeSystem'])
    end

    def self.load_fhir_expansions
      FileUtils.mkdir_p PACKAGE_DIR
      FHIRPackageManager.get_package('hl7.fhir.r4.expansions#4.0.1', PACKAGE_DIR, ['ValueSet', 'CodeSystem'])
    end

    def self.code_system_metadata
      @code_system_metadata ||=
        if File.file? File.join('resources', 'terminology', 'validators', 'bloom', 'metadata.yml')
          YAML.load_file(File.join('resources', 'terminology', 'validators', 'bloom', 'metadata.yml'))
        else
          {}
        end
    end

    def self.load_valuesets_from_directory(directory, include_subdirectories = false)
      directory += '/**/' if include_subdirectories
      valueset_files = Dir["#{directory}/*.json"]
      valueset_files.each do |vs_file|
        next unless JSON.parse(File.read(vs_file))['resourceType'] == 'ValueSet'

        add_valueset_from_file(vs_file)
      end
    end

    # Creates the valueset validators, based on the passed in parameters and the @known_valuesets hash
    # @param type [Symbol] the type of validators to create, either :bloom or :csv
    # @param selected_module [Symbol]/[String], the name of the module to build validators for, or :all (default)
    # @param [String] minimum_binding_strength the lowest binding strength for which we should build validators
    # @param [Boolean] include_umls a flag to determine if we should build validators that require UMLS
    # @param [Boolean] delete_existing a flag to determine whether any existing validators of `type` should be
    # deleted before the creation tasks run. Default to `true`. If `false`, the existing validators will
    # be read in and combined with the validators created in this step.
    def self.create_validators(type: :bloom, selected_module: :all, minimum_binding_strength: 'example', include_umls: true, delete_existing: true)
      strengths = ['example', 'preferred', 'extensible', 'required'].drop_while { |s| s != minimum_binding_strength }
      umls_code_systems = Set.new(Inferno::Terminology::ValueSet::SAB.keys)
      root_dir = "resources/terminology/validators/#{type}"

      FileUtils.rm_r(root_dir, force: true) if delete_existing
      FileUtils.mkdir_p(root_dir)

      vs_validators = get_module_valuesets(selected_module, strengths).map do |k, vs|
        next if SKIP_SYS.include? k
        next if !include_umls && !umls_code_systems.disjoint?(Set.new(vs.included_code_systems))

        Inferno.logger.debug "Processing #{k}"
        filename = "#{root_dir}/#{(URI(vs.url).host + URI(vs.url).path).gsub(%r{[./]}, '_')}"
        begin
          # Save the validator to file, and get the "new" count of number of codes
          new_count = save_to_file(vs.valueset, filename, type)
          {
            url: k,
            file: name_by_type(File.basename(filename), type),
            count: new_count,
            type: type.to_s,
            code_systems: vs.included_code_systems
          }
        rescue ValueSet::UnknownCodeSystemException, ValueSet::FilterOperationException, UnknownValueSetException, URI::InvalidURIError => e
          Inferno.logger.warn "#{e.message} for ValueSet: #{k}"
          next
        end
      end
      vs_validators.compact!

      code_systems = vs_validators.flat_map { |vs| vs[:code_systems] }.uniq
      vs = Inferno::Terminology::ValueSet.new(@db)

      cs_validators = code_systems.map do |cs_name|
        next if SKIP_SYS.include? cs_name
        next if !include_umls && umls_code_systems.include?(cs_name)

        Inferno.logger.debug "Processing #{cs_name}"
        begin
          cs = vs.code_system_set(cs_name)
          filename = "#{root_dir}/#{bloom_file_name(cs_name)}"
          new_count = save_to_file(cs, filename, type)
          {
            url: cs_name,
            file: name_by_type(File.basename(filename), type),
            count: new_count,
            type: type.to_s,
            code_systems: cs_name
          }
        rescue ValueSet::UnknownCodeSystemException, ValueSet::FilterOperationException, UnknownValueSetException, URI::InvalidURIError => e
          Inferno.logger.warn "#{e.message} for CodeSystem #{cs_name}"
          next
        end
      end
      validators = (vs_validators + cs_validators).compact

      # Write manifest for loading later
      File.write("#{root_dir}/manifest.yml", validators.to_yaml)

      create_code_system_metadata(cs_validators.map { |validator| validator[:url] }, root_dir)
    end

    def self.create_code_system_metadata(system_urls, root_dir)
      vs = ValueSet.new(@db)
      metadata_path = "#{root_dir}/metadata.yml"
      metadata =
        if File.file? metadata_path
          YAML.load_file(metadata_path)
        else
          {}
        end
      system_urls.each do |url|
        abbreviation = vs.umls_abbreviation(url)
        next if abbreviation.nil?

        versions = @db.execute("SELECT SVER FROM mrsab WHERE RSAB='#{abbreviation}' AND SABIN='Y'").flatten
        restriction_level = @db.execute("SELECT SRL FROM mrsab WHERE RSAB='#{abbreviation}' AND SABIN='Y'").flatten.first
        system_metadata = metadata[url] || vs.code_system_metadata(url).dup || {}
        system_metadata[:versions] ||= []
        system_metadata[:versions].concat(versions).uniq!
        system_metadata[:restriction_level] = restriction_level

        metadata[url] = system_metadata
      end

      File.write(metadata_path, metadata.to_yaml)
    end

    def self.get_module_valuesets(selected_module, strengths)
      if selected_module == :all
        @known_valuesets
      else
        # get the list of unique value set URL strings where the corresponding
        # strength attribute is in the strengths array from above
        module_vs_urls = Inferno::Module.get(selected_module)
          .value_sets
          .keep_if { |vs| strengths.include? vs[:strength] }
          .collect { |vs| vs[:value_set_url] }
          .compact
          .uniq
        module_valuesets = @known_valuesets.keep_if { |key, _| module_vs_urls.include?(key) }
        # Throw an error message for each missing valueset
        # But don't halt the rake task
        (module_vs_urls - module_valuesets.keys).each do |missing_vs_url|
          Inferno.logger.error "Inferno doesn't know about valueset #{missing_vs_url} for module #{selected_module}"
        end
        module_valuesets
      end
    end

    # Chooses which filetype to save the validator as, based on the type variable passed in
    def self.save_to_file(codeset, filename, type)
      case type
      when :bloom
        save_bloom_to_file(codeset, name_by_type(filename, type))
      when :csv
        save_csv_to_file(codeset, name_by_type(filename, type))
      else
        raise 'Unknown Validator Type!'
      end
    end

    def self.name_by_type(filename, type)
      case type
      when :bloom
        "#{filename}.msgpack"
      when :csv
        "#{filename}.csv"
      else
        raise 'Unknown Validator Type!'
      end
    end

    # Saves the valueset bloomfilter to a msgpack file
    #
    # @param [String] filename the name of the file
    def self.save_bloom_to_file(codeset, filename)
      # If the file already exists, load it in
      bf = if File.file? filename
             Bloomer::Scalable.from_msgpack(File.read(filename))
           else
             Bloomer::Scalable.create_with_sufficient_size(codeset.length)
           end
      codeset.each do |cc|
        bf.add_without_duplication("#{cc[:system]}|#{cc[:code]}")
      end
      bloom_file = File.new(filename, 'wb')
      bloom_file.write(bf.to_msgpack) unless bf.nil?
      # return the accumulated count of the bloom filter
      bf.count
    end

    # Saves the valueset to a csv
    # @param [String] filename the name of the file
    def self.save_csv_to_file(codeset, filename)
      csv_set = Set.new
      # If the file already exists, add it to the Set
      if File.file? filename
        CSV.read(filename).each do |code_array|
          csv_set.add({ code: code_array[1], system: code_array[0] })
        end
      end
      codeset.merge csv_set

      count = 0
      CSV.open(filename, 'wb') do |csv|
        codeset.each do |code|
          csv << [code[:system], code[:code]]
          count += 1
        end
      end
      count
    end

    def self.register_umls_db(database)
      @db = SQLite3::Database.new database
    end

    def self.add_valueset_from_file(vs_file)
      vs = Inferno::Terminology::ValueSet.new(@db)
      vs.read_valueset(vs_file)
      vs.vsa = self
      @known_valuesets[vs.url] = vs
      vs
    end

    # Load the validators into FHIR::Models
    def self.load_validators(directory = 'resources/terminology/validators/bloom')
      manifest_file = "#{directory}/manifest.yml"
      return unless File.file? manifest_file

      validators = YAML.load_file("#{directory}/manifest.yml")
      validators.each do |validator|
        bfilter = Bloomer::Scalable.from_msgpack(File.open("#{directory}/#{validator[:file]}").read)
        validate_fn = lambda do |coding|
          probe = "#{coding['system']}|#{coding['code']}"
          bfilter.include? probe
        end
        # Register the validators with FHIR Models for validation
        FHIR::DSTU2::StructureDefinition.validates_vs(validator[:url], &validate_fn)
        FHIR::StructureDefinition.validates_vs(validator[:url], &validate_fn)
        @loaded_validators[validator[:url]] = validator
      end
    end

    # Returns the ValueSet with the provided URL
    #
    # @param [String] url the url of the desired valueset
    # @return [Inferno::Terminology::ValueSet] ValueSet
    def self.get_valueset(url)
      @known_valuesets[url] || raise(UnknownValueSetException, url)
    end

    def self.bloom_file_name(codesystem)
      system = codesystem.tr('|', '_')
      uri = URI(system)
      return (uri.host + uri.path).gsub(%r{[./]}, '_') if uri.host && uri.port

      system.gsub(/\W/, '_')
    end

    def self.missing_validators
      return @missing_validators if @missing_validators

      required_valuesets = Inferno::Module.get('uscore_v3.1.1').value_sets.reject { |vs| vs[:strength] == 'example' }.collect { |vs| vs[:value_set_url] }
      @missing_validators = required_valuesets.compact - Inferno::Terminology.loaded_validators.keys.compact
    end

    # This function accepts a valueset URL, code, and optional system, and returns true
    # if the code or code/system combination is valid for the valueset
    # represented by that URL
    #
    # @param String valueset_url the URL for the valueset to validate against
    # @param String code the code to validate against the valueset
    # @param String system an optional codesystem to validate against. Defaults to nil
    # @return Boolean whether the code or code/system is in the valueset
    def self.validate_code(valueset_url: nil, code:, system: nil)
      raise(ProhibitedSystemException, system) if TerminologyConfiguration.system_prohibited? system

      # Before we validate the code, see if there's any preprocessing steps we have to do
      # To get the code "ready" for validation
      code = PREPROCESS_FUNCS[system].call(code) if PREPROCESS_FUNCS[system]

      # Get the valueset from the url. Redundant if the 'system' is not nil,
      # but allows us to throw a better error if the valueset isn't known by Inferno
      if valueset_url
        validation_fn = FHIR::StructureDefinition.vs_validators[valueset_url]
        raise(UnknownValueSetException, valueset_url) unless validation_fn
      else
        validation_fn = FHIR::StructureDefinition.vs_validators[system]
        raise(Inferno::Terminology::ValueSet::UnknownCodeSystemException, system) unless validation_fn
      end

      if system
        validation_fn.call('code' => code, 'system' => system)
      else
        in_allowed_code_system =
          @loaded_validators[valueset_url][:code_systems].any? do |possible_system|
            next if TerminologyConfiguration.system_prohibited?(possible_system)

            validation_fn.call('code' => code, 'system' => possible_system)
          end

        unless in_allowed_code_system
          prohibited_systems =
            @loaded_validators[valueset_url][:code_systems].select do |system|
              TerminologyConfiguration.system_prohibited? system
            end
          raise(ProhibitedSystemException, prohibited_systems.join(', ')) if prohibited_systems.present?
        end

        in_allowed_code_system
      end
    end

    class UnknownValueSetException < StandardError
      def initialize(value_set)
        super("Unknown ValueSet: #{value_set}")
      end
    end
  end
end
