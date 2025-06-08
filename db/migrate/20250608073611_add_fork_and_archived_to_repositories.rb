class AddForkAndArchivedToRepositories < ActiveRecord::Migration[8.0]
  def change
    add_column :repositories, :fork, :boolean, default: false, null: false
    add_column :repositories, :archived, :boolean, default: false, null: false
    
    add_index :repositories, :fork
    add_index :repositories, :archived
  end
end
