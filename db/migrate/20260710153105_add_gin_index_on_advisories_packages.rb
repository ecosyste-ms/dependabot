class AddGinIndexOnAdvisoriesPackages < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :advisories, :packages, using: :gin, opclass: :jsonb_path_ops,
              name: 'index_advisories_on_packages', algorithm: :concurrently
  end
end
