# frozen_string_literal: true

module Inferno
  module Sequence
    class SMARTInvalidAud < SequenceBase
      title 'SMART Invalid AUD'
      description 'Demonstrate that the server properly validates AUD parameter'

      test_id_prefix 'SIA'

      requires :bulk_client_id, :bulk_jwks_url_auth, :bulk_encryption_method, :bulk_token_endpoint, :bulk_scope
      defines :bulk_access_token

      test 'test_one 1' do
        metadata do
        id '01'
        description %(
            Test description
        )
        end
      end
    end
  end
end