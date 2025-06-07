class AddIndexOnUuidToIssues < ActiveRecord::Migration[8.0]
  def change
    add_index :issues, :uuid, name: 'index_issues_on_uuid'
  end
end
