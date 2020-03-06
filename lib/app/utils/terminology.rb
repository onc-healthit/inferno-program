# frozen_string_literal: true

require_relative 'valueset'
require 'bloomer'
require 'bloomer/msgpackable'
require_relative 'fhir_package_manager'

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
      'http://hl7.org/fhir/ValueSet/media-modality' # ValueSet contains an unknown ValueSet
    ].freeze

    PACKAGE_DIR = File.join('tmp', 'terminology', 'fhir')

    @known_valuesets = {}
    @valueset_ids = nil
    @loaded_code_systems = nil

    @loaded_validators = {}
    @missing_validators = nil
    class << self; attr_reader :loaded_validators, :known_valuesets; end

    def self.load_fhir_r4
      mkdir_p PACKAGE_DIR
      FHIRPackageManager.get_package('hl7.fhir.r4.core#4.0.1', PACKAGE_DIR, ['ValueSet', 'CodeSystem'])
    end

    def self.load_us_core
      mkdir_p PACKAGE_DIR
      FHIRPackageManager.get_package('hl7.fhir.us.core#3.1.0', PACKAGE_DIR, ['ValueSet', 'CodeSystem'])
    end

    def self.load_fhir_expansions
      mkdir_p PACKAGE_DIR
      FHIRPackageManager.get_package('hl7.fhir.r4.expansions#4.0.1', PACKAGE_DIR, ['ValueSet', 'CodeSystem'])
    end

    def self.load_valuesets_from_directory(directory, include_subdirectories = false)
      directory += '/**/' if include_subdirectories
      valueset_files = Dir["#{directory}/*.json"]
      valueset_files.each do |vs_file|
        next unless JSON.parse(File.read(vs_file))['resourceType'] == 'ValueSet'

        add_valueset_from_file(vs_file)
      end
    end

    def self.create_validators(type)
      validators = []
      case type
      when :bloom
        root_dir = 'resources/terminology/validators/bloom'
        FileUtils.mkdir_p(root_dir)
        @known_valuesets.each do |k, vs|
          next if SKIP_SYS.include? k

          Inferno.logger.debug "Processing #{k}"
          filename = "#{root_dir}/#{(URI(vs.url).host + URI(vs.url).path).gsub(%r{[./]}, '_')}.msgpack"
          begin
            save_bloom_to_file(vs.valueset, filename)
            validators << { url: k, file: File.basename(filename), count: vs.count, type: 'bloom', code_systems: vs.included_code_systems }
          rescue Valueset::UnknownCodeSystemException => e
            Inferno.logger.debug "#{e.message} for ValueSet: #{k}"
            next
          rescue Valueset::FilterOperationException => e
            Inferno.logger.debug "#{e.message} for ValueSet: #{k}"
            next
          rescue UnknownValueSetException => e
            Inferno.logger.debug "#{e.message} for ValueSet: #{url}"
            next
          end
        end
        vs = Inferno::Terminology::Valueset.new(@db)
        Inferno::Terminology::Valueset::SAB.each do |k, _v|
          Inferno.logger.debug "Processing #{k}"
          cs = vs.code_system_set(k)
          filename = "#{root_dir}/#{bloom_file_name(k)}.msgpack"
          save_bloom_to_file(cs, filename)
          validators << { url: k, file: File.basename(filename), count: cs.length, type: 'bloom', code_systems: k }
        end
        # Write manifest for loading later
        File.write("#{root_dir}/manifest.yml", validators.to_yaml)
      when :csv
        root_dir = 'resources/terminology/validators/csv'
        FileUtils.mkdir_p(root_dir)
        @known_valuesets.each do |k, vs|
          next if (k == 'http://fhir.org/guides/argonaut/ValueSet/argo-codesystem') || (k == 'http://fhir.org/guides/argonaut/ValueSet/languages')

          Inferno.logger.debug "Processing #{k}"
          filename = "#{root_dir}/#{bloom_file_name(vs.url)}.csv"
          save_csv_to_file(vs.valueset, filename)
          validators << { url: k, file: File.basename(filename), count: vs.count, type: 'csv', code_systems: vs.included_code_systems }
        end
        vs = Inferno::Terminology::Valueset.new(@db)
        Inferno::Terminology::Valueset::SAB.each do |k, _v|
          Inferno.logger.debug "Processing #{k}"
          cs = vs.code_system_set(k)
          filename = "#{root_dir}/#{bloom_file_name(k)}.csv"
          save_csv_to_file(cs, filename)
          validators << { url: k, file: File.basename(filename), count: cs.length, type: 'csv', code_systems: k }
        end
        # Write manifest for loading later
        File.write("#{root_dir}/manifest.yml", validators.to_yaml)
      else
        raise 'Unknown Validator Type!'
      end
    end

    # Saves the valueset bloomfilter to a msgpack file
    #
    # @param [String] filename the name of the file
    def self.save_bloom_to_file(codeset, filename)
      bf = Bloomer::Scalable.new
      codeset.each do |cc|
        bf.add("#{cc[:system]}|#{cc[:code]}")
      end
      bloom_file = File.new(filename, 'wb')
      bloom_file.write(bf.to_msgpack) unless bf.nil?
    end

    # Saves the valueset to a csv
    # @param [String] filename the name of the file
    def self.save_csv_to_file(codeset, filename)
      CSV.open(filename, 'wb') do |csv|
        codeset.each do |code|
          csv << [code[:system], code[:code]]
        end
      end
    end

    def self.register_umls_db(database)
      @db = SQLite3::Database.new database
    end

    def self.add_valueset_from_file(vs_file)
      vs = Inferno::Terminology::Valueset.new(@db)
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

    def self.get_valueset_by_id(id)
      unless @valueset_ids
        @valueset_ids = {}
        @known_valuesets.each_pair do |k, v|
          @valueset_ids[v&.valueset_model&.id] = k
        end
      end
      @known_valuesets[@valueset_ids[id]] || raise(UnknownValueSetException, id)
    end

    def self.bloom_file_name(codesystem)
      uri = URI(codesystem)
      return (uri.host + uri.path).gsub(%r{[./]}, '_') if uri.host && uri.port

      codesystem.gsub(/[.\W]/, '_')
    end

    def self.loaded_code_systems
      @loaded_code_systems ||= @loaded_validators.flat_map do |_, vs|
        vs[:code_systems]
      end.uniq.compact
    end

    def self.missing_validators
      return @missing_validators if @missing_validators

      required_valuesets = Inferno::Module.get('uscore_v3.1.0').value_sets.reject { |vs| vs[:strength] == 'example' }.collect { |vs| vs[:value_set_url] }
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
    def self.validate_code(valueset_url, code, system = nil)
      # Get the valueset from the url. Redundant if the 'system' is not nil,
      # but allows us to throw a better error if the valueset isn't known by Inferno
      validation_fn = FHIR::StructureDefinition.vs_validators[valueset_url]
      raise(UnknownValueSetException, valueset_url) unless validation_fn

      if system
        validation_fn.call('code' => code, 'system' => system)
      else
        @loaded_validators[valueset_url][:code_systems].any? do |possible_system|
          validation_fn.call('code' => code, 'system' => possible_system)
        end
      end
    end

    class UnknownValueSetException < StandardError
      def initialize(value_set)
        super("Unknown ValueSet: #{value_set}")
      end
    end
  end
end
