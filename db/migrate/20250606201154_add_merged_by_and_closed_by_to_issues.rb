class AddMergedByAndClosedByToIssues < ActiveRecord::Migration[8.0]
  def change
    add_column :issues, :merged_by, :string
    add_column :issues, :closed_by, :string
  end
end
