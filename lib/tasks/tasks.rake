# frozen_string_literal: true

require 'fhir_client'
require 'pry'
require 'pry-byebug'
require 'csv'
require 'colorize'
require 'nokogiri'
require 'optparse'
require 'rubocop/rake_task'

require_relative '../app'
require_relative '../app/endpoint'
require_relative '../app/helpers/configuration'
require_relative '../app/sequence_base'
require_relative '../app/models'

include Inferno

def suppress_output
  begin
    original_stderr = $stderr.clone
    original_stdout = $stdout.clone
    $stderr.reopen(File.new('/dev/null', 'w'))
    $stdout.reopen(File.new('/dev/null', 'w'))
    retval = yield
  rescue StandardError => e
    $stdout.reopen(original_stdout)
    $stderr.reopen(original_stderr)
    raise e
  ensure
    $stdout.reopen(original_stdout)
    $stderr.reopen(original_stderr)
  end
  retval
end

# Removes indents from markdown for better printing
def unindent_markdown(markdown)
  return nil if markdown.nil?

  natural_indent = markdown.lines.collect { |l| l.index(/[^ ]/) }.select { |l| !l.nil? && l.positive? }.min || 0
  markdown.lines.map { |l| l[natural_indent..-1] || "\n" }.join.lstrip
end

def print_requests(result)
  result.request_responses.map do |req_res|
    req_res.response_code.to_s + ' ' + req_res.request_method.upcase + ' ' + req_res.request_url
  end
end

def execute(instance, sequences)
  client = FHIR::Client.for_testing_instance(instance)

  sequence_results = []

  fails = false
  skips = false

  system 'clear'
  puts "\n"
  puts "==========================================\n"
  puts " Testing #{sequences.length} Sequences"
  puts "==========================================\n"
  sequences.each do |sequence_info|
    sequence = sequence_info['sequence']
    sequence_info.each do |key, val|
      if key != 'sequence'
        if val.is_a?(Array) || val.is_a?(Hash)
          instance.send("#{key}=", val.to_json) if instance.respond_to? key.to_s
        elsif val.is_a?(String) && val.casecmp('true').zero?
          instance.send("#{key}=", true) if instance.respond_to? key.to_s
        elsif val.is_a?(String) && val.casecmp('false').zero?
          instance.send("#{key}=", false) if instance.respond_to? key.to_s
        elsif instance.respond_to? key.to_s
          instance.send("#{key}=", val)
        end
      end
    end
    instance.save!

    disable_verify_peer = Inferno::App::Endpoint.settings.disable_verify_peer
    sequence_instance = sequence.new(instance, client, disable_verify_peer)
    sequence_result = nil

    suppress_output { sequence_result = sequence_instance.start }

    sequence_results << sequence_result

    checkmark = "\u2713"
    puts "\n" + sequence.sequence_name + " Sequence: \n"
    sequence_result.test_results.each do |result|
      print ' '
      if result.pass?
        print "#{checkmark.encode('utf-8')} pass".green
        print " - #{result.test_id} #{result.name}\n"
      elsif result.skip?
        print '* skip'.yellow
        print " - #{result.test_id} #{result.name}\n"
        puts "    Message: #{result.message}"
      elsif result.fail?
        if result.required
          print 'X fail'.red
          print " - #{result.test_id} #{result.name}\n"
          puts "    Message: #{result.message}"
          print_requests(result).map do |req|
            puts "    #{req}"
          end
          fails = true
        else
          print 'X fail (optional)'.light_black
          print " - #{result.test_id} #{result.name}\n"
          puts "    Message: #{result.message}"
          print_requests(result).map do |req|
            puts "    #{req}"
          end
        end
      elsif result.error?
        print 'X error'.magenta
        print " - #{result.test_id} #{result.name}\n"
        puts "    Message: #{result.message}"
        print_requests(result).map do |req|
          puts "      #{req}"
        end
        fails = true
      elsif result.omit?
        print '* omit'.light_black
        print " - #{result.test_id} #{result.name}\n"
        puts "    Message: #{result.message}"
      end
    end
    print "\n" + sequence.sequence_name + ' Sequence Result: '
    if sequence_result.pass?
      puts 'pass '.green + checkmark.encode('utf-8').green
    elsif sequence_result.fail?
      puts 'fail '.red + 'X'.red
      fails = true
    elsif sequence_result.error?
      puts 'error '.magenta + 'X'.magenta
      fails = true
    elsif sequence_result.skip?
      puts 'skip '.yellow + '*'.yellow
      skips = true
    end
    puts "---------------------------------------------\n"
  end

  failures_count = sequence_results.count(&:fail?).to_s
  passed_count = sequence_results.count(&:pass?).to_s
  print ' Result: ' + failures_count.red + ' failed, ' + passed_count.green + ' passed'
  if sequence_results.any?(&:skip?)
    skip_count = sequence_results.count(&:skip?).to_s
    print(', ' + skip_count.yellow + ' skipped')
  end
  if sequence_results.any?(&:error?)
    error_count = sequence_results.count(&:error?).to_s
    print(', ' + error_count.yellow + ' error')
  end

  puts "\n=============================================\n"

  return_value = 0
  return_value = 1 if fails || skips

  return_value
