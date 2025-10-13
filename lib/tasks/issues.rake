namespace :issues do
  desc 'Enrich incomplete Dependabot PRs with details from GitHub API'
  task enrich_incomplete: :environment do
    puts "Starting enrichment of incomplete Dependabot PRs..."

    incomplete_count = Issue.incomplete_prs.count
    puts "Found #{incomplete_count} incomplete PRs"

    if incomplete_count == 0
      puts "No incomplete PRs to enrich"
      next
    end

    result = Issue.enrich_incomplete_prs

    puts "\nEnrichment complete:"
    puts "  Enriched: #{result[:enriched]}"
    puts "  Failed: #{result[:failed]}"
    puts "  Duration: #{result[:duration]} seconds"
    puts "  Remaining incomplete: #{Issue.incomplete_prs.count}"
  end
end
