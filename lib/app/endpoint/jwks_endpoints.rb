# frozen_string_literal: true

module Inferno
  class App
    module JwksEndpoints
      def self.included(klass)
        klass.class_eval do
          get '/.well-known/jwks.json' do
            an_instance = Inferno::Models::TestingInstance.first()
            content_type :json
            an_instance.bulk_public_key
          end
        end
      end
    end
  end
end
