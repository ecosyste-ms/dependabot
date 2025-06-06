class AddIssuesCountToPackages < ActiveRecord::Migration[8.0]
  def change
    add_column :packages, :issues_count, :integer, default: 0, null: false
    add_index :packages, :issues_count
  end
end
