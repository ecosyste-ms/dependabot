class RemoveDuplicateIssueIdIndexFromIssuePackages < ActiveRecord::Migration[8.0]
  def change
    remove_index :issue_packages, :issue_id
  end
end
