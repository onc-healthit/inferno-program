module Inferno
  module BCP47
    # https://tools.ietf.org/html/bcp47
    # https://tools.ietf.org/html/rfc5646
    # https://www.iana.org/assignments/language-subtag-registry/language-subtag-registry
    #
    class << self
      SEPARATOR = '%%'.freeze

      def code_set(filter = nil)
        filter_codes(filter)
      end

      def load_bcp47
        bcp47_file_location = 'resources/terminology/bcp47.txt'
        bcp47_file = File.new(bcp47_file_location)
        bcp47_file.gets(SEPARATOR) # remove the first line which has the date
        bcp47_file
      end

      def filter_codes(filter = nil)
        bcp47_file = bcp
        cs_set = Set.new
        bcp47_file.each(SEPARATOR) do |raw_language|
          language = parse_language(raw_language)
          next if language['Subtag'].nil?
          next if language['Type'] == 'region'

          cs_set.add(system: 'urn:ietf:bcp:47', code: language['Subtag']) if meets_filter_criteria?(language, filter)
        end
        cs_set
      end

      private

      def bcp
        load_bcp47
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

      def string_to_boolean(boolean_string)
        if boolean_string == 'true'
          true
        elsif boolean_string == 'false'
          false
        end
      end

      def meets_filter_criteria?(language, filter)
        return true unless filter

        meets_criteria = true
        if filter.op == 'exists'
          filter_value = string_to_boolean(filter.value)
          throw Terminology::Valueset::FilterOperationException(filter.to_s) if filter_value.nil?
          if filter.property == 'ext-lang'
            meets_criteria = (language['Type'] == 'extlang') == filter_value
          elsif filter.property == 'script'
            meets_criteria = (language['Type'] == 'script') == filter_value
          elsif filter.property == 'variant'
            meets_criteria = (language['Type'] == 'variant') == filter_value
          elsif filter.property == 'extension'
            meets_criteria = language['Subtag'].match?(/-\w-/) == filter_value
          elsif filter.property == 'private-use'
            meets_criteria = (language['Scope'] == 'private-use') == filter_value
          else
            throw Terminology::Valueset::FilterOperationException(filter.to_s)
          end
        else
          throw Terminology::Valueset::FilterOperationException(filter.op)
        end
        meets_criteria
      end
    end
  end
end