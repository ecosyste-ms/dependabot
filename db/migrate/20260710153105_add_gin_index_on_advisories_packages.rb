class AddGinIndexOnAdvisoriesPackages < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    remove_index :advisories, name: 'index_advisories_on_packages', if_exists: true, algorithm: :concurrently
    add_index :advisories, :packages, using: :gin, opclass: :jsonb_path_ops,
              name: 'index_advisories_on_packages', algorithm: :concurrently
  end

  def down
    remove_index :advisories, name: 'index_advisories_on_packages', if_exists: true, algorithm: :concurrently
  end
end
