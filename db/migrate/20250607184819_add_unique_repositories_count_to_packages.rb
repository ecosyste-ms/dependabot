class AddUniqueRepositoriesCountToPackages < ActiveRecord::Migration[8.0]
  def change
    add_column :packages, :unique_repositories_count, :integer, default: 0
    add_column :packages, :unique_repositories_count_past_30_days, :integer, default: 0
    
    add_index :packages, :unique_repositories_count
    add_index :packages, :unique_repositories_count_past_30_days
  end
end
