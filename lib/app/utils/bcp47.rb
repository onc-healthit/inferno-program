module Inferno
  module BCP47
    extend self
    SEPARATOR = '%%'.freeze


    def load_bcp47
      bcp47_file_location = 'resources/terminology/bcp47.txt'
      bcp47_file = File.new(bcp47_file_location)
      bcp47_file.gets(SEPARATOR) # remove the first line which has the date
      bcp47_file
    end

    def filter_codes(filter = nil)
      bcp47_file = bcp
      bcp47_file.each(SEPARATOR) do |language|
        puts parse_language(language)
      end
    end

    private

    @bcp = nil
    def bcp
      @bcp ||= load_bcp47
    end

    # Parse the language attributes chunk from the text file
    #
    # @param [String] language A single language and its attributes from the file
    # @return [Hash] the language attributes as key value pairs
    def parse_language(language)
      # Need to use scan because match only returns the first match group
      Hash[language.scan(regex)]
    end

    def regex
      /^(?<key>\S+): (?<value>.*)$/
    end

    def meets_filter_criteria?(language, filters)
      return true unless filters&.present?

      filters.each do |filter|
        if filter.op == 'exists'
          if filter.property == 'ext-lang'
            language['Type'] == filter.property
          end
        end
      end
    end
  end
end