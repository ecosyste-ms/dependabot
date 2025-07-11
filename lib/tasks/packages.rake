namespace :packages do
  desc "Reset counter cache for packages.issues_count"
  task reset_counters: :environment do
    puts "Resetting counter cache for packages.issues_count..."
    
    Package.find_each do |package|
      count = package.issue_packages.count
      package.update_column(:issues_count, count)
      print "."
    end
    
    puts "\nCounter cache reset complete!"
  end
  
  desc "Populate pr_created_at field for existing issue_packages"
  task populate_pr_created_at: :environment do
    puts "Populating pr_created_at field for issue_packages..."
    
    IssuePackage.includes(:issue).where(pr_created_at: nil).find_each do |issue_package|
      issue_package.update_column(:pr_created_at, issue_package.issue.created_at)
      print "."
    end
    
    puts "\nPR created_at population complete!"
  end
  
  desc "Update dependency metadata for all issues"
  task update_metadata: :environment do
    puts "Updating dependency metadata for all issues..."
    
    total_count = Issue.count
    updated_count = 0
    
    puts "Found #{total_count} issues to process..."
    
    Issue.find_each.with_index do |issue, index|
      old_metadata = issue.dependency_metadata
      issue.update_dependabot_metadata
      
      if issue.dependency_metadata != old_metadata
        updated_count += 1
      end
      
      if (index + 1) % 1000 == 0
        puts "\nProcessed #{index + 1}/#{total_count} issues (#{updated_count} updated)..."
      else
        print "."
      end
    end
    
    puts "\nDependency metadata update complete!"
    puts "Total issues processed: #{total_count}"
    puts "Issues with updated metadata: #{updated_count}"
    puts "Issues with new metadata: #{Issue.with_dependency_metadata.count}"
    puts "Issues without metadata: #{Issue.without_dependency_metadata.count}"
  end
  
  desc "Enqueue packages for sync if not synced recently"
  task sync_stale: :environment do
    count = Package.enqueue_stale_for_sync
    puts "Enqueued #{count} packages for sync"
  end
  
  desc "Update unique repositories counts for all packages"
  task update_unique_repositories_counts: :environment do
    puts "Updating unique repositories counts for all packages..."
    
    total_count = Package.count
    processed_count = 0
    
    puts "Found #{total_count} packages to process..."
    
    Package.find_each.with_index do |package, index|
      package.update_unique_repositories_counts!
      processed_count += 1
      
      if (index + 1) % 100 == 0
        puts "\nProcessed #{index + 1}/#{total_count} packages..."
      else
        print "."
      end
    end
    
    puts "\nUnique repositories counts update complete!"
    puts "Total packages processed: #{processed_count}"
  end
end