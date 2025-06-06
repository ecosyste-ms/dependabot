class AddGitHubFieldsToIssues < ActiveRecord::Migration[8.0]
  def change
    add_column :issues, :body, :text
    add_column :issues, :draft, :boolean
    add_column :issues, :mergeable, :boolean
    add_column :issues, :mergeable_state, :string
    add_column :issues, :rebaseable, :boolean
    add_column :issues, :review_comments_count, :integer
    add_column :issues, :commits_count, :integer
    add_column :issues, :additions, :integer
    add_column :issues, :deletions, :integer
    add_column :issues, :changed_files, :integer
  end
end
