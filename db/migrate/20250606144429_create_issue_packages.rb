class CreateIssuePackages < ActiveRecord::Migration[8.0]
  def change
    create_table :issue_packages do |t|
      t.references :issue, null: false, foreign_key: true
      t.references :package, null: false, foreign_key: true
      t.string :old_version
      t.string :new_version
      t.string :path
      t.string :update_type

      t.timestamps
    end
    
    add_index :issue_packages, [:issue_id, :package_id], unique: true
  end
end
