# frozen_string_literal: true

module Inferno
  module Models
    class TestingInstance
      property :onc_sl_url, String
      property :onc_sl_confidential_client, Boolean
      property :onc_sl_client_id, String
      property :onc_sl_client_secret, String
      property :onc_sl_scopes, String

      property :onc_patient_ids, String
    end
  end
end
