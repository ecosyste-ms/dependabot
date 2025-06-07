class CreateImports < ActiveRecord::Migration[8.0]
  def change
    create_table :imports do |t|
      t.string :filename
      t.datetime :imported_at
      t.integer :dependabot_count
      t.integer :pr_count
      t.integer :comment_count
      t.integer :review_count
      t.integer :review_comment_count
      t.integer :review_thread_count
      t.integer :created_count
      t.integer :updated_count
      t.boolean :success
      t.text :error_message

      t.timestamps
    end
  end
end
