class AddColumnAttachmentRequiresToken < ActiveRecord::Migration[5.2]
  def change
    add_column :inferno_models_testing_instances, 
      :attachment_requires_token, 
      :boolean, 
      :default => true
  end
end
