# frozen_string_literal: true

require 'rubygems/package'
require 'tempfile'
require 'zlib'

module Inferno
  module FHIRPackageManager
    class << self

      REGISTRY_SERVER_URL = 'https://packages.fhir.org'
      # Get the FHIR Package from the registry.
      #
      # e.g. get_package('hl7.fhir.us.core#3.1.0')
      #
      # @param [String] package The FHIR Package
      def get_package(package, destination, desired_types = [])
        package_url = package
          .split('#')
          .prepend(REGISTRY_SERVER_URL)
          .join('/')

        File.open("tmp/#{package.split('#').join('-')}.tgz", 'w') do |output_file|
          block = proc do |response|
            response.read_body do |chunk|
              output_file.write chunk
            end
          end
          RestClient::Request.execute(method: :get, url: package_url, block_response: block)
        end

        tar = Gem::Package::TarReader.new(Zlib::GzipReader.open("tmp/#{package.split('#').join('-')}.tgz"))

        path = File.join destination.split('/')
        FileUtils.mkdir_p(path) unless File.exist?(path)

        tar.each do |entry|
          next if entry.directory?

          next unless entry.full_name.start_with? 'package/'

          file_name = entry.full_name.split('/').last
          next if desired_types.present? && !file_name.start_with?(*desired_types)

          puts 'writing'
          File.open(File.join(path, file_name), 'w') { |file| file.write(entry.read)}
        end
      end
    end
  end
end