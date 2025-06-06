class AddRepositoryUrlToPackages < ActiveRecord::Migration[8.0]
  def change
    add_column :packages, :repository_url, :string
  end
end
