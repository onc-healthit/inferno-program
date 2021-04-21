# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2021_04_21_162516) do

  create_table "inferno_models_information_messages", id: :string, limit: 500, force: :cascade do |t|
    t.text "message"
    t.string "test_result_id", limit: 500, null: false
    t.index ["test_result_id"], name: "index_inferno_models_information_messages_test_result"
  end

  create_table "inferno_models_request_response_test_results", primary_key: ["request_response_id", "test_result_id"], force: :cascade do |t|
    t.string "request_response_id", limit: 500, null: false
    t.string "test_result_id", limit: 500, null: false
  end

  create_table "inferno_models_request_responses", primary_key: "request_index", force: :cascade do |t|
    t.string "id", limit: 500, null: false
    t.string "request_method", limit: 500
    t.text "request_url"
    t.text "request_headers"
    t.text "request_payload"
    t.integer "response_code"
    t.text "response_headers"
    t.text "response_body"
    t.string "direction", limit: 500
    t.string "instance_id", limit: 500
    t.datetime "timestamp"
    t.index ["request_index"], name: "unique_inferno_models_request_responses_request_index", unique: true
  end

  create_table "inferno_models_resource_references", primary_key: "resource_index", force: :cascade do |t|
    t.string "id", limit: 500, null: false
    t.string "resource_type", limit: 500
    t.string "resource_id", limit: 500
    t.string "profile", limit: 500
    t.datetime "created_at"
    t.string "testing_instance_id", limit: 50, null: false
    t.index ["resource_index"], name: "unique_inferno_models_resource_references_resource_index", unique: true
    t.index ["testing_instance_id"], name: "index_inferno_models_resource_references_testing_instance"
  end

  create_table "inferno_models_sequence_results", id: :string, limit: 500, force: :cascade do |t|
    t.text "name"
    t.string "result", limit: 500
    t.text "test_case_id"
    t.text "test_set_id"
    t.text "redirect_to_url"
    t.text "wait_at_endpoint"
    t.boolean "expect_redirect_failure", default: false
    t.integer "required_passed", default: 0
    t.integer "required_total", default: 0
    t.integer "error_count", default: 0
    t.integer "todo_count", default: 0
    t.integer "skip_count", default: 0
    t.integer "optional_passed", default: 0
    t.integer "optional_total", default: 0
    t.integer "required_omitted", default: 0
    t.integer "optional_omitted", default: 0
    t.string "app_version", limit: 500
    t.boolean "required", default: true
    t.text "input_params"
    t.text "output_results"
    t.text "next_sequences"
    t.text "next_test_cases"
    t.datetime "created_at"
    t.string "testing_instance_id", limit: 50, null: false
    t.index ["testing_instance_id"], name: "index_inferno_models_sequence_results_testing_instance"
  end

  create_table "inferno_models_server_capabilities", id: :string, limit: 50, force: :cascade do |t|
    t.text "capabilities"
    t.string "testing_instance_id", limit: 50, null: false
    t.index ["testing_instance_id"], name: "index_inferno_models_server_capabilities_testing_instance"
  end

  create_table "inferno_models_test_results", id: :string, limit: 500, force: :cascade do |t|
    t.string "test_id", limit: 500
    t.text "ref"
    t.text "name"
    t.string "result", limit: 500
    t.text "message"
    t.text "details"
    t.boolean "required", default: true
    t.text "url"
    t.text "description"
    t.integer "test_index"
    t.datetime "created_at"
    t.string "versions", limit: 500
    t.text "wait_at_endpoint"
    t.text "redirect_to_url"
    t.boolean "expect_redirect_failure", default: false
    t.string "sequence_result_id", limit: 500, null: false
    t.index ["sequence_result_id"], name: "index_inferno_models_test_results_sequence_result"
  end

  create_table "inferno_models_test_warnings", id: :string, limit: 500, force: :cascade do |t|
    t.text "message"
    t.string "test_result_id", limit: 500, null: false
    t.index ["test_result_id"], name: "index_inferno_models_test_warnings_test_result"
  end

  create_table "inferno_models_testing_instances", id: :string, limit: 50, force: :cascade do |t|
    t.text "url"
    t.string "name", limit: 50
    t.boolean "confidential_client"
    t.text "client_id"
    t.text "client_secret"
    t.text "base_url"
    t.string "client_name", limit: 50, default: "Inferno"
    t.text "scopes"
    t.text "received_scopes"
    t.string "encounter_id", limit: 50
    t.string "launch_type", limit: 50
    t.text "state"
    t.string "selected_module", limit: 50
    t.boolean "conformance_checked"
    t.text "oauth_authorize_endpoint"
    t.text "oauth_token_endpoint"
    t.text "oauth_register_endpoint"
    t.string "fhir_format", limit: 50
    t.boolean "dynamically_registered"
    t.string "client_endpoint_key", limit: 50
    t.text "token"
    t.datetime "token_retrieved_at"
    t.integer "token_expires_in"
    t.text "id_token"
    t.text "refresh_token"
    t.datetime "created_at"
    t.text "oauth_introspection_endpoint"
    t.text "resource_id"
    t.text "resource_secret"
    t.text "introspect_token"
    t.text "introspect_refresh_token"
    t.text "standalone_launch_script"
    t.text "ehr_launch_script"
    t.text "manual_registration_script"
    t.text "initiate_login_uri"
    t.text "redirect_uris"
    t.text "dynamic_registration_token"
    t.string "must_support_confirmed", limit: 50, default: ""
    t.text "patient_ids"
    t.text "group_id"
    t.boolean "data_absent_code_found"
    t.boolean "data_absent_extension_found"
    t.text "device_codes"
    t.text "bulk_url"
    t.text "bulk_token_endpoint"
    t.text "bulk_client_id"
    t.text "bulk_system_export_endpoint"
    t.text "bulk_patient_export_endpoint"
    t.text "bulk_group_export_endpoint"
    t.text "bulk_fastest_resource"
    t.string "bulk_requires_auth", limit: 50
    t.string "bulk_since_param", limit: 50
    t.text "bulk_jwks_url_auth"
    t.text "bulk_jwks_auth"
    t.string "bulk_encryption_method", limit: 50, default: "ES384"
    t.text "bulk_data_jwks"
    t.text "bulk_access_token"
    t.string "bulk_lines_to_validate", limit: 50
    t.text "bulk_status_output"
    t.text "bulk_patient_ids_in_group"
    t.text "bulk_device_types_in_group"
    t.string "bulk_stop_after_must_support", limit: 50, default: "true"
    t.text "bulk_scope"
    t.boolean "disable_bulk_data_require_access_token_test", default: false
    t.text "bulk_public_key"
    t.text "bulk_private_key"
    t.text "onc_sl_url"
    t.boolean "onc_sl_confidential_client"
    t.text "onc_sl_client_id"
    t.text "onc_sl_client_secret"
    t.text "onc_sl_scopes"
    t.text "onc_sl_expected_resources"
    t.text "onc_sl_token"
    t.text "onc_sl_refresh_token"
    t.text "onc_sl_patient_id"
    t.text "onc_sl_oauth_authorize_endpoint"
    t.text "onc_sl_oauth_token_endpoint"
    t.text "onc_public_client_id"
    t.text "onc_public_scopes"
    t.text "onc_patient_ids"
    t.string "onc_visual_single_registration", limit: 50, default: "false"
    t.text "onc_visual_single_registration_notes"
    t.string "onc_visual_multi_registration", limit: 50, default: "false"
    t.text "onc_visual_multi_registration_notes"
    t.string "onc_visual_single_scopes", limit: 50, default: "false"
    t.text "onc_visual_single_scopes_notes"
    t.string "onc_visual_single_offline_access", limit: 50, default: "false"
    t.text "onc_visual_single_offline_access_notes"
    t.string "onc_visual_refresh_timeout", limit: 50, default: "false"
    t.text "onc_visual_refresh_timeout_notes"
    t.string "onc_visual_introspection", limit: 50, default: "false"
    t.text "onc_visual_introspection_notes"
    t.string "onc_visual_data_without_omission", limit: 50, default: "false"
    t.text "onc_visual_data_without_omission_notes"
    t.string "onc_visual_multi_scopes_no_greater", limit: 50, default: "false"
    t.text "onc_visual_multi_scopes_no_greater_notes"
    t.string "onc_visual_documentation", limit: 50, default: "false"
    t.text "onc_visual_documentation_notes"
    t.string "onc_visual_other_resources", limit: 50, default: "false"
    t.text "onc_visual_other_resources_notes"
    t.string "onc_visual_jwks_cache", limit: 50, default: "false"
    t.text "onc_visual_jwks_cache_notes"
    t.string "onc_visual_patient_period", limit: 50, default: "false"
    t.text "onc_visual_patient_period_notes"
    t.string "onc_visual_patient_suffix", limit: 50, default: "false"
    t.text "onc_visual_patient_suffix_notes"
    t.string "onc_visual_allergy_reaction", limit: 50, default: "false"
    t.text "onc_visual_allergy_reaction_notes"
    t.string "onc_visual_token_revocation", limit: 50, default: "false"
    t.text "onc_visual_token_revocation_notes"
    t.string "onc_visual_native_application", limit: 50, default: "false"
    t.text "onc_visual_native_application_notes"
  end

end
