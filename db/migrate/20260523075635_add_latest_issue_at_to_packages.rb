class AddLatestIssueAtToPackages < ActiveRecord::Migration[8.1]
  def change
    add_column :packages, :latest_issue_at, :datetime
  end
end
