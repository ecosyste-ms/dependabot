class Import < ApplicationRecord
  require 'net/http'
  require 'zlib'
  require 'json'
  
  validates :filename, presence: true, uniqueness: true
  
  def url
    "http://data.gharchive.org/#{filename}"
  end

  def self.url_for(datetime)
    filename = "#{datetime.year}-#{datetime.month.to_s.rjust(2, '0')}-#{datetime.day.to_s.rjust(2, '0')}-#{datetime.hour}.json.gz"
    "http://data.gharchive.org/#{filename}"
  end

  def datetime
    # Parse filename like "2024-01-01-14.json.gz" to datetime
    parts = filename.split('.').first.split('-').map(&:to_i)
    DateTime.new(parts[0], parts[1], parts[2], parts[3])
  end
  
  def retry!
    # Clear previous error state
    update!(
      success: nil,
      error_message: nil,
      **self.class.default_stats.except(:affected_package_ids)
    )
    
    # Retry the import
    result = self.class.import_hour(datetime)
    
    # Update the record with new results
    if result[:success]
      update!(
        imported_at: Time.current,
        success: true,
        **result.except(:success)
      )
    else
      update!(
        imported_at: Time.current,
        success: false,
        error_message: result[:error]
      )
    end
    
    result
  end
  
  def self.already_imported?(datetime)
    filename = "#{datetime.year}-#{datetime.month.to_s.rjust(2, '0')}-#{datetime.day.to_s.rjust(2, '0')}-#{datetime.hour}.json.gz"
    exists?(filename: filename)
  end
  
  def self.failed_imports_last_24_hours
    where(success: false)
      .where('imported_at >= ?', 24.hours.ago)
      .order(imported_at: :desc)
  end
  
  def self.import_hour(datetime)
    filename = "#{datetime.year}-#{datetime.month.to_s.rjust(2, '0')}-#{datetime.day.to_s.rjust(2, '0')}-#{datetime.hour}.json.gz"
    
    begin
      url = "http://data.gharchive.org/#{filename}"
      uri = URI(url)
      response = Net::HTTP.get_response(uri)
      
      if response.code != '200'
        error_msg = "HTTP #{response.code}"
        # Don't record 404s - file doesn't exist yet, will retry later
        if response.code != '404'
          create_failed_import(filename, error_msg)
        end
        return { success: false, error: error_msg }
      end
      
      # Decompress and process data
      decompressed_data = Zlib::GzipReader.new(StringIO.new(response.body)).read
      stats = process_gharchive_data(decompressed_data)
      
      # Update package counts for affected packages
      update_package_counts(stats)
      
      # Update merge rates for advisories with issues
      Advisory.update_merge_rates_for_advisories_with_issues
      
      # Record successful import (skip if already exists)
      unless exists?(filename: filename)
        # Extract only the database fields (exclude affected_package_ids Set)
        db_stats = stats.except(:affected_package_ids)
        create!(
          filename: filename,
          imported_at: Time.current,
          **db_stats,
          success: true
        )
      end
      
      { success: true, **stats.except(:affected_package_ids) }

    rescue => e
      error_details = "#{e.class}: #{e.message}\n\nBacktrace:\n#{e.backtrace.first(15).join("\n")}"
      Rails.logger.error "Import failed for #{filename}: #{error_details}"
      # Truncate if too long for database field
      truncated_error = error_details.length > 5000 ? "#{error_details[0..4900]}...\n[truncated]" : error_details
      create_failed_import(filename, truncated_error)
      { success: false, error: e.message }
    end
  end
  
  def self.import_range(start_time, end_time)
    results = {
      total_hours: 0,
      successful_imports: 0,
      failed_imports: 0,
      skipped_imports: 0,
      **default_stats
    }
    
    current_time = start_time.beginning_of_hour
    
    while current_time <= end_time
      results[:total_hours] += 1
      hour_str = current_time.strftime('%Y-%m-%d %H:00 UTC')
      
      if already_imported?(current_time)
        puts "⏭️  Skipping #{hour_str} (already imported)"
        results[:skipped_imports] += 1
        results[:successful_imports] += 1
        current_time += 1.hour
        next
      end
      
      puts "📥 Processing #{hour_str}..."
      result = import_hour(current_time)
      
      if result[:success]
        puts "✅ #{hour_str} - Found #{result[:dependabot_count]} Dependabot events"
        results[:successful_imports] += 1
        add_stats_to_totals(results, result)
      else
        puts "❌ #{hour_str} - Failed: #{result[:error]}"
        results[:failed_imports] += 1
      end
      
      current_time += 1.hour
    end
    
    results
  end
  
  private
  
  def self.find_or_build_issue_by_uuid(repository, uuid)
    # Find issue globally by UUID first
    issue = Issue.find_by(uuid: uuid)
    
    if issue
      # If issue exists but belongs to a different repository, return nil
      if issue.repository_id != repository.id
        Rails.logger.warn "Issue UUID #{uuid} already exists for repository #{issue.repository_id}, but event is for repository #{repository.id}. Skipping."
        return nil
      end
      # Return the existing issue for this repository
      issue
    else
      # Build new issue for this repository
      repository.issues.build(uuid: uuid)
    end
  end
  
  def self.sanitize_string(str)
    return nil if str.nil?
    # Remove null bytes that cause PostgreSQL errors
    str.delete("\0")
  end
  
  def self.create_failed_import(filename, error_message)
    # Only create if one doesn't already exist
    return if exists?(filename: filename)
    
    create!(
      filename: filename,
      imported_at: Time.current,
      **default_stats.except(:affected_package_ids),
      success: false,
      error_message: error_message
    )
  end
  
  def self.default_stats
    {
      dependabot_count: 0,
      pr_count: 0,
      comment_count: 0,
      review_count: 0,
      review_comment_count: 0,
      review_thread_count: 0,
      created_count: 0,
      updated_count: 0,
      affected_package_ids: Set.new
    }
  end
  
  def self.add_stats_to_totals(totals, stats)
    default_stats.keys.each do |key|
      if key == :affected_package_ids
        totals[key] ||= Set.new
        totals[key].merge(stats[key] || Set.new)
      else
        totals[key] ||= 0
        totals[key] += stats[key] || 0
      end
    end
  end
  
  def self.process_gharchive_data(data)
    stats = default_stats
    
    data.each_line do |line|
      event = JSON.parse(line.strip)
      
      # Only process PR-related events
      pr_event_types = ['PullRequestEvent', 'IssueCommentEvent', 'PullRequestReviewEvent', 'PullRequestReviewCommentEvent', 'PullRequestReviewThreadEvent']
      next unless pr_event_types.include?(event['type'])
      
      next unless event['repo']
      repo_name = event['repo']['name']
      next unless repo_name
      
      case event['type']
      when 'PullRequestEvent'
        process_pr_event(event, repo_name, stats)
      when 'IssueCommentEvent'
        process_comment_event(event, repo_name, stats)
      when 'PullRequestReviewEvent'
        process_review_event(event, repo_name, stats)
      when 'PullRequestReviewCommentEvent'
        process_review_comment_event(event, repo_name, stats)
      when 'PullRequestReviewThreadEvent'
        process_review_thread_event(event, repo_name, stats)
      end
    end
    
    stats
  end
  
  def self.process_pr_event(event, repo_name, stats)
    allowed_actions = ['opened', 'closed', 'synchronize', 'reopened', 'edited']
    action = event['payload']['action']
    return unless allowed_actions.include?(action)

    pr_data = event['payload']['pull_request']
    return unless pr_data

    # Check actor field for Dependabot (GHArchive format changed, actor is more reliable)
    actor = event['actor']
    return unless actor && actor['login']

    pr_author = actor['login']

    # Only process Dependabot PRs
    return unless pr_author&.include?('dependabot')
    
    stats[:dependabot_count] += 1
    stats[:pr_count] += 1
    
    repository = find_or_create_repository(repo_name)
    return unless repository
    
    issue = find_or_build_issue_by_uuid(repository, pr_data['id'])
    return unless issue

    # Skip if this is an older event (only applicable when we have timestamp data - old format)
    if issue.persisted? && issue.updated_at && pr_data['updated_at']
      event_time = Time.parse(pr_data['updated_at'])
      if issue.updated_at >= event_time
        return
      end
    end

    was_new = issue.new_record?
    # Only update if we have new data or it's a new record
    # For new format with limited data, we still want to create the record
    issue.assign_attributes(map_github_pr_data(pr_data, repository, pr_author))

    if save_issue_with_metadata(issue, stats)
      if was_new
        stats[:created_count] += 1
      else
        stats[:updated_count] += 1
      end
    end
  end
  
  def self.process_comment_event(event, repo_name, stats)
    payload = event['payload']
    return unless payload && payload['issue']

    issue_data = payload['issue']
    return unless issue_data['pull_request']

    # Determine if this is a Dependabot PR
    # Check if issue_data has user (should be present in both formats for IssueCommentEvent)
    return unless issue_data['user']

    pr_author = issue_data['user']['login']

    # Only process comments on Dependabot PRs
    return unless pr_author&.include?('dependabot')
    
    repository = find_or_create_repository(repo_name)
    return unless repository
    
    issue = find_or_build_issue_by_uuid(repository, issue_data['id'])
    return unless issue
    
    if issue.persisted?
      issue.update(comments_count: issue_data['comments'])
      stats[:comment_count] += 1
    else
      issue.assign_attributes(map_github_pr_data(issue_data, repository))
      
      if save_issue_with_metadata(issue, stats)
        stats[:created_count] += 1
        stats[:comment_count] += 1
      end
    end
  end
  
  def self.process_review_event(event, repo_name, stats)
    pr_data = event['payload']['pull_request']
    return unless pr_data

    # Determine if this is a Dependabot PR
    # Old format: pr_data has 'user' field
    # New format: check branch name or existing issue
    is_dependabot = if pr_data['user']
      pr_data['user']['login']&.include?('dependabot')
    elsif pr_data['head'] && pr_data['head']['ref']
      pr_data['head']['ref']&.include?('dependabot')
    else
      existing_issue = Issue.find_by(uuid: pr_data['id'])
      existing_issue&.user&.include?('dependabot')
    end

    return unless is_dependabot
    
    repository = find_or_create_repository(repo_name)
    return unless repository
    
    existing_issue = find_or_build_issue_by_uuid(repository, pr_data['id'])
    return unless existing_issue
    
    if existing_issue.persisted?
      update_attrs = {}
      update_attrs[:comments_count] = pr_data['comments'] if pr_data['comments']
      update_attrs[:updated_at] = Time.parse(pr_data['updated_at']) if pr_data['updated_at']
      existing_issue.update(update_attrs) if update_attrs.any?
      stats[:review_count] += 1
    else
      issue = create_pr_from_data(repository, pr_data)
      if issue&.persisted?
        stats[:created_count] += 1
        stats[:review_count] += 1
      end
    end
  end

  def self.process_review_comment_event(event, repo_name, stats)
    pr_data = event['payload']['pull_request']
    return unless pr_data

    # Determine if this is a Dependabot PR
    # Old format: pr_data has 'user' field
    # New format: check branch name or existing issue
    is_dependabot = if pr_data['user']
      pr_data['user']['login']&.include?('dependabot')
    elsif pr_data['head'] && pr_data['head']['ref']
      pr_data['head']['ref']&.include?('dependabot')
    else
      existing_issue = Issue.find_by(uuid: pr_data['id'])
      existing_issue&.user&.include?('dependabot')
    end

    return unless is_dependabot
    
    repository = find_or_create_repository(repo_name)
    return unless repository
    
    existing_issue = find_or_build_issue_by_uuid(repository, pr_data['id'])
    return unless existing_issue
    
    if existing_issue.persisted?
      update_attrs = {}
      update_attrs[:comments_count] = pr_data['comments'] if pr_data['comments']
      update_attrs[:updated_at] = Time.parse(pr_data['updated_at']) if pr_data['updated_at']
      existing_issue.update(update_attrs) if update_attrs.any?
      stats[:review_comment_count] += 1
    else
      issue = create_pr_from_data(repository, pr_data)
      if issue&.persisted?
        stats[:created_count] += 1
        stats[:review_comment_count] += 1
      end
    end
  end

  def self.process_review_thread_event(event, repo_name, stats)
    pr_data = event['payload']['pull_request']
    return unless pr_data

    # Determine if this is a Dependabot PR
    # Old format: pr_data has 'user' field
    # New format: check branch name or existing issue
    is_dependabot = if pr_data['user']
      pr_data['user']['login']&.include?('dependabot')
    elsif pr_data['head'] && pr_data['head']['ref']
      pr_data['head']['ref']&.include?('dependabot')
    else
      existing_issue = Issue.find_by(uuid: pr_data['id'])
      existing_issue&.user&.include?('dependabot')
    end

    return unless is_dependabot
    
    repository = find_or_create_repository(repo_name)
    return unless repository
    
    existing_issue = find_or_build_issue_by_uuid(repository, pr_data['id'])
    return unless existing_issue
    
    if existing_issue.persisted?
      if pr_data['updated_at']
        existing_issue.update(updated_at: Time.parse(pr_data['updated_at']))
      end
      stats[:review_thread_count] += 1
    else
      issue = create_pr_from_data(repository, pr_data)
      if issue&.persisted?
        stats[:created_count] += 1
        stats[:review_thread_count] += 1
      end
    end
  end
  
  def self.map_github_pr_data(pr_data, repository, actor_login = nil)
    # Support both old format (full data) and new format (minimal data)
    # Old format has pr_data['user'], new format requires actor_login parameter
    user_login = pr_data['user'] ? pr_data['user']['login'] : actor_login

    attrs = {
      number: pr_data['number'],
      user: sanitize_string(user_login),
      pull_request: true,
      host_id: repository.host_id
    }

    # Optional fields that may not be present in new GHArchive format
    attrs[:node_id] = pr_data['node_id'] if pr_data['node_id']
    attrs[:title] = sanitize_string(pr_data['title']) if pr_data['title']
    attrs[:body] = sanitize_string(pr_data['body']) if pr_data['body']
    attrs[:state] = pr_data['state'] if pr_data['state']
    attrs[:locked] = pr_data['locked'] if pr_data.key?('locked')
    attrs[:comments_count] = pr_data['comments'] if pr_data['comments']
    attrs[:created_at] = Time.parse(pr_data['created_at']) if pr_data['created_at']
    attrs[:updated_at] = Time.parse(pr_data['updated_at']) if pr_data['updated_at']
    attrs[:closed_at] = Time.parse(pr_data['closed_at']) if pr_data['closed_at']
    attrs[:labels] = (pr_data['labels'] || []).map { |l| sanitize_string(l['name']) } if pr_data['labels']
    attrs[:assignees] = (pr_data['assignees'] || []).map { |a| sanitize_string(a['login']) } if pr_data['assignees']
    attrs[:author_association] = sanitize_string(pr_data['author_association']) if pr_data['author_association']
    attrs[:state_reason] = sanitize_string(pr_data['state_reason']) if pr_data['state_reason']
    attrs[:merged_at] = Time.parse(pr_data['merged_at']) if pr_data['merged_at']
    attrs[:merged_by] = sanitize_string(pr_data['merged_by']&.dig('login')) if pr_data['merged_by']
    attrs[:closed_by] = sanitize_string(pr_data['closed_by']&.dig('login')) if pr_data['closed_by']
    attrs[:draft] = pr_data['draft'] if pr_data.key?('draft')
    attrs[:mergeable] = pr_data['mergeable'] if pr_data.key?('mergeable')
    attrs[:mergeable_state] = sanitize_string(pr_data['mergeable_state']) if pr_data['mergeable_state']
    attrs[:rebaseable] = pr_data['rebaseable'] if pr_data.key?('rebaseable')
    attrs[:review_comments_count] = pr_data['review_comments'] if pr_data['review_comments']
    attrs[:commits_count] = pr_data['commits'] if pr_data['commits']
    attrs[:additions] = pr_data['additions'] if pr_data['additions']
    attrs[:deletions] = pr_data['deletions'] if pr_data['deletions']
    attrs[:changed_files] = pr_data['changed_files'] if pr_data['changed_files']

    attrs
  end
  
  def self.save_issue_with_metadata(issue, stats = nil)
    if issue.closed_at.present?
      issue.time_to_close = issue.closed_at - issue.created_at
    end
    
    begin
      if issue.save
        affected_package_ids = issue.update_dependabot_metadata
        if stats && affected_package_ids.any?
          stats[:affected_package_ids].merge(affected_package_ids)
        end
        true
      else
        false
      end
    rescue ActiveRecord::RecordNotUnique, PG::UniqueViolation => e
      # Handle unique constraint violations
      if e.message.include?('index_issues_on_repository_id_and_number_unique')
        Rails.logger.warn "Duplicate issue found for repository #{issue.repository_id}, number #{issue.number}. UUID: #{issue.uuid}. Skipping."
        return false
      elsif e.message.include?('index_issues_on_uuid')
        Rails.logger.warn "Duplicate UUID #{issue.uuid} found. This UUID already exists in the database. Skipping."
        return false
      else
        # Re-raise if it's a different constraint violation
        raise e
      end
    end
  end
  
  def self.find_or_create_repository(repo_name)
    owner_name, repo_name_only = repo_name.split('/', 2)
    return nil unless owner_name && repo_name_only
    
    github_host = Host.find_by(name: 'GitHub')
    return nil unless github_host
    
    # Use case-insensitive lookup to match the existing index
    existing_repo = Repository.find_by('lower(full_name) = ? AND host_id = ?', repo_name.downcase, github_host.id)
    return existing_repo if existing_repo
    
    begin
      Repository.create!(
        full_name: repo_name,
        host: github_host,
        owner: owner_name
      )
    rescue ActiveRecord::RecordNotUnique
      # Handle race condition - find the existing record
      Repository.find_by('lower(full_name) = ? AND host_id = ?', repo_name.downcase, github_host.id)
    rescue => e
      Rails.logger.error "Failed to find/create repository #{repo_name}: #{e.message}"
      nil
    end
  end
  
  def self.create_pr_from_data(repository, pr_data)
    issue = find_or_build_issue_by_uuid(repository, pr_data['id'])
    return nil unless issue
    issue.assign_attributes(map_github_pr_data(pr_data, repository))
    
    # Use save_issue_with_metadata to handle duplicate constraints
    if save_issue_with_metadata(issue)
      issue
    else
      nil
    end
  end
  
  def self.update_package_counts(stats)
    affected_package_ids = stats[:affected_package_ids]
    return unless affected_package_ids&.any?
    
    Rails.logger.info "Updating repository counts for #{affected_package_ids.size} affected packages"
    
    Package.where(id: affected_package_ids.to_a).find_each do |package|
      package.update_unique_repositories_counts!
    end
    
    Rails.logger.info "Repository counts updated for affected packages"
  end
end
