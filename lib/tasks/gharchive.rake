require 'net/http'
require 'zlib'
require 'json'

namespace :gharchive do
  desc "Test import one hour of Dependabot PRs from GHArchive"
  task test_import: :environment do
    # Default to 1 hour ago if no hour specified
    hour_ago = 24.hour.ago
    
    puts "Testing GHArchive import for #{hour_ago.strftime('%Y-%m-%d-%H')}..."
    
    result = import_hour_with_stats(hour_ago)
    
    if result[:success]
      puts "\nImport complete!"
      puts "- Total Dependabot PR events: #{result[:dependabot_count]}"
      puts "- Pull request lifecycle events: #{result[:pr_count]}"
      puts "- Comment updates: #{result[:comment_count]}"
      puts "- Review events: #{result[:review_count]}"
      puts "- Review comment events: #{result[:review_comment_count]}"
      puts "- Review thread events: #{result[:review_thread_count]}"
      puts "- Issues created: #{result[:created_count]}"
      puts "- Issues updated: #{result[:updated_count]}"
    else
      puts "Import failed: #{result[:error]}"
    end
  end
  
  desc "Import past 24 hours of Dependabot PRs from GHArchive"
  task import_24_hours: :environment do
    puts "Importing past 24 hours of Dependabot PRs from GHArchive..."
    
    end_time = Time.now.utc
    start_time = 24.hours.ago.utc
    
    total_hours = 24
    successful_imports = 0
    failed_imports = 0
    total_events = 0
    total_prs = 0
    total_comments = 0
    total_reviews = 0
    total_review_comments = 0
    total_review_threads = 0
    total_created = 0
    total_updated = 0
    
    puts "Importing from #{start_time.strftime('%Y-%m-%d %H:00 UTC')} to #{end_time.strftime('%Y-%m-%d %H:00 UTC')}"
    puts "Processing #{total_hours} hours of data...\n"
    
    current_time = start_time.beginning_of_hour
    
    while current_time <= end_time
      hour_str = current_time.strftime('%Y-%m-%d-%H')
      print "Processing #{hour_str}... "
      
      begin
        result = import_hour_with_stats(current_time)
        
        if result[:success]
          successful_imports += 1
          total_events += result[:dependabot_count]
          total_prs += result[:pr_count] 
          total_comments += result[:comment_count]
          total_reviews += result[:review_count]
          total_review_comments += result[:review_comment_count]
          total_review_threads += result[:review_thread_count]
          total_created += result[:created_count]
          total_updated += result[:updated_count]
          
          puts "✅ #{result[:dependabot_count]} events, #{result[:created_count]} created, #{result[:updated_count]} updated"
        else
          failed_imports += 1
          puts "❌ #{result[:error]}"
        end
        
      rescue => e
        failed_imports += 1
        puts "❌ Exception: #{e.message}"
      end
      
      current_time += 1.hour
    end
    
    puts "\n" + "="*80
    puts "24-Hour Import Summary"
    puts "="*80
    puts "Hours processed: #{total_hours}"
    puts "Successful imports: #{successful_imports}"
    puts "Failed imports: #{failed_imports}"
    puts "Success rate: #{(successful_imports.to_f / total_hours * 100).round(1)}%"
    puts ""
    puts "Total Dependabot events: #{total_events}"
    puts "- PR lifecycle events: #{total_prs}"
    puts "- Comment updates: #{total_comments}"
    puts "- Review events: #{total_reviews}"
    puts "- Review comment events: #{total_review_comments}"
    puts "- Review thread events: #{total_review_threads}"
    puts ""
    puts "Database changes:"
    puts "- Issues created: #{total_created}"
    puts "- Issues updated: #{total_updated}"
    puts "="*80
  end

  desc "Import all Dependabot PRs from GHArchive for the last 30 days"
  task import_last_30_days: :environment do
    puts "Importing all Dependabot PRs from GHArchive for the last 30 days..."
    
    end_time = Time.now.utc
    start_time = 30.days.ago.utc
    
    total_days = 30
    successful_imports = 0
    failed_imports = 0
    total_events = 0
    total_prs = 0
    total_comments = 0
    total_reviews = 0
    total_review_comments = 0
    total_review_threads = 0
    total_created = 0
    total_updated = 0
    
    puts "Importing from #{start_time.strftime('%Y-%m-%d %H:%M UTC')} to #{end_time.strftime('%Y-%m-%d %H:%M UTC')}"
    
    current_time = start_time.beginning_of_day
    
    while current_time <= end_time
      day_str = current_time.strftime('%Y-%m-%d')
      print "Processing #{day_str}... "
      
      begin
        result = import_hour_with_stats(current_time)
        
        if result[:success]
          successful_imports += 1
          total_events += result[:dependabot_count]
          total_prs += result[:pr_count] 
          total_comments += result[:comment_count]
          total_reviews += result[:review_count]
          total_review_comments += result[:review_comment_count]
          total_review_threads += result[:review_thread_count]
          total_created += result[:created_count]
          total_updated += result[:updated_count]
          
          puts "✅ #{result[:dependabot_count]} events, #{result[:created_count]} created, #{result[:updated_count]} updated"
        else
          failed_imports += 1
          puts "❌ #{result[:error]}"
        end
        
      rescue => e
        failed_imports += 1
        puts "❌ Exception: #{e.message}"
      end
      
      current_time += 1.day
    end
    
    puts "\n" + "="*80
    puts "30-Day Import Summary"
    puts "="*80
    puts "Days processed: #{total_days}"
    puts "Successful imports: #{successful_imports}"
    puts "Failed imports: #{failed_imports}"
    puts "Success rate: #{(successful_imports.to_f / total_days * 100).round(1)}%"
    puts ""
        puts "Total Dependabot events: #{total_events}"
    puts "- PR lifecycle events: #{total_prs}"
    puts "- Comment updates: #{total_comments}"
    puts "- Review events: #{total_reviews}"
    puts "- Review comment events: #{total_review_comments}"
    puts "- Review thread events: #{total_review_threads}"
    puts ""
    puts "Database changes:"
    puts "- Issues created: #{total_created}"
    puts "- Issues updated: #{total_updated}"
    puts "="*80
  end
  
  desc "Import specific hour of Dependabot PRs from GHArchive (HOUR=2024-01-01-14)"
  task import_hour: :environment do
    hour_string = ENV['HOUR']
    
    if hour_string.nil?
      puts "Please specify HOUR in format YYYY-MM-DD-HH, e.g., rake gharchive:import_hour HOUR=2024-01-01-14"
      exit 1
    end
    
    begin
      # Parse the hour string
      year, month, day, hour = hour_string.split('-').map(&:to_i)
      datetime = Time.new(year, month, day, hour, 0, 0, 'UTC')
      
      puts "Importing GHArchive data for #{datetime.strftime('%Y-%m-%d %H:00 UTC')}..."
      
      result = import_hour_with_stats(datetime)
      
      if result[:success]
        puts "\nImport complete!"
        puts "- Total Dependabot PR events: #{result[:dependabot_count]}"
        puts "- Pull request lifecycle events: #{result[:pr_count]}"
        puts "- Comment updates: #{result[:comment_count]}"
        puts "- Review events: #{result[:review_count]}"
        puts "- Review comment events: #{result[:review_comment_count]}"
        puts "- Review thread events: #{result[:review_thread_count]}"
        puts "- Issues created: #{result[:created_count]}"
        puts "- Issues updated: #{result[:updated_count]}"
      else
        puts "Import failed: #{result[:error]}"
        exit 1
      end
    rescue => e
      puts "Error parsing hour '#{hour_string}': #{e.message}"
      puts "Expected format: YYYY-MM-DD-HH (e.g., 2024-01-01-14)"
      exit 1
    end
  end
  
  private
  
  def map_github_pr_data(pr_data, repository)
    # Common mapping logic for all PR data
    {
      node_id: pr_data['node_id'],
      number: pr_data['number'],
      title: pr_data['title'],
      body: pr_data['body'],
      state: pr_data['state'],
      locked: pr_data['locked'] || false,
      comments_count: pr_data['comments'] || 0,
      created_at: Time.parse(pr_data['created_at']),
      updated_at: Time.parse(pr_data['updated_at']),
      closed_at: pr_data['closed_at'] ? Time.parse(pr_data['closed_at']) : nil,
      user: pr_data['user']['login'],
      labels: (pr_data['labels'] || []).map { |l| l['name'] },
      assignees: (pr_data['assignees'] || []).map { |a| a['login'] },
      pull_request: true,
      author_association: pr_data['author_association'],
      state_reason: pr_data['state_reason'],
      merged_at: pr_data['merged_at'] ? Time.parse(pr_data['merged_at']) : nil,
      draft: pr_data['draft'],
      mergeable: pr_data['mergeable'],
      mergeable_state: pr_data['mergeable_state'],
      rebaseable: pr_data['rebaseable'],
      review_comments_count: pr_data['review_comments'] || 0,
      commits_count: pr_data['commits'] || 0,
      additions: pr_data['additions'] || 0,
      deletions: pr_data['deletions'] || 0,
      changed_files: pr_data['changed_files'] || 0,
      host_id: repository.host_id
    }
  end
  
  def save_issue_with_metadata(issue, was_new, created_count, updated_count)
    # Calculate time to close if closed
    if issue.closed_at.present?
      issue.time_to_close = issue.closed_at - issue.created_at
    end
    
    # Save the issue
    if issue.save
      # Update Dependabot metadata after saving
      issue.update_dependabot_metadata
      
      if was_new
        created_count += 1
      else
        updated_count += 1
      end
    end
    
    [created_count, updated_count]
  end
  
  def import_hour_with_stats(datetime)
    # Wrapper that returns structured stats for batch processing
    begin
      filename = "#{datetime.year}-#{datetime.month.to_s.rjust(2, '0')}-#{datetime.day.to_s.rjust(2, '0')}-#{datetime.hour}.json.gz"
      url = "http://data.gharchive.org/#{filename}"
      
      uri = URI(url)
      response = Net::HTTP.get_response(uri)
      
      if response.code != '200'
        return {
          success: false,
          error: "HTTP #{response.code}"
        }
      end
      
      # Decompress the gzipped data
      decompressed_data = Zlib::GzipReader.new(StringIO.new(response.body)).read
      
      dependabot_count = 0
      pr_count = 0
      comment_count = 0
      review_count = 0
      review_comment_count = 0
      review_thread_count = 0
      created_count = 0
      updated_count = 0
      
      # Process each line (each line is a JSON event)
      decompressed_data.each_line do |line|
        event = JSON.parse(line.strip)
        
        # Only process PR-related events
        pr_event_types = ['PullRequestEvent', 'IssueCommentEvent', 'PullRequestReviewEvent', 'PullRequestReviewCommentEvent', 'PullRequestReviewThreadEvent']
        next unless pr_event_types.include?(event['type'])
        
        event_type = event['type']
        repo_name = event['repo']['name']
        
        if event_type == 'PullRequestEvent'
          # Process key PR lifecycle actions
          allowed_actions = ['opened', 'closed', 'synchronize', 'reopened', 'edited']
          action = event['payload']['action']
          next unless allowed_actions.include?(action)
          
          # Extract the pull request data
          pr_data = event['payload']['pull_request']
          
          # Only process PRs originally opened by Dependabot (check PR author, not event actor)
          pr_author = pr_data['user']['login']
          next unless Issue::DEPENDABOT_USERNAMES.include?(pr_author)
          
          dependabot_count += 1
          pr_count += 1
          
          # Find or create the repository
          repository = find_or_create_repository(repo_name)
          next unless repository
          
          # Find or create the issue (PRs are stored as issues)
          issue = repository.issues.find_or_initialize_by(uuid: pr_data['id'])
          
          # Skip if this is an older event for an issue we already have
          if issue.persisted? && issue.updated_at && issue.updated_at >= Time.parse(pr_data['updated_at'])
            next
          end
          
          was_new = issue.new_record?
          
          # Map the GitHub data to our issue format
          issue.assign_attributes(map_github_pr_data(pr_data, repository))
          
          # Save and update counts
          created_count, updated_count = save_issue_with_metadata(issue, was_new, created_count, updated_count)
          
        elsif event_type == 'IssueCommentEvent'
          # For comments, check if it's on a pull request
          issue_data = event['payload']['issue']
          next unless issue_data['pull_request'] # Only comments on PRs
          
          # Only process comments on PRs originally opened by Dependabot
          pr_author = issue_data['user']['login']
          next unless Issue::DEPENDABOT_USERNAMES.include?(pr_author)
          
          # For comments, we'll update the PR's comment count but won't create new issues
          # Just find existing issue and update comment count
          repository = find_or_create_repository(repo_name)
          next unless repository
          
          existing_issue = repository.issues.find_by(uuid: issue_data['id'])
          if existing_issue
            existing_issue.update(comments_count: issue_data['comments'])
            comment_count += 1
          else
            # Create missing PR from comment event
            issue = repository.issues.find_or_initialize_by(uuid: issue_data['id'])
            was_new = issue.new_record?
            
            # Map issue data to our format (similar to PR data mapping)
            issue.assign_attributes(map_github_pr_data(issue_data, repository))
            
            # Save and update counts
            created_count, updated_count = save_issue_with_metadata(issue, was_new, created_count, updated_count)
            comment_count += 1 if was_new
          end
          
        elsif event_type == 'PullRequestReviewEvent'
          # Handle PR review events (approved, changes_requested, commented, etc.)
          pr_data = event['payload']['pull_request']
          
          # Only process reviews on PRs originally opened by Dependabot
          pr_author = pr_data['user']['login']
          next unless Issue::DEPENDABOT_USERNAMES.include?(pr_author)
          
          # Find or create the PR from review event
          repository = find_or_create_repository(repo_name)
          next unless repository
          
          existing_issue = repository.issues.find_by(uuid: pr_data['id'])
          if existing_issue
            # Update any relevant fields from the PR data
            existing_issue.update(
              comments_count: pr_data['comments'] || existing_issue.comments_count,
              updated_at: Time.parse(pr_data['updated_at'])
            )
            review_count += 1
          else
            # Create missing PR from review event
            issue = create_pr_from_data(repository, pr_data)
            if issue&.persisted?
              created_count += 1
              review_count += 1
            end
          end
          
        elsif event_type == 'PullRequestReviewCommentEvent'
          # Handle line-specific review comments
          pr_data = event['payload']['pull_request']
          
          # Only process review comments on PRs originally opened by Dependabot
          pr_author = pr_data['user']['login']
          next unless Issue::DEPENDABOT_USERNAMES.include?(pr_author)
          
          # Find or create the PR from review comment event
          repository = find_or_create_repository(repo_name)
          next unless repository
          
          existing_issue = repository.issues.find_by(uuid: pr_data['id'])
          if existing_issue
            # Update comment count and updated_at
            existing_issue.update(
              comments_count: pr_data['comments'] || existing_issue.comments_count,
              updated_at: Time.parse(pr_data['updated_at'])
            )
            review_comment_count += 1
          else
            # Create missing PR from review comment event
            issue = create_pr_from_data(repository, pr_data)
            if issue&.persisted?
              created_count += 1
              review_comment_count += 1
            end
          end
          
        elsif event_type == 'PullRequestReviewThreadEvent'
          # Handle review thread events (resolved, unresolved)
          pr_data = event['payload']['pull_request']
          
          # Only process review threads on PRs originally opened by Dependabot
          pr_author = pr_data['user']['login']
          next unless Issue::DEPENDABOT_USERNAMES.include?(pr_author)
          
          # Find or create the PR from review thread event
          repository = find_or_create_repository(repo_name)
          next unless repository
          
          existing_issue = repository.issues.find_by(uuid: pr_data['id'])
          if existing_issue
            # Update updated_at timestamp
            existing_issue.update(updated_at: Time.parse(pr_data['updated_at']))
            review_thread_count += 1
          else
            # Create missing PR from review thread event
            issue = create_pr_from_data(repository, pr_data)
            if issue&.persisted?
              created_count += 1
              review_thread_count += 1
            end
          end
        end
      end
      
      return {
        success: true,
        dependabot_count: dependabot_count,
        pr_count: pr_count,
        comment_count: comment_count,
        review_count: review_count,
        review_comment_count: review_comment_count,
        review_thread_count: review_thread_count,
        created_count: created_count,
        updated_count: updated_count
      }
      
    rescue => e
      return {
        success: false,
        error: e.message
      }
    end
  end
  
  def find_or_create_repository(repo_name)
    owner_name, repo_name_only = repo_name.split('/', 2)
    return nil unless owner_name && repo_name_only
    
    # Find GitHub host
    github_host = Host.find_by(name: 'GitHub')
    unless github_host
      puts "GitHub host not found. Please create it first."
      return nil
    end
    
    # Find or create repository
    repository = Repository.find_by(full_name: repo_name, host: github_host)
    unless repository
      puts "Repository #{repo_name} not found in database. Creating placeholder..."
      repository = Repository.create!(
        full_name: repo_name,
        owner: owner_name,
        host: github_host
      )
    end
    
    repository
  end
  
  def create_pr_from_data(repository, pr_data)
    # Create issue from PR data (reusable for all review events)
    issue = repository.issues.find_or_initialize_by(uuid: pr_data['id'])
    
    # Map PR data to our format
    issue.assign_attributes(map_github_pr_data(pr_data, repository))
    
    # Calculate time to close if closed
    if issue.closed_at.present?
      issue.time_to_close = issue.closed_at - issue.created_at
    end
    
    # Save and return the issue
    if issue.save
      # Update Dependabot metadata after saving
      issue.update_dependabot_metadata
      issue
    else
      puts "Failed to save issue from review event #{pr_data['id']}: #{issue.errors.full_messages.join(', ')}"
      nil
    end
  end
end