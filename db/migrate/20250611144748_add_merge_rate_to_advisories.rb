class AddMergeRateToAdvisories < ActiveRecord::Migration[8.0]
  def change
    add_column :advisories, :merge_rate, :decimal, precision: 5, scale: 2, default: 0.0
    add_index :advisories, :merge_rate
  end
end
