# frozen_string_literal: true

require 'pry'
require 'pry-byebug'
require 'csv'
require 'colorize'
require 'nokogiri'
require 'rubocop/rake_task'

require_relative '../app'
require_relative '../app/models'

namespace :terminology do |_argv|
  TEMP_DIR = 'tmp/terminology'
  desc 'download and execute UMLS terminology data'
  task :download_umls, [:apikey, :version] do |_t, args|
    # Adapted from https://documentation.uts.nlm.nih.gov/automating-downloads.html

    args.with_defaults(version: '2019')
    versioned_temp_dir = File.join(TEMP_DIR, args.version)
    # URLs for the umls downloads, by year
    umls_file_urls = {
      '2019' => 'https://download.nlm.nih.gov/umls/kss/2019AB/umls-2019AB-full.zip',
      '2020' => 'https://download.nlm.nih.gov/umls/kss/2020AB/umls-2020AB-full.zip',
      '2021' => 'https://download.nlm.nih.gov/umls/kss/2021AA/umls-2021AA-full.zip'
    }
    # URL for the 'ticket-granting ticket' request link
    tgt_url = 'https://utslogin.nlm.nih.gov/cas/v1/api-key'

    FileUtils.mkdir_p(versioned_temp_dir)

    target_file = umls_file_urls[args.version]
    target_filename = 'umls.zip'

    puts 'Getting TGT'
    tgt_html = RestClient::Request.execute(method: :post,
                                           url: tgt_url,
                                           payload: {
                                             apikey: args.apikey
                                           })
    tgt = Nokogiri::HTML(tgt_html.body).at_css('form').attributes['action'].value

    puts 'Getting ticket'
    ticket = RestClient::Request.execute(method: :post,
                                         url: tgt,
                                         payload: {
                                           service: target_file
                                         }).body

    begin
      puts 'Downloading'
      RestClient::Request.execute(method: :get,
                                  url: "#{target_file}?ticket=#{ticket}",
                                  max_redirects: 0)
    rescue RestClient::ExceptionWithResponse => e
      ticket = RestClient::Request.execute(method: :post,
                                           url: tgt,
                                           payload: {
                                             service: e.response.headers[:location]
                                           }).body
      target_location = File.join(versioned_temp_dir, target_filename)
      follow_redirect(e.response.headers[:location], target_location, ticket, e.response.headers[:set_cookie])
    end
    puts 'Finished Downloading!'
  end

  def follow_redirect(location, file_location, ticket, cookie = nil)
    return unless location

    size = 0
    percent = 0
    current_percent = 0
    File.open(file_location, 'w') do |f|
      f.binmode
      block = proc do |response|
        puts response.header['content-type']
        if response.header['content-type'] == 'application/zip'
          total = response.header['content-length'].to_i
          response.read_body do |chunk|
            f.write chunk
            size += chunk.size
            percent = ((size * 100) / total).round unless total.zero?
            if current_percent != percent
              current_percent = percent
              puts "#{percent}% complete"
            end
          end
        else
          follow_redirect(response.header['location'], file_location, ticket, response.header['set-cookie'])
        end
      end
      RestClient::Request.execute(
        method: :get,
        url: "#{location}?ticket=#{ticket}",
        headers: { cookie: cookie },
        block_response: block
      )
    end
  end

  desc 'unzip umls zip'
  task :unzip_umls, [:version] do |_t, args|
    args.with_defaults(version: '2019')
    versioned_temp_dir = File.join(TEMP_DIR, args.version)
    destination = File.join(versioned_temp_dir, 'umls')
    umls_zip = File.join(versioned_temp_dir, 'umls.zip')

    # https://stackoverflow.com/questions/19754883/how-to-unzip-a-zip-file-containing-folders-and-files-in-rails-while-keeping-the
    Zip::File.open(umls_zip) do |zip_file|
      # Handle entries one by one
      zip_file.each do |entry|
        # Extract to file/directory/symlink
        puts "Extracting #{entry.name}"
        f_path = File.join(destination, entry.name)
        FileUtils.mkdir_p(File.dirname(f_path))
        zip_file.extract(entry, f_path) unless File.exist?(f_path)
      end
    end
    Zip::File.open(File.expand_path("#{Dir["#{destination}/20*"][0]}/mmsys.zip")) do |zip_file|
      # Handle entries one by one
      zip_file.each do |entry|
        # Extract to file/directory/symlink
        puts "Extracting #{entry.name}"
        f_path = File.join((Dir["#{destination}/20*"][0]).to_s, entry.name)
        FileUtils.mkdir_p(File.dirname(f_path))
        zip_file.extract(entry, f_path) unless File.exist?(f_path)
      end
    end
  end

  desc 'run umls jar'
  task :run_umls, [:version] do |_t, args|
    # More information on batch running UMLS
    # https://www.nlm.nih.gov/research/umls/implementation_resources/community/mmsys/BatchMetaMorphoSys.html
    args.with_defaults(version: '2019')

    versioned_temp_dir = File.join(TEMP_DIR, args.version)

    version_props = {
      '2019' => 'inferno_2019.prop',
      '2020' => 'inferno_2020.prop',
      '2021' => 'inferno_2021.prop'
    }
    jre_version = if !(/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM).nil?
                    'windows64'
                  elsif !(/darwin/ =~ RUBY_PLATFORM).nil?
                    'macos'
                  else
                    'linux'
                  end
    puts "#{jre_version} system detected"
    config_file = File.join(Dir.pwd, 'resources', 'terminology', version_props[args.version])
    output_dir = File.join(Dir.pwd, versioned_temp_dir, 'umls_subset')
    FileUtils.mkdir(output_dir)
    puts "Using #{config_file}"
    Dir.chdir(Dir[File.join(Dir.pwd, versioned_temp_dir, '/umls/20*')][0]) do
      puts Dir.pwd
      Dir['lib/*.jar'].each do |jar|
        File.chmod(0o555, jar)
      end
      Dir["jre/#{jre_version}/bin/*"].each do |file|
        File.chmod(0o555, file)
      end
      puts 'Running MetamorphoSys (this may take a while)...'
      output = system("./jre/#{jre_version}/bin/java " \
                          '-Djava.awt.headless=true ' \
                          '-cp .:lib/jpf-boot.jar ' \
                          '-Djpf.boot.config=./etc/subset.boot.properties ' \
                          '-Dlog4j.configuration=./etc/log4j.properties ' \
                          '-Dinput.uri=. ' \
                          "-Doutput.uri=#{output_dir} " \
                          "-Dmmsys.config.uri=#{config_file} " \
                          '-Xms300M -Xmx8G ' \
                          'org.java.plugin.boot.Boot')
      unless output
        puts 'MetamorphoSys run failed'
        # The cwd at this point is 2 directories above where umls_subset is, so we have to navigate up to it
        FileUtils.remove_dir(File.join(Dir.pwd, '..', '..', 'umls_subset')) if File.directory?(File.join(Dir.pwd, '..', '..', 'umls_subset'))
        exit 1
      end
    end
    puts 'done'
  end

  desc 'cleanup all terminology files'
  task :cleanup, [] do |_t, _args|
    puts "removing all terminology build files in #{TEMP_DIR}"
    FileUtils.remove_dir File.join(TEMP_DIR)
  end

  desc 'cleanup terminology files except umls.db'
  task :cleanup_precursors, [:version] do |_t, args|
    args.with_defaults(version: '2019')
    puts "removing terminology precursor files in #{TEMP_DIR}/#{args.version}"
    FileUtils.remove_dir(File.join(TEMP_DIR, args.version, 'umls'), true)
    FileUtils.remove_dir(File.join(TEMP_DIR, args.version, 'umls_subset'), true)
    FileUtils.rm(File.join(TEMP_DIR, args.version, 'umls.zip'), force: true)
    FileUtils.rm(Dir.glob(File.join(TEMP_DIR, args.version, '*.pipe')), force: true)
  end


  def db_for_version(version)
    File.join(TEMP_DIR, version, 'umls.db')
  end

  desc 'post-process UMLS terminology file'
  task :process_umls, [:version] do |_t, args|
    args.with_defaults(version: '2019')
    versioned_temp_dir = File.join(TEMP_DIR, version)
    require 'find'
    require 'csv'
    puts 'Looking for `./tmp/terminology/MRCONSO.RRF`...'
    input_file = Find.find(versioned_temp_dir).find { |f| /MRCONSO.RRF$/ =~f }
    if input_file
      start = Time.now
      output_filename = File.join(versioned_temp_dir, 'terminology_umls.txt')
      output = File.open(output_filename, 'w:UTF-8')
      line = 0
      excluded = 0
      excluded_systems = Hash.new(0)
      begin
        puts "Writing to #{output_filename}..."
        CSV.foreach(input_file, headers: false, col_sep: '|', quote_char: "\x00") do |row|
          line += 1
          include_code = false
          code_system = row[11]
          code = row[13]
          description = row[14]
          case code_system
          when 'SNOMEDCT_US'
            code_system = 'SNOMED'
            include_code = (row[4] == 'PF' && ['FN', 'OAF'].include?(row[12]))
          when 'LNC'
            code_system = 'LOINC'
            include_code = true
          when 'ICD10CM'
            code_system = 'ICD10'
            include_code = (row[12] == 'PT')
          when 'ICD10PCS'
            code_system = 'ICD10'
            include_code = (row[12] == 'PT')
          when 'ICD9CM'
            code_system = 'ICD9'
            include_code = (row[12] == 'PT')
          when 'CPT'
            include_code = (row[12] == 'PT')
          when 'HCPCS'
            include_code = (row[12] == 'PT')
          when 'MTHICD9'
            code_system = 'ICD9'
            include_code = true
          when 'RXNORM'
            include_code = true
          when 'CVX'
            include_code = ['PT', 'OP'].include?(row[12])
          when 'SRC'
            # 'SRC' rows define the data sources in the file
            include_code = false
          else
            include_code = false
            excluded_systems[code_system] += 1
          end
          if include_code
            output.write("#{code_system}|#{code}|#{description}\n")
          else
            excluded += 1
          end
        end
      rescue StandardError => e
        puts "Error at line #{line}"
        puts e.message
      end
      output.close
      puts "Processed #{line} lines, excluding #{excluded} redundant entries."
      puts "Excluded code systems: #{excluded_systems}" unless excluded_systems.empty?
      finish = Time.now
      minutes = ((finish - start) / 60)
      seconds = (minutes - minutes.floor) * 60
      puts "Completed in #{minutes.floor} minute(s) #{seconds.floor} second(s)."
      puts 'Done.'
    else
      download_umls_notice
    end
  end

  def download_umls_notice
    puts 'UMLS file not found.'
    puts 'Download the US National Library of Medicine (NLM) Unified Medical Language System (UMLS) Full Release files'
    puts '  -> https://www.nlm.nih.gov/research/umls/licensedcontent/umlsknowledgesources.html'
    puts 'Install the metathesaurus with the following data sources:'
    puts '  CVX|CVX;ICD10CM|ICD10CM;ICD10PCS|ICD10PCS;ICD9CM|ICD9CM;LNC|LNC;MTHICD9|ICD9CM;RXNORM|RXNORM;SNOMEDCT_US|SNOMEDCT;CPT;HCPCS'
    puts 'After installation, copy `{install path}/META/MRCONSO.RRF` into your `./tmp/terminology` folder, and rerun this task.'
  end

  desc 'post-process UMLS terminology file for translations'
  task :process_umls_translations, [] do |_t, _args|
    require 'find'
    puts 'Looking for `./tmp/terminology/MRCONSO.RRF`...'
    input_file = Find.find(File.join(TEMP_DIR, 'terminology')).find { |f| /MRCONSO.RRF$/ =~f }
    if input_file
      start = Time.now
      output_filename = File.join(TEMP_DIR, 'translations_umls.txt')
      output = File.open(output_filename, 'w:UTF-8')
      line = 0
      excluded_systems = Hash.new(0)
      begin
        entire_file = File.read(input_file)
        puts "Writing to #{output_filename}..."
        current_umls_concept = nil
        translation = Array.new(10)
        entire_file.split("\n").each do |l|
          row = l.split('|')
          line += 1
          concept = row[0]
          if concept != current_umls_concept && !current_umls_concept.nil?
            output.write("#{translation.join('|')}\n") unless translation[1..-2].reject(&:nil?).length < 2
            translation = Array.new(10)
            current_umls_concept = concept
            translation[0] = current_umls_concept
          elsif current_umls_concept.nil?
            current_umls_concept = concept
            translation[0] = current_umls_concept
          end
          code_system = row[11]
          code = row[13]
          translation[9] = row[14]
          case code_system
          when 'SNOMEDCT_US'
            translation[1] = code if row[4] == 'PF' && ['FN', 'OAF'].include?(row[12])
          when 'LNC'
            translation[2] = code
          when 'ICD10CM'
            translation[3] = code if row[12] == 'PT'
          when 'ICD10PCS'
            translation[3] = code if row[12] == 'PT'
          when 'ICD9CM'
            translation[4] = code if row[12] == 'PT'
          when 'MTHICD9'
            translation[4] = code
          when 'RXNORM'
            translation[5] = code
          when 'CVX'
            translation[6] = code if ['PT', 'OP'].include?(row[12])
          when 'CPT'
            translation[7] = code if row[12] == 'PT'
          when 'HCPCS'
            translation[8] = code if row[12] == 'PT'
          when 'SRC'
            # 'SRC' rows define the data sources in the file
          else
            excluded_systems[code_system] += 1
          end
        end
      rescue StandardError => e
        puts "Error at line #{line}"
        puts e.message
      end
      output.close
      puts "Processed #{line} lines."
      puts "Excluded code systems: #{excluded_systems}" unless excluded_systems.empty?
      finish = Time.now
      minutes = ((finish - start) / 60)
      seconds = (minutes - minutes.floor) * 60
      puts "Completed in #{minutes.floor} minute(s) #{seconds.floor} second(s)."
      puts 'Done.'
    else
      download_umls_notice
    end
  end

  desc 'Create ValueSet Validators'
  task :create_vs_validators, [:database, :type, :version, :delete_existing] do |_t, args|
    args.with_defaults(type: 'bloom', delete_existing: true, version: '2019')

    database = if !args.database.nil?
                 args.database
               else
                 db_for_version(args.version)
               end
    validator_type = args.type.to_sym
    Inferno::Terminology.register_umls_db database
    Inferno::Terminology.load_valuesets_from_directory(Inferno::Terminology::PACKAGE_DIR, true)
    Inferno::Terminology.create_validators(type: validator_type, delete_existing: args.delete_existing)
  end

  desc 'Create only non-UMLS validators'
  task :create_non_umls_vs_validators, [:module, :minimum_binding_strength, :delete_existing] do |_t, args|
    args.with_defaults(type: 'bloom',
                       module: :all,
                       minimum_binding_strength: 'example',
                       delete_existing: true)
    validator_type = args.type.to_sym
    Inferno::Terminology.load_valuesets_from_directory(Inferno::Terminology::PACKAGE_DIR, true)
    Inferno::Terminology.create_validators(type: validator_type,
                                           selected_module: args.module,
                                           minimum_binding_strength: args.minimum_binding_strength,
                                           include_umls: false,
                                           delete_existing: args.delete_existing)
  end

  desc 'Create ValueSet Validators for a given module'
  task :create_module_vs_validators, [:module, :minimum_binding_strength, :version, :delete_existing] do |_t, args|
    args.with_defaults(module: 'all',
                       minimum_binding_strength: 'example',
                       delete_existing: true,
                       version: '2019')
    # Args come in as strings, so we need to convert to a boolean
    delete_existing = args.delete_existing != 'false'

    Inferno::Terminology.register_umls_db db_for_version(args.version)
    Inferno::Terminology.load_valuesets_from_directory(Inferno::Terminology::PACKAGE_DIR, true)
    Inferno::Terminology.create_validators(type: :bloom,
                                           selected_module: args.module,
                                           minimum_binding_strength: args.minimum_binding_strength,
                                           delete_existing: delete_existing)
  end

  desc 'Number of codes in ValueSet'
  task :codes_in_valueset, [:vs] do |_t, args|
    Inferno::Terminology.register_umls_db File.join(TEMP_DIR, 'umls.db')
    Inferno::Terminology.load_valuesets_from_directory(Inferno::Terminology::PACKAGE_DIR, true)
    vs = Inferno::Terminology.known_valuesets[args.vs]
    puts vs&.valueset&.count
  end

  desc 'Expand and Save ValueSet to a file'
  task :expand_valueset_to_file, [:vs, :filename, :type] do |_t, args|
    # JSON is a special case, because we need to add codes from valuesets from several versions
    # We accomplish this by collecting and merging codes from each version
    # Before writing the JSON to a file at the end
    if args.type == 'json'
      end_vs = nil
    end

    %w{2019 2020 2021}.each do |version|
      Inferno::Terminology.register_umls_db File.join(TEMP_DIR, version, 'umls.db')
      Inferno::Terminology.load_valuesets_from_directory(Inferno::Terminology::PACKAGE_DIR, true)
      vs = Inferno::Terminology.known_valuesets[args.vs]
      if args.type == 'json'
        end_vs ||= vs
        # Collect valueset codes
        end_vs.valueset.merge vs.valueset
      else
        Inferno::Terminology.save_to_file(vs.valueset, args.filename, args.type.to_sym)
      end
    end

    if args.type == 'json'
      File.open("#{args.filename}.json", 'wb') { |f| f << end_vs.expansion_as_fhir_valueset.to_json }
    end
  end

  desc 'Download FHIR Package'
  task :download_package, [:package, :location] do |_t, args|
    Inferno::FHIRPackageManager.get_package(args.package, args.location)
  end

  desc 'Download Terminology from FHIR Package'
  task :download_program_terminology do |_t, _args|
    Inferno::Terminology.load_fhir_r4
    Inferno::Terminology.load_fhir_expansions
    Inferno::Terminology.load_us_core
  end

  desc 'Check if the code is in the specified ValueSet.  Omit the ValueSet to check against CodeSystem'
  task :check_code, [:code, :system, :valueset] do |_t, args|
    args.with_defaults(system: nil, valueset: nil)
    code_display = args.system ? "#{args.system}|#{args.code}" : args.code.to_s
    if Inferno::Terminology.validate_code(code: args.code, system: args.system, valueset_url: args.valueset)
      in_system = 'is in'
      symbol = "\u2713".encode('utf-8').to_s.green
    else
      in_system = 'is not in'
      symbol = 'X'.red
    end
    system_checked = args.valueset || args.system

    puts "#{symbol} #{code_display} #{in_system} #{system_checked}"
  end
end
