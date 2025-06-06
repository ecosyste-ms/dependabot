class AddCreatedAtToIssuePackages < ActiveRecord::Migration[8.0]
  def change
    add_column :issue_packages, :pr_created_at, :datetime
    add_index :issue_packages, :pr_created_at
  end
end
