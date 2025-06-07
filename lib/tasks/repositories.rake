namespace :repositories do
  desc 'sync least recently synced repos'
  task sync_least_recent: :environment do 
      Repository.sync_least_recently_synced
  end
  
  desc "Enqueue repositories for sync if not synced recently"
  task sync_stale: :environment do
    count = Repository.enqueue_stale_for_sync
    puts "Enqueued #{count} repositories for sync"
  end
end