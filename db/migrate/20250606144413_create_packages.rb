class CreatePackages < ActiveRecord::Migration[8.0]
  def change
    create_table :packages do |t|
      t.string :name, null: false
      t.string :ecosystem, null: false

      t.timestamps
    end
    
    add_index :packages, [:name, :ecosystem], unique: true
  end
end
