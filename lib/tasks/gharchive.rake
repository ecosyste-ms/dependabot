require 'net/http'
require 'zlib'
require 'json'

namespace :gharchive do
  desc "Test import one hour of Dependabot PRs from GHArchive"
  task test_import: :environment do
    # Default to 1 hour ago if no hour specified
    hour_ago = 1.hour.ago
    
    puts "Testing GHArchive import for #{hour_ago.strftime('%Y-%m-%d-%H')}..."
    
    import_hour(hour_ago)
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
      
      import_hour(datetime)
    rescue => e
      puts "Error parsing hour '#{hour_string}': #{e.message}"
      puts "Expected format: YYYY-MM-DD-HH (e.g., 2024-01-01-14)"
      exit 1
    end
  end
  
  private
  
  def import_hour(datetime)
    filename = "#{datetime.year}-#{datetime.month.to_s.rjust(2, '0')}-#{datetime.day.to_s.rjust(2, '0')}-#{datetime.hour}.json.gz"
    url = "http://data.gharchive.org/#{filename}"
    
    puts "Downloading #{url}..."
    
    begin
      uri = URI(url)
      response = Net::HTTP.get_response(uri)
      
      if response.code != '200'
        puts "Failed to download #{url}: HTTP #{response.code}"
        return
      end
      
      puts "Downloaded #{response.body.length} bytes, decompressing..."
      
      # Decompress the gzipped data
      decompressed_data = Zlib::GzipReader.new(StringIO.new(response.body)).read
      
      puts "Decompressed to #{decompressed_data.length} bytes, processing events..."
      
      dependabot_count = 0
      pr_count = 0
      created_count = 0
      updated_count = 0
      
      # Process each line (each line is a JSON event)
      decompressed_data.each_line do |line|
        event = JSON.parse(line.strip)
        
        # Only process PullRequestEvent from dependabot[bot]
        next unless event['type'] == 'PullRequestEvent'
        next unless event['actor'] && event['actor']['login'] == 'dependabot[bot]'
        
        dependabot_count += 1
        
        # Only process 'opened' actions for now (to avoid duplicates)
        next unless event['payload']['action'] == 'opened'
        
        pr_count += 1
        
        # Extract the pull request data
        pr_data = event['payload']['pull_request']
        repo_name = event['repo']['name']
        
        # Find or create the repository
        repository = find_or_create_repository(repo_name)
        next unless repository
        
        # Find or create the issue (PRs are stored as issues)
        issue = repository.issues.find_or_initialize_by(uuid: pr_data['id'])
        
        was_new = issue.new_record?
        
        # Map the GitHub data to our issue format
        issue.assign_attributes(
          node_id: pr_data['node_id'],
          number: pr_data['number'],
          title: pr_data['title'],
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
          host_id: repository.host_id
        )
        
        # Parse Dependabot metadata (reuse existing method)
        issue.parse_dependabot_metadata if issue.respond_to?(:parse_dependabot_metadata)
        
        # Calculate time to close if closed
        if issue.closed_at.present?
          issue.time_to_close = issue.closed_at - issue.created_at
        end
        
        # Save the issue
        if issue.save
          if was_new
            created_count += 1
          else
            updated_count += 1
          end
        else
          puts "Failed to save issue #{pr_data['id']}: #{issue.errors.full_messages.join(', ')}"
        end
      end
      
      puts "\nImport complete!"
      puts "- Total Dependabot events: #{dependabot_count}"
      puts "- Pull request 'opened' events: #{pr_count}"
      puts "- Issues created: #{created_count}"
      puts "- Issues updated: #{updated_count}"
      
    rescue => e
      puts "Error importing data: #{e.message}"
      puts e.backtrace.first(5).join("\n")
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
        name: repo_name_only,
        host: github_host,
        private: false # Assume public since it's in GHArchive
      )
    end
    
    repository
  end
end