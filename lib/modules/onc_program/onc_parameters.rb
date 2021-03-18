# frozen_string_literal: true

module Inferno
  module Models
    class TestingInstance
      property :onc_sl_url, Text
      property :onc_sl_confidential_client, Boolean
      property :onc_sl_client_id, Text
      property :onc_sl_client_secret, Text
      property :onc_sl_scopes, Text
      property :onc_sl_expected_resources, Text

      property :onc_sl_token, Text
      property :onc_sl_refresh_token, Text
      property :onc_sl_patient_id, Text
      property :onc_sl_oauth_authorize_endpoint, Text
      property :onc_sl_oauth_token_endpoint, Text

      property :onc_public_client_id, Text
      property :onc_public_scopes, Text

      property :onc_patient_ids, Text

      property :onc_visual_single_registration, String, default: 'false'
      property :onc_visual_single_registration_notes, Text
      property :onc_visual_multi_registration, String, default: 'false'
      property :onc_visual_multi_registration_notes, Text
      property :onc_visual_single_scopes, String, default: 'false'
      property :onc_visual_single_scopes_notes, Text
      property :onc_visual_single_offline_access, String, default: 'false'
      property :onc_visual_single_offline_access_notes, Text
      property :onc_visual_refresh_timeout, String, default: 'false'
      property :onc_visual_refresh_timeout_notes, Text
      property :onc_visual_introspection, String, default: 'false'
      property :onc_visual_introspection_notes, Text
      property :onc_visual_data_without_omission, String, default: 'false'
      property :onc_visual_data_without_omission_notes, Text
      property :onc_visual_multi_scopes_no_greater, String, default: 'false'
      property :onc_visual_multi_scopes_no_greater_notes, Text
      property :onc_visual_documentation, String, default: 'false'
      property :onc_visual_documentation_notes, Text
      property :onc_visual_other_resources, String, default: 'false'
      property :onc_visual_other_resources_notes, Text
      property :onc_visual_jwks_cache, String, default: 'false'
      property :onc_visual_jwks_cache_notes, Text
      property :onc_visual_patient_period, String, default: 'false'
      property :onc_visual_patient_period_notes, Text
      property :onc_visual_patient_suffix, String, default: 'false'
      property :onc_visual_patient_suffix_notes, Text
      property :onc_visual_allergy_reaction, String, default: 'false'
      property :onc_visual_allergy_reaction_notes, Text

      property :onc_visual_token_revocation, String, default: 'false'
      property :onc_visual_token_revocation_notes, Text
      property :onc_visual_native_application, String, default: 'false'
      property :onc_visual_native_application_notes, Text
    end
  end
end
