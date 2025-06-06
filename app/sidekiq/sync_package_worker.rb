class SyncPackageWorker
  include Sidekiq::Worker

  def perform(package_id)
    Package.find_by_id(package_id)&.sync
  end
end