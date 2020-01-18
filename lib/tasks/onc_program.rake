# frozen_string_literal: true

require 'fhir_client'
require 'pry'
require 'pry-byebug'
require 'dm-core'
require 'csv'
require 'colorize'
require 'optparse'
require 'rubocop/rake_task'

require_relative '../app'
require_relative '../app/endpoint'
require_relative '../app/helpers/configuration'
require_relative '../app/sequence_base'
require_relative '../app/models'

# rubocop: disable Style/MixinUsage
include Inferno
# rubocop: enable Style/MixinUsage

namespace :onc_program do |_argv|
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
end
