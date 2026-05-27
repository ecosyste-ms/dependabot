class AddIssueStatusCountsToPackages < ActiveRecord::Migration[8.1]
  def change
    add_column :packages, :open_issues_count, :integer
    add_column :packages, :merged_issues_count, :integer
    add_column :packages, :closed_issues_count, :integer
    add_column :packages, :update_type_counts, :jsonb, default: {}
  end
end
