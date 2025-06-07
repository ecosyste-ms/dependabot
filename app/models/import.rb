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
  
  def self.already_imported?(datetime)
    filename = "#{datetime.year}-#{datetime.month.to_s.rjust(2, '0')}-#{datetime.day.to_s.rjust(2, '0')}-#{datetime.hour}.json.gz"
    exists?(filename: filename, success: true)
  end
  
  def self.import_hour(datetime)
    filename = "#{datetime.year}-#{datetime.month.to_s.rjust(2, '0')}-#{datetime.day.to_s.rjust(2, '0')}-#{datetime.hour}.json.gz"
    
    begin
      url = "http://data.gharchive.org/#{filename}"
      uri = URI(url)
      response = Net::HTTP.get_response(uri)
      
      if response.code != '200'
        error_msg = "HTTP #{response.code}"
        create_failed_import(filename, error_msg)
        return { success: false, error: error_msg }
      end
      
      # Decompress and process data
      decompressed_data = Zlib::GzipReader.new(StringIO.new(response.body)).read
      stats = process_gharchive_data(decompressed_data)
      
      # Record successful import
      create!(
        filename: filename,
        imported_at: Time.current,
        **stats,
        success: true
      )
      
      { success: true, **stats }
      
    rescue => e
      create_failed_import(filename, e.message)
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
      
      if already_imported?(current_time)
        results[:skipped_imports] += 1
        results[:successful_imports] += 1
        current_time += 1.hour
        next
      end
      
      result = import_hour(current_time)
      
      if result[:success]
        results[:successful_imports] += 1
        add_stats_to_totals(results, result)
      else
        results[:failed_imports] += 1
      end
      
      current_time += 1.hour
    end
    
    results
  end
  
  private
  
  def self.create_failed_import(filename, error_message)
    create!(
      filename: filename,
      imported_at: Time.current,
      **default_stats,
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
      updated_count: 0
    }
  end
  
  def self.add_stats_to_totals(totals, stats)
    default_stats.keys.each do |key|
      totals[key] ||= 0
      totals[key] += stats[key] || 0
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
    return unless pr_data && pr_data['user']
    
    pr_author = pr_data['user']['login']
    return unless Issue::DEPENDABOT_USERNAMES.include?(pr_author)
    
    stats[:dependabot_count] += 1
    stats[:pr_count] += 1
    
    repository = find_or_create_repository(repo_name)
    return unless repository
    
    issue = repository.issues.find_or_initialize_by(uuid: pr_data['id'])
    
    # Skip if this is an older event
    if issue.persisted? && issue.updated_at && issue.updated_at >= Time.parse(pr_data['updated_at'])
      return
    end
    
    was_new = issue.new_record?
    issue.assign_attributes(map_github_pr_data(pr_data, repository))
    
    if save_issue_with_metadata(issue)
      if was_new
        stats[:created_count] += 1
      else
        stats[:updated_count] += 1
      end
    end
  end
  
  def self.process_comment_event(event, repo_name, stats)
    issue_data = event['payload']['issue']
    return unless issue_data['pull_request']
    
    pr_author = issue_data['user']['login']
    return unless Issue::DEPENDABOT_USERNAMES.include?(pr_author)
    
    repository = find_or_create_repository(repo_name)
    return unless repository
    
    existing_issue = repository.issues.find_by(uuid: issue_data['id'])
    if existing_issue
      existing_issue.update(comments_count: issue_data['comments'])
      stats[:comment_count] += 1
    else
      issue = repository.issues.find_or_initialize_by(uuid: issue_data['id'])
      was_new = issue.new_record?
      issue.assign_attributes(map_github_pr_data(issue_data, repository))
      
      if save_issue_with_metadata(issue)
        stats[:created_count] += 1 if was_new
        stats[:comment_count] += 1 if was_new
      end
    end
  end
  
  def self.process_review_event(event, repo_name, stats)
    pr_data = event['payload']['pull_request']
    pr_author = pr_data['user']['login']
    return unless Issue::DEPENDABOT_USERNAMES.include?(pr_author)
    
    repository = find_or_create_repository(repo_name)
    return unless repository
    
    existing_issue = repository.issues.find_by(uuid: pr_data['id'])
    if existing_issue
      existing_issue.update(
        comments_count: pr_data['comments'] || existing_issue.comments_count,
        updated_at: Time.parse(pr_data['updated_at'])
      )
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
    pr_author = pr_data['user']['login']
    return unless Issue::DEPENDABOT_USERNAMES.include?(pr_author)
    
    repository = find_or_create_repository(repo_name)
    return unless repository
    
    existing_issue = repository.issues.find_by(uuid: pr_data['id'])
    if existing_issue
      existing_issue.update(
        comments_count: pr_data['comments'] || existing_issue.comments_count,
        updated_at: Time.parse(pr_data['updated_at'])
      )
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
    pr_author = pr_data['user']['login']
    return unless Issue::DEPENDABOT_USERNAMES.include?(pr_author)
    
    repository = find_or_create_repository(repo_name)
    return unless repository
    
    existing_issue = repository.issues.find_by(uuid: pr_data['id'])
    if existing_issue
      existing_issue.update(updated_at: Time.parse(pr_data['updated_at']))
      stats[:review_thread_count] += 1
    else
      issue = create_pr_from_data(repository, pr_data)
      if issue&.persisted?
        stats[:created_count] += 1
        stats[:review_thread_count] += 1
      end
    end
  end
  
  def self.map_github_pr_data(pr_data, repository)
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
      merged_by: pr_data['merged_by']&.dig('login'),
      closed_by: pr_data['closed_by']&.dig('login'),
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
  
  def self.save_issue_with_metadata(issue)
    if issue.closed_at.present?
      issue.time_to_close = issue.closed_at - issue.created_at
    end
    
    if issue.save
      issue.update_dependabot_metadata
      true
    else
      false
    end
  end
  
  def self.find_or_create_repository(repo_name)
    owner_name, repo_name_only = repo_name.split('/', 2)
    return nil unless owner_name && repo_name_only
    
    github_host = Host.find_by(name: 'GitHub')
    return nil unless github_host
    
    begin
      Repository.find_or_create_by!(
        full_name: repo_name,
        host: github_host
      ) do |repo|
        repo.owner = owner_name
      end
    rescue ActiveRecord::RecordNotUnique
      Repository.find_by!(full_name: repo_name, host: github_host)
    end
  end
  
  def self.create_pr_from_data(repository, pr_data)
    issue = repository.issues.find_or_initialize_by(uuid: pr_data['id'])
    issue.assign_attributes(map_github_pr_data(pr_data, repository))
    
    if issue.closed_at.present?
      issue.time_to_close = issue.closed_at - issue.created_at
    end
    
    if issue.save
      issue.update_dependabot_metadata
      issue
    else
      nil
    end
  end
end
