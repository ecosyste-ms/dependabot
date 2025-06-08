atom_feed(language: 'en-US') do |feed|
  feed.title "#{@repository.full_name} - Dependabot Issues"
  feed.description "Recent Dependabot issues and pull requests for #{@repository.full_name}"
  feed.link host_repository_url(@host, @repository)
  feed.updated @issues.maximum(:updated_at) if @issues.any?
  
  @issues.each do |issue|
    feed.entry(issue, url: host_repository_issue_url(@host, @repository, issue)) do |entry|
      entry.title issue.title
      entry.content type: 'html' do |content|
        content << content_tag(:p, "State: #{issue.state.capitalize}")
        content << content_tag(:p, "Created: #{issue.created_at.strftime('%B %d, %Y')}")
        content << content_tag(:p, "Author: #{issue.user}")
        
        if issue.dependency_name.present?
          content << content_tag(:p, "Package: #{issue.dependency_name}")
        end
        
        if issue.dependency_previous_version.present? && issue.dependency_new_version.present?
          content << content_tag(:p, "Version: #{issue.dependency_previous_version} → #{issue.dependency_new_version}")
        end
        
        if issue.ecosystem.present?
          content << content_tag(:p, "Ecosystem: #{issue.ecosystem}")
        end
        
        if issue.merged_at.present?
          content << content_tag(:p, "Merged: #{issue.merged_at.strftime('%B %d, %Y')}")
        elsif issue.closed_at.present?
          content << content_tag(:p, "Closed: #{issue.closed_at.strftime('%B %d, %Y')}")
        end
      end
      
      entry.author issue.user
      entry.updated issue.updated_at
      entry.published issue.created_at
    end
  end
end