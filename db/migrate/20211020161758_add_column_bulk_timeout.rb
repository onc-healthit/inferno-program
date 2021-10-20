class AddColumnBulkTimeout < ActiveRecord::Migration[5.2]
  def change
    add_column :inferno_models_testing_instances, :bulk_timeout, :integer, :default => 180
  end
end
