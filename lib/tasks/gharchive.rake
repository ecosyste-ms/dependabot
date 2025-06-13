namespace :gharchive do
  desc "Test import one hour of Dependabot PRs from GHArchive"
  task test_import: :environment do
    hour_ago = 1.hour.ago
    puts "Testing GHArchive import for #{hour_ago.strftime('%Y-%m-%d-%H')}..."
    
    result = Import.import_hour(hour_ago)
    
    if result[:success]
      puts "✅ Import complete!"
      puts "- Dependabot events: #{result[:dependabot_count]}"
      puts "- Issues created: #{result[:created_count]}"
      puts "- Issues updated: #{result[:updated_count]}"
    else
      puts "❌ Import failed: #{result[:error]}"
    end
  end
  
  desc "Import past 24 hours of Dependabot PRs from GHArchive"
  task import_24_hours: :environment do
    end_time = Time.now.utc
    start_time = 24.hours.ago.utc
    
    Import.import_range(start_time, end_time)
    
    # Retry any failed imports from the past 24 hours
    failed_imports = Import.failed_imports_last_24_hours
    failed_imports.each do |import|
      import.retry!
    end
  end

  desc "Import all Dependabot PRs from GHArchive for the last 30 days"
  task import_last_30_days: :environment do
    puts "Importing last 30 days of Dependabot PRs..."
    
    end_time = Time.now.utc
    start_time = 30.days.ago.utc
    
    results = Import.import_range(start_time, end_time)
    
    puts "\n" + "="*50
    puts "30-Day Import Summary"
    puts "="*50
    puts "Hours processed: #{results[:total_hours]}"
    puts "Successful: #{results[:successful_imports]}"
    puts "Failed: #{results[:failed_imports]}"
    puts "Skipped: #{results[:skipped_imports]}"
    puts "Success rate: #{(results[:successful_imports].to_f / results[:total_hours] * 100).round(1)}%"
    puts ""
    puts "Total events: #{results[:dependabot_count]}"
    puts "Issues created: #{results[:created_count]}"
    puts "Issues updated: #{results[:updated_count]}"
    puts "="*50
  end
  
  desc "Import specific hour of Dependabot PRs from GHArchive (HOUR=2024-01-01-14)"
  task import_hour: :environment do
    hour_string = ENV['HOUR']
    
    if hour_string.nil?
      puts "Please specify HOUR in format YYYY-MM-DD-HH, e.g., rake gharchive:import_hour HOUR=2024-01-01-14"
      exit 1
    end
    
    begin
      year, month, day, hour = hour_string.split('-').map(&:to_i)
      datetime = Time.new(year, month, day, hour, 0, 0, 'UTC')
      
      puts "Importing GHArchive data for #{datetime.strftime('%Y-%m-%d %H:00 UTC')}..."
      
      result = Import.import_hour(datetime)
      
      if result[:success]
        puts "✅ Import complete!"
        puts "- Dependabot events: #{result[:dependabot_count]}"
        puts "- Issues created: #{result[:created_count]}"
        puts "- Issues updated: #{result[:updated_count]}"
      else
        puts "❌ Import failed: #{result[:error]}"
        exit 1
      end
    rescue => e
      puts "❌ Error parsing hour '#{hour_string}': #{e.message}"
      puts "Expected format: YYYY-MM-DD-HH (e.g., 2024-01-01-14)"
      exit 1
    end
  end
end