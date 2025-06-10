class CreateAdvisories < ActiveRecord::Migration[8.0]
  def change
    create_table :advisories do |t|
      t.string :uuid, null: false
      t.string :url
      t.string :title
      t.text :description
      t.string :origin
      t.string :severity
      t.datetime :published_at
      t.datetime :withdrawn_at
      t.string :classification
      t.float :cvss_score
      t.string :cvss_vector
      t.jsonb :references, default: []
      t.string :source_kind
      t.jsonb :identifiers, default: []
      t.string :repository_url
      t.float :blast_radius
      t.jsonb :packages, default: []
      t.float :epss_percentage
      t.float :epss_percentile

      t.timestamps
    end

    add_index :advisories, :uuid, unique: true
    add_index :advisories, :severity
    add_index :advisories, :published_at
    add_index :advisories, :repository_url
    add_index :advisories, :identifiers, using: :gin
  end
end
