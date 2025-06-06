class AddMetadataToPackages < ActiveRecord::Migration[8.0]
  def change
    add_column :packages, :metadata, :json, default: {}
  end
end
