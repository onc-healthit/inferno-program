class AddColumnBulkRedirectTokenRequired < ActiveRecord::Migration[5.2]
  def change
    add_column :inferno_models_testing_instances, :bulk_redirect_token_required, :boolean, :default => false
  end
end
