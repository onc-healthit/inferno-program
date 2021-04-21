# frozen_string_literal: true

require 'active_record'

module Inferno
  module Utils
    module Database
      def self.establish_db_connection
        path = File.join(__dir__, '..', '..', '..', 'db', 'config.yml')
        configuration = YAML.load_file(path)[ENV['RACK_ENV']]
        ActiveRecord::Base.establish_connection(configuration)
        ActiveRecord::Base.connection
      end
    end
  end
end
