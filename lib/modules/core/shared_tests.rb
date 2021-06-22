# frozen_string_literal: true

module Inferno
  module Sequence
    module SharedTests
      def self.included(klass)
        klass.extend(ClassMethods)
      end

      module ClassMethods
        def test_is_deprecated(index:, name:, version:)
          test "test_is_deprecated_#{index}" do
            metadata do
              id index
              name "#{name} is deprecated"
              link 'http://hl7.org/fhir'
              description %(
                Test #{name} is deprecated from version #{version}
              )
              optional
            end

            omit
          end
        end
      end
    end
  end
end