end

def file_path(filename)
  return filename unless ENV['RACK_ENV'] == 'test'

  FileUtils.mkdir_p 'tmp'
  File.join('tmp', filename)
end

namespace :inferno do |_argv|
  # Exports a CSV containing the test metadata
  desc 'Generate List of All Tests'
  task :tests_to_csv, [:module, :group, :filename] do |_task, args|
    # Leaving for now, but we may want to consolodate under the XLS export
    # because that supports multi-line fields (e.g. descriptions) and our
    # intended audience for this feature will be opening the CSVs in Excel anyhow.
    # We could consider refactoring to allow either, but that doesn't have a high
    # priority at this point.
    Inferno.logger.warn 'Please use :tests_to_xls, which will replace this task'
    args.with_defaults(module: 'argonaut', group: 'active')
    args.with_defaults(filename: "#{args.module}_testlist.csv")
    inferno_module = Inferno::Module.get(args.module)
    sequences = inferno_module&.sequences
    if sequences.nil?
      puts "No sequence found for module: #{args.module}"
      exit
    end

    flat_tests = sequences.map do |klass|
      klass.tests(inferno_module).map do |test|
        test.metadata_hash.merge(
          sequence: klass.to_s,
          sequence_required: !klass.optional?
        )
      end
    end.flatten

    csv_out = CSV.generate do |csv|
      csv << ['Version', VERSION, 'Generated', Time.now]
      csv << ['', '', '', '', '']
      csv << ['Test ID', 'Reference', 'Sequence/Group', 'Test Name', 'Required?', 'Reference URI']
      flat_tests.each do |test|
        csv << [
          test[:test_id],
          test[:ref],
          test[:sequence].split('::').last,
          test[:name],
          test[:sequence_required] && test[:required],
          test[:url]
        ]
      end
    end

    filename = file_path(args.filename)

    File.write(filename, csv_out)
    Inferno.logger.info "Writing to #{filename}"
  end

  desc 'Generate a rich excel file'
  task :tests_to_xls, [:module, :test_set, :filename] do |_task, args|
    require 'rubyXL'
    require 'rubyXL/convenience_methods'
    args.with_defaults(module: 'onc_certification', test_set: 'test_procedure')
    args.with_defaults(filename: "#{args.module}_testlist.xlsx")

    workbook = RubyXL::Workbook.new
    worksheet = workbook.worksheets[0]

    # ['Version', VERSION, '', 'Generated', Time.now.to_s].each_with_index do |value, index|
    #   worksheet.add_cell(0, index, value)
    # end
    # worksheet.change_row_italics(0, true)
    # worksheet.add_cell(1, 0, '')

    columns = [
      ['Inferno Test', 14, ->(_group, test_case, test) { "#{test_case.prefix}#{test.id}" }],
      ['Rule No', 14, ->(_group, _test_case, _test) { '' }],
      ['Test Step', 14, ->(_group, _test_case, _test) { '' }],
      ['Rule Section', 14, ->(_group, _test_case, _test) { '' }],
      ['Test Case Name', 20, ->(_group, test_case, _test) { test_case.title }],
      ['Test Name', 50, ->(_group, _test_case, test) { test.name }],
      ['Test Case Description', 45, ->(_group, test_case, _test) { test_case.description }],
      ['Required?', 9, ->(_group, test_case, test) { (!test_case.sequence.optional? && !test.optional?).to_s }],
      ['Elaborated Testable Requirements', 14, ->(_group, _test_case, _test) { '' }],
      ['Comments', 14, ->(_group, _test_case, _test) { '' }],
      ['Rule Language', 14, ->(_group, _test_case, _test) { '' }],
      ['Preamble Language', 14, ->(_group, _test_case, _test) { '' }],
      ['Test Link', 85, ->(_group, _test_case, test) { test.link }],
      ['Group', 30, ->(group, _test_case, _test) { group.name }],
      ['', 100, ->(_group, _test_case, _test) { '' }],
      ['Group Overview', 30, ->(group, _test_case, _test) { group.overview }],
      ['', 3, ->(_group, _test_case, _test) { '' }],
      ['Test Case Details', 30, ->(_group, test_case, _test) { unindent_markdown(test_case.sequence.details) }],
      ['Test Detail', 60, ->(group, _test_case, _test) { group.name }],
      ['Test Procedure Reference', 30, ->(_group, _test_case, test) { test.ref || ' ' }]
    ]

    columns.each_with_index do |row_name, index|
      cell = worksheet.add_cell(0, index, row_name.first)
      cell.change_text_wrap(true)
    end

    worksheet.change_row_bold(0, true)
    worksheet.change_row_fill(0, 'BBBBBB')
    worksheet.change_row_height(0, 40)

    test_module = Inferno::Module.get(args.module)
    test_set = test_module.test_sets[args.test_set.to_sym]
    row = 1

    test_set.groups.each do |group|
      cell = worksheet.add_cell(row, 0, group.name)
      cell.change_text_wrap(true)
      worksheet.merge_cells(row, 0, row, columns.length)
      worksheet.change_row_fill(row, 'EEEEEE')
      worksheet.change_row_height(row, 25)
      worksheet.change_row_vertical_alignment(row, 'distributed')
      row += 1
      group.test_cases.each do |test_case|
        test_case.sequence.tests.each do |test|
          next if test_case.sequence.optional? || test.optional?

          this_row = columns.map do |col|
            col[2].call(group, test_case, test)
          end

          this_row.each_with_index do |value, index|
            cell = worksheet.add_cell(row, index, value)
            cell.change_text_wrap(true)
          end
          worksheet.change_row_height(row, 30)
          worksheet.change_row_vertical_alignment(row, 'top')
          worksheet.change_row_font_color(row, '666666') unless !test_case.sequence.optional? && !test.optional?
          row += 1
        end
      end
    end

    columns.each_with_index do |col, index|
      worksheet.change_column_width(index, col[1])
    end

    Inferno.logger.info "Writing to #{args.filename}"
    workbook.write(args.filename)
  end

  desc 'Generate a visual matrix of test procedure coverage'
  task :generate_matrix, [:module, :test_set, :filename] do |_task, args|
    require 'rubyXL'
    require 'rubyXL/convenience_methods'
    args.with_defaults(module: 'onc_program', test_set: 'test_procedure')
    args.with_defaults(filename: "#{args.module}_matrix.xlsx")

    workbook = RubyXL::Workbook.new

    test_module = Inferno::Module.get(args.module)
    test_set = test_module.test_sets[args.test_set.to_sym]

    ########################
    # MATRIX WORKSHEET
    ########################

    matrix_worksheet = workbook.worksheets[0]
    matrix_worksheet.sheet_name = 'Matrix'

    col = 2
    cell = matrix_worksheet.add_cell(0, 1, "Inferno Program Tests (v#{Inferno::VERSION})")
    matrix_worksheet.change_row_height(0, 20)
    matrix_worksheet.change_row_vertical_alignment(0, 'distributed')
    tests = []
    column_map = {}
    inferno_to_procedure_map = Hash.new { |h, k| h[k] = [] }
    matrix_worksheet.change_column_width(1, 25)
    matrix_worksheet.change_row_height(1, 20)
    matrix_worksheet.change_row_horizontal_alignment(1, 'center')
    matrix_worksheet.change_row_vertical_alignment(1, 'distributed')
    column_borders = []

    test_set.groups.each do |group|
      cell = matrix_worksheet.add_cell(1, col, group.name)
      matrix_worksheet.merge_cells(1, col, 1, col + group.test_cases.length - 1)
      cell.change_text_wrap(true)
      matrix_worksheet.change_column_border(col, :left, 'medium')
      matrix_worksheet.change_column_border_color(col, :left, '000000')
      column_borders << col

      group.test_cases.each do |test_case|
        matrix_worksheet.change_column_width(col, 4.2)

        test_case_id = test_case.sequence.tests.first.id.split('-').first
        test_case_id = "#{test_case.prefix}#{test_case_id}" unless test_case.prefix.nil?
        cell = matrix_worksheet.add_cell(2, col, test_case_id)
        cell.change_text_rotation(90)
        cell.change_border_color(:bottom, '000000')
        cell.change_border(:bottom, 'medium')
        matrix_worksheet.change_column_border(col, :right, 'thin')
        matrix_worksheet.change_column_border_color(col, :right, '666666')

        test_case.sequence.tests.each do |test|
          tests << { test_case: test_case, test: test }
          full_test_id = "#{test_case.prefix}#{test.id}"
          column_map[full_test_id] = col
        end
        col += 1
      end
    end

    total_width = col - 1
    matrix_worksheet.merge_cells(0, 1, 0, total_width)
    matrix_worksheet.change_row_horizontal_alignment(0, 'center')

    cell = matrix_worksheet.add_cell(2, total_width + 2, 'Supported?')
    row = 3

    test_module.test_procedure.sections.each do |section|
      section.steps.each do |step|
        cell = matrix_worksheet.add_cell(row, 1, "#{step.id.upcase} ")
        matrix_worksheet.change_row_height(row, 13)
        matrix_worksheet.change_row_vertical_alignment(row, 'distributed')

        (2..total_width).each do |column|
          cell = matrix_worksheet.add_cell(row, column, '')
        end

        step.inferno_tests.each do |test|
          column = column_map[test]
          inferno_to_procedure_map[test].push(step.id.upcase)
          if column.nil?
            puts "No such test found: #{test}"
            next
          end

          cell = matrix_worksheet.add_cell(row, column, '')
          cell.change_fill('3C63FF')
        end

        cell = matrix_worksheet.add_cell(row, total_width + 2, step.inferno_supported.upcase)

        row += 1
      end
    end
    matrix_worksheet.change_column_horizontal_alignment(1, 'right')
    matrix_worksheet.change_row_horizontal_alignment(0, 'center')

    column_borders.each do |column|
      matrix_worksheet.change_column_border(column, :left, 'medium')
      matrix_worksheet.change_column_border_color(column, :left, '000000')
    end
    matrix_worksheet.change_column_border_color(total_width, :right, '000000')
    matrix_worksheet.change_column_border(total_width, :right, 'medium')
    matrix_worksheet.change_column_width(total_width + 1, 3)

    matrix_worksheet.change_column_width(total_width + 3, 6)
    matrix_worksheet.change_column_width(total_width + 4, 2)
    matrix_worksheet.change_column_width(total_width + 5, 60)
    matrix_worksheet.add_cell(1, total_width + 3, '').change_fill('3C63FF')
    matrix_worksheet.add_cell(1, total_width + 5, 'Blue boxes indicate that the Inferno test (top) covers this test procedure step (left).').change_text_wrap(true)
    matrix_worksheet.change_column_horizontal_alignment(total_width + 5, :left)

    ########################
    # TEST PROCEDURE WORKSHEET
    ########################

    workbook.add_worksheet('Test Procedure')
    tp_worksheet = workbook.worksheets[1]

    [3, 3, 22, 65, 65, 3, 15, 30, 65, 65].each_with_index { |width, index| tp_worksheet.change_column_width(index, width) }
    ['',
     '',
     'ID',
     'System Under Test',
     'Test Lab Verifies',
     '',
     'Inferno Supports?',
     'Inferno Tests',
     'Inferno Notes',
     'Alternate Test Methodology'].each_with_index { |text, index| tp_worksheet.add_cell(0, index, text) }

    row = 2

    test_module.test_procedure.sections.each do |section|
      cell = tp_worksheet.add_cell(row, 0, section.name)
      row += 1
      section.steps.group_by(&:group).each do |group_name, steps|
        cell = tp_worksheet.add_cell(row, 1, group_name)
        row += 1
        steps.each do |step|
          longest_line = [step.s_u_t, step.t_l_v, step.inferno_notes, step.alternate_test].map { |text| text&.lines&.count || 0 }.max
          tp_worksheet.change_row_height(row, longest_line * 10 + 10)
          tp_worksheet.change_row_vertical_alignment(row, 'top')
          cell = tp_worksheet.add_cell(row, 2, "#{step.id.upcase} ")
          cell = tp_worksheet.add_cell(row, 3, step.s_u_t).change_text_wrap(true)
          cell = tp_worksheet.add_cell(row, 4, step.t_l_v).change_text_wrap(true)
          cell = tp_worksheet.add_cell(row, 5, '')
          cell = tp_worksheet.add_cell(row, 6, step.inferno_supported)
          cell = tp_worksheet.add_cell(row, 7, step.inferno_tests.join(', ')).change_text_wrap(true)
          cell = tp_worksheet.add_cell(row, 8, step.inferno_notes).change_text_wrap(true)
          cell = tp_worksheet.add_cell(row, 9, step.alternate_test).change_text_wrap(true)
          row += 1
        end
      end
      row += 1
    end

    ########################
    # INFERNO TESTS WORKSHEET
    ########################

    workbook.add_worksheet('Inferno Tests')
    inferno_worksheet = workbook.worksheets[2]

    columns = [
      ['', 3, ->(_group, _test_case, _test) { '' }],
      ['', 3, ->(_group, _test_case, _test) { '' }],
      ['Inferno Test ID', 22, ->(_group, test_case, test) { "#{test_case.prefix}#{test.id}" }],
      ['Inferno Test Name', 65, ->(_group, _test_case, test) { test.name }],
      ['Inferno Test Description', 65, lambda do |_group, _test_case, test|
        natural_indent = test.description.lines.collect { |l| l.index(/[^ ]/) }.select { |l| !l.nil? && l.positive? }.min || 0
        test.description.lines.map { |l| l[natural_indent..-1] || "\n" }.join.strip
      end],
      ['Reference', 65, ->(_group, _test_case, test) { test.link }],
      ['Test Procedure Steps', 30, ->(_group, test_case, test) { inferno_to_procedure_map["#{test_case.prefix}#{test.id}"].join(', ') }]
    ]

    columns.each_with_index do |row_name, index|
      cell = inferno_worksheet.add_cell(0, index, row_name.first)
    end

    test_module = Inferno::Module.get(args.module)
    test_set = test_module.test_sets[args.test_set.to_sym]
    row = 1

    test_set.groups.each do |group|
      row += 1
      cell = inferno_worksheet.add_cell(row, 0, group.name)
      row += 1
      group.test_cases.each do |test_case|
        cell = inferno_worksheet.add_cell(row, 1, "#{test_case.prefix}#{test_case.sequence.tests.first.id.split('-').first}: #{test_case.title}: #{test_case.description}")
        row += 1
        test_case.sequence.tests.each do |test|
          next if test_case.sequence.optional? || test.optional?

          this_row = columns.map do |column|
            column[2].call(group, test_case, test)
          end

          this_row.each_with_index do |value, index|
            cell = inferno_worksheet.add_cell(row, index, value)
            cell.change_text_wrap(true)
          end
          inferno_worksheet.change_row_height(row, [26, test.description.strip.lines.count * 10 + 10].max)
          inferno_worksheet.change_row_vertical_alignment(row, 'top')
          row += 1
        end
      end
    end

    columns.each_with_index do |column, index|
      inferno_worksheet.change_column_width(index, column[1])
    end

    # inferno_worksheet.change_row_border(row-1, :bottom, 'medium')
    # inferno_worksheet.change_row_border_color(row-1, :bottom, '000000')

    # test_set.groups.each do |group|
    #   cell = inferno_worksheet.add_cell(row, 0, group.name)
    #   cell.change_text_wrap(true)
    #   inferno_worksheet.merge_cells(row, 0, row, columns.length)
    #   inferno_worksheet.change_row_fill(row, 'EEEEEE')
    #   inferno_worksheet.change_row_height(row, 25)
    #   inferno_worksheet.change_row_vertical_alignment(row, 'distributed')
    #   row += 1
    #   group.test_cases.each do |test_case|
    #     test_case.sequence.tests.each do |test|
    #       next if test_case.sequence.optional? || test.optional?

    #       this_row = columns.map do |col|
    #         col[2].call(group, test_case, test)
    #       end

    #       this_row.each_with_index do |value, index|
    #         cell = worksheet.add_cell(row, index, value)
    #         cell.change_text_wrap(true)
    #       end
    #       worksheet.change_row_height(row, 30)
    #       worksheet.change_row_vertical_alignment(row, 'top')
    #       worksheet.change_row_font_color(row, '666666') unless !test_case.sequence.optional? && !test.optional?
    #       row += 1
    #     end
    #   end
    # end

    # columns.each_with_index do |col, index|
    #   worksheet.change_column_width(index, col[1])
    # end

    Inferno.logger.info "Writing to #{args.filename}"
    workbook.write(args.filename)
  end
  desc 'Generate automated run script'
  task :generate_script, [:server, :module] do |_task, args|
    sequences = []
    requires = []
    defines = []

    input = ''

    output = { server: args[:server], module: args[:module], arguments: {}, sequences: [] }

    instance = Inferno::TestingInstance.new(url: args[:server], selected_module: args[:module])
    instance.save!

    instance.module.sequences.each do |seq|
      unless input == 'a'
        print "\nInclude #{seq.sequence_name} (y/n/a)? "
        input = STDIN.gets.chomp
      end

      next unless ['a', 'y'].include? input

      output[:sequences].push(sequence: seq.sequence_name)
      sequences << seq
      seq.requires.each do |req|
        requires << req unless requires.include?(req) || defines.include?(req) || req == :url
      end
      defines.push(*seq.defines)
    end

    STDOUT.print "\n"

    requires.each do |req|
      input = ''

      if req == :initiate_login_uri
        input = 'http://localhost:4568/launch'
      elsif req == :redirect_uris
        input = 'http://localhost:4568/redirect'
      else
        STDOUT.flush
        STDOUT.print "\nEnter #{req.to_s.upcase}: ".light_black
        STDOUT.flush
        input = STDIN.gets.chomp
      end

      output[:arguments][req] = input
    end

    File.open('script.json', 'w') { |file| file.write(JSON.pretty_generate(output)) }
  end

  desc 'Execute sequences against a FHIR server'
  task :execute, [:server, :module] do |_task, args|
    Inferno::Utils::Database.establish_db_connection

    FHIR.logger.level = Logger::UNKNOWN
    sequences = []
    requires = []
    defines = []

    instance = Inferno::TestingInstance.new(url: args[:server], selected_module: args[:module])
    instance.save!

    instance.module.sequences.each do |seq|
      next unless args.extras.empty? || args.extras.include?(seq.sequence_name.split('Sequence')[0])

      seq.requires.each do |req|
        requires << req unless requires.include?(req) || defines.include?(req) || req == :url
      end
      defines.push(*seq.defines)
      sequences << seq
    end

    o = OptionParser.new

    o.banner = 'Usage: rake inferno:execute [options]'
    requires.each do |req|
      o.on("--#{req} #{req.to_s.upcase}") do |value|
        instance.send("#{req}=", value) if instance.respond_to? req.to_s
      end
    end

    arguments = o.order!(ARGV) {}

    o.parse!(arguments)

    if requires.include? :client_id
      puts 'Please register the application with the following information (enter to continue)'
      # FIXME
      puts "Launch URI: http://localhost:4567/#{base_path}/#{instance.id}/#{instance.client_endpoint_key}/launch"
      puts "Redirect URI: http://localhost:4567/#{base_path}/#{instance.id}/#{instance.client_endpoint_key}/redirect"
      STDIN.getc
      print "            \r"
    end

    input_required = false
    param_list = ''
    requires.each do |req|
      next unless instance.respond_to?(req) && instance.send(req).nil?

      puts "\nPlease provide the following required fields:\n" unless input_required
      print "  #{req.to_s.upcase}: ".light_black
      value_input = gets.chomp
      instance.send("#{req}=", value_input)
      input_required = true
      param_list = "#{param_list} --#{req.to_s.upcase} #{value_input}"
    end
    instance.save!

    if input_required
      args_list = "#{instance.url},#{args.module}"
      args_list += ",#{args.extras.join(',')}" unless args.extras.empty?

      puts ''
      puts "\nIn the future, run with the following command:\n\n"
      puts "  rake inferno:execute[#{args_list}] -- #{param_list}".light_black
      puts ''
      print '(enter to continue)'.red
      STDIN.getc
      print "            \r"
    end

    exit execute(instance, sequences.map { |s| { 'sequence' => s } })
  end

  desc 'Execute sequence against a FHIR server'
  task :execute_batch, [:config] do |_task, args|
    Inferno::Utils::Database.establish_db_connection

    file = File.read(args.config)
    config = JSON.parse(file)

    instance = Inferno::TestingInstance.new(
      url: config['server'],
      selected_module: config['module'],
      initiate_login_uri: 'http://localhost:4568/launch',
      redirect_uris: 'http://localhost:4568/redirect'
    )
    instance.save!
    client = FHIR::Client.new(config['server'])
    client.use_dstu2 if instance.module.fhir_version == 'dstu2'
    client.default_json

    config['arguments'].each do |key, val|
      if instance.respond_to?(key)
        if val.is_a?(Array) || val.is_a?(Hash)
          instance.send("#{key}=", val.to_json) if instance.respond_to? key.to_s
        elsif val.is_a?(String) && val.casecmp('true').zero?
          instance.send("#{key}=", true) if instance.respond_to? key.to_s
        elsif val.is_a?(String) && val.casecmp('false').zero?
          instance.send("#{key}=", false) if instance.respond_to? key.to_s
        elsif instance.respond_to? key.to_s
          instance.send("#{key}=", val)
        end
      end
    end

    sequences = config['sequences'].map do |sequence|
      sequence_name = sequence
      out = {}
      if !sequence.is_a?(Hash)
        out = {
          'sequence' => Inferno::Sequence::SequenceBase.descendants.find { |x| x.sequence_name.start_with?(sequence_name) }
        }
      else
        out = sequence
        out['sequence'] = Inferno::Sequence::SequenceBase.descendants.find { |x| x.sequence_name.start_with?(sequence['sequence']) }
      end

      out
    end

    exit execute(instance, sequences)
  end

  desc 'Generate Tests'
  task :generate, [:generator, :path] do |_t, args|
    require_relative("../../generator/#{args.generator}/#{args.generator}_generator")
    generator_class = Inferno::Generator::Base.subclasses.first do |c|
      c.name.demodulize.downcase.start_with?(args.generator)
    end

    generator = generator_class.new(args.path, args.extras)
    generator.run
  end
end

RuboCop::RakeTask.new(:rubocop) do |t|
  t.options = ['--display-cop-names']
end
