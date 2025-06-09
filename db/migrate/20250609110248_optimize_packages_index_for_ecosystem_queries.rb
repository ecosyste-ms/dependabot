class OptimizePackagesIndexForEcosystemQueries < ActiveRecord::Migration[8.0]
  def change
    # Remove the existing index with wrong column order
    remove_index :packages, name: 'index_packages_on_name_and_ecosystem'
    
    # Add index with ecosystem first to optimize ecosystem filtering queries
    add_index :packages, [:ecosystem, :name], name: 'index_packages_on_ecosystem_and_name', unique: true
  end
end
