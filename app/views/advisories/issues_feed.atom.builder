atom_feed(language: 'en-US') do |feed|
  feed.title "#{@advisory.primary_identifier} - Dependabot Pull Requests"
  feed.description "Dependabot pull requests for security advisory #{@advisory.primary_identifier}"
  feed.link href: advisory_url(@advisory)
  feed.updated @issues.maximum(:updated_at) if @issues.any?

  @issues.each do |issue|
    feed.entry issue, url: [issue.host, issue.repository, issue], published: issue.created_at do |entry|
      entry.title "#{issue.repository.full_name}##{issue.number}: #{issue.title}"
      
      content = ""
      
      if issue.body.present?
        # Use the cleaned body helper
        content += clean_dependabot_body(issue.body)
        content += "\n\n"
      end
      
      content += "**Repository:** #{issue.repository.full_name}\n"
      content += "**State:** #{issue.effective_state.capitalize}\n"
      
      if issue.packages.any?
        content += "**Packages:** #{issue.packages.map(&:name).join(', ')}\n"
      end
      
      if issue.closed_at
        content += "**Closed:** #{issue.closed_at.strftime('%Y-%m-%d')}\n"
      end
      
      if issue.merged_at
        content += "**Merged:** #{issue.merged_at.strftime('%Y-%m-%d')}\n"
      end
      
      entry.content content, type: 'text'
      entry.author do |author|
        author.name "dependabot[bot]"
      end
    end
  end
end