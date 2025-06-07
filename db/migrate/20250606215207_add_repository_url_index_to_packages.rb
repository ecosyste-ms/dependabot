class AddRepositoryUrlIndexToPackages < ActiveRecord::Migration[8.0]
  def change
    add_index :packages, 'LOWER(repository_url)', name: 'index_packages_on_lower_repository_url'
  end
end
