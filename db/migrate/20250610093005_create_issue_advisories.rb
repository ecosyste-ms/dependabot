class CreateIssueAdvisories < ActiveRecord::Migration[8.0]
  def change
    create_table :issue_advisories do |t|
      t.references :issue, null: false, foreign_key: true
      t.references :advisory, null: false, foreign_key: true

      t.timestamps
    end

    add_index :issue_advisories, [:issue_id, :advisory_id], unique: true
    add_index :issue_advisories, :created_at
  end
end
