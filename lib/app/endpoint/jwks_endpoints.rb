# frozen_string_literal: true

module Inferno
  class App
    module JwksEndpoints
      def self.included(klass)
        klass.class_eval do
          get '/.well-known/jwks.json' do
            keys = []
            if settings.respond_to? :bulk_data_jwks
              keys.push(settings.bulk_data_jwks['es384_public']) if settings.bulk_data_jwks['es384_public'].present?
              keys.push(settings.bulk_data_jwks['rs384_public']) if settings.bulk_data_jwks['rs384_public'].present?
            end

            jwks_urls = { 'keys': keys }

            content_type :json
            jwks_urls.to_json
          end
        end
      end
    end
  end
end
