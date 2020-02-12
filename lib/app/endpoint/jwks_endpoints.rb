# frozen_string_literal: true

module Inferno
  class App
    module JwksEndpoints
      def self.included(klass)
        klass.class_eval do
          get '/.well-known/jwks.json' do
            binding.pry
            if settings.method_defined? :bulk_data_jwks
              keys = []
              if settings.bulk_data_jwks['es384_public'].present?
                keys.push(settings.bulk_data_jwks['es384_public'])
              end
              if settings.bulk_data_jwks['es384_public'].present?
                keys.push(settings.bulk_data_jwks['es384_public'])
              end
            end

            jwks_urls = Hash.new()
            jwks_urls["keys"] = keys

            content_type :json
            binding.pry
            an_instance.bulk_public_key
          end
        end
      end
    end
  end
end
