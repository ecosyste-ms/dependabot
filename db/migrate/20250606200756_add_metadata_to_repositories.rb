class AddMetadataToRepositories < ActiveRecord::Migration[8.0]
  def change
    add_column :repositories, :metadata, :json, default: {}
  end
end
