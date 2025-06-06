class SyncRepositoryWorker
  include Sidekiq::Worker

  def perform(repository_id)
    Repository.find_by_id(repository_id)&.sync
  end
end