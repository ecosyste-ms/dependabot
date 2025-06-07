class AddIndexesForHomepagePerformance < ActiveRecord::Migration[8.0]
  def change
    # Index for homepage query: issues ordered by created_at DESC
    add_index :issues, :created_at, name: 'index_issues_on_created_at'
  end
end
