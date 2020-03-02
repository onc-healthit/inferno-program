# frozen_string_literal: true


module Inferno
  module FHIRPackageManager
    class << self
      REGISTRY_SERVER_URL = 'https://packages.fhir.org'
      # Get the FHIR Package from the registry.
      #
      # e.g. get_package('hl7.fhir.us.core#3.1.0')
      #
      # @param [String] package The FHIR Package
      def get_package(package)
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
      end
    end
  end
end