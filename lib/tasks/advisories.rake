namespace :advisories do
  desc "Sync advisories from API and link to issues"
  task sync: :environment do
    Advisory.sync_all
  end
  
  desc "Fast sync advisories from API without linking to issues"
  task sync_fast: :environment do
    Advisory.sync_fast
  end
  
  desc "Hourly sync task - syncs recent advisories and links to issues"
  task hourly: :environment do
    Advisory.sync_hourly
  end
end