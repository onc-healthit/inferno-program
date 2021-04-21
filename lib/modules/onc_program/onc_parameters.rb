# frozen_string_literal: true

module Inferno
  class TestingInstance
    attribute :onc_visual_single_registration, :string, default: 'false'
    attribute :onc_visual_multi_registration, :string, default: 'false'
    attribute :onc_visual_single_scopes, :string, default: 'false'
    attribute :onc_visual_single_offline_access, :string, default: 'false'
    attribute :onc_visual_refresh_timeout, :string, default: 'false'
    attribute :onc_visual_introspection, :string, default: 'false'
    attribute :onc_visual_data_without_omission, :string, default: 'false'
    attribute :onc_visual_multi_scopes_no_greater, :string, default: 'false'
    attribute :onc_visual_documentation, :string, default: 'false'
    attribute :onc_visual_other_resources, :string, default: 'false'
    attribute :onc_visual_jwks_cache, :string, default: 'false'
    attribute :onc_visual_patient_period, :string, default: 'false'
    attribute :onc_visual_patient_suffix, :string, default: 'false'
    attribute :onc_visual_allergy_reaction, :string, default: 'false'

    attribute :onc_visual_token_revocation, :string, default: 'false'
    attribute :onc_visual_native_application, :string, default: 'false'
  end
end
