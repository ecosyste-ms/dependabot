class AddUniqueConstraintToIssues < ActiveRecord::Migration[8.0]
  def up
    # Add unique constraint on repository_id + number combination
    add_index :issues, [:repository_id, :number], unique: true, name: 'index_issues_on_repository_id_and_number_unique'
    
    # Also make uuid unique since it should be unique per issue
    remove_index :issues, :uuid
    add_index :issues, :uuid, unique: true
  end
  
  def down
    remove_index :issues, name: 'index_issues_on_repository_id_and_number_unique'
    remove_index :issues, :uuid
    add_index :issues, :uuid
  end
end
