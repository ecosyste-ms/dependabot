class RemoveDuplicateIndexes < ActiveRecord::Migration[8.0]
  def change
    # Remove duplicate index on issue_advisories.issue_id since it's covered by the composite index
    remove_index :issue_advisories, :issue_id
    
    # Remove duplicate index on issues.repository_id since it's covered by the unique composite index
    remove_index :issues, :repository_id
  end
end
