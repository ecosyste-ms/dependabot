class AddIssuesCountToAdvisories < ActiveRecord::Migration[8.0]
  def change
    add_column :advisories, :issues_count, :integer, default: 0, null: false
    add_index :advisories, :issues_count
  end
end
