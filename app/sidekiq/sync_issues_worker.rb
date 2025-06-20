class SyncIssuesWorker
  include Sidekiq::Worker

  def perform(job_id)
    Job.find_by_id!(job_id).perform_issue_syncing
  end
end