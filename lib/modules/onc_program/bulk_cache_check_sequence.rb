# frozen_string_literal: true

module Inferno
    module Sequence
      class BulkCacheCheck < SequenceBase
        title 'JWK Set Cache Check'
        description 'Demonstrate JWK Set Cache Check'
  
        test_id_prefix 'JSCC'
  
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