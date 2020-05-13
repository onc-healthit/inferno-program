# frozen_string_literal: true

module Inferno
  module Models
    class TestingInstance
      property :onc_sl_url, String
      property :onc_sl_confidential_client, Boolean
      property :onc_sl_client_id, String
      property :onc_sl_client_secret, String
      property :onc_sl_scopes, String
      property :onc_sl_restricted_scopes, String

      property :onc_patient_ids, String

      property :onc_visual_single_registration, String, default: 'false'
      property :onc_visual_single_registration_notes, String
      property :onc_visual_multi_registration, String, default: 'false'
      property :onc_visual_multi_registration_notes, String
      property :onc_visual_single_scopes, String, default: 'false'
      property :onc_visual_single_scopes_notes, String
      property :onc_visual_single_offline_access, String, default: 'false'
      property :onc_visual_single_offline_access_notes, String
      property :onc_visual_refresh_timeout, String, default: 'false'
      property :onc_visual_refresh_timeout_notes, String
      property :onc_visual_introspection, String, default: 'false'
      property :onc_visual_introspection_notes, String
      property :onc_visual_data_without_omission, String, default: 'false'
      property :onc_visual_data_without_omission_notes, String
      property :onc_visual_multi_scopes_no_greater, String, default: 'false'
      property :onc_visual_multi_scopes_no_greater_notes, String
      property :onc_visual_documentation, String, default: 'false'
      property :onc_visual_documentation_notes, String
    end
  end
end
