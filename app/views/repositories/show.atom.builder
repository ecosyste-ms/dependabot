atom_feed(language: 'en-US') do |feed|
  feed.title "#{@repository.full_name} - Dependabot Pull Requests"
  feed.description "Recent Dependabot pull requests for #{@repository.full_name}"
  feed.link host_repository_url(@host, @repository)
  
  # Add self link
  feed.link rel: 'self', href: feed_host_repository_url(@host, @repository, page: @pagy.page)
  
  # Add alternate link to HTML version
  feed.link rel: 'alternate', type: 'text/html', href: host_repository_url(@host, @repository)
  
  # Add pagination links
  if @pagy.prev
    feed.link rel: 'previous', href: feed_host_repository_url(@host, @repository, page: @pagy.prev)
  end
  
  if @pagy.next
    feed.link rel: 'next', href: feed_host_repository_url(@host, @repository, page: @pagy.next)
  end
  feed.updated @issues.maximum(:updated_at) if @issues.any?
  
  @issues.each do |issue|
    feed.entry(issue, url: host_repository_issue_url(@host, @repository, issue)) do |entry|
      entry.title issue.title
      entry.content type: 'html' do |content|
        content << content_tag(:p, "State: #{issue.effective_state.capitalize}")
        content << content_tag(:p, "Created: #{issue.created_at.strftime('%B %d, %Y')}")
        content << content_tag(:p, "Author: #{issue.user}")
        
        # Show package information from issue_packages
        issue.issue_packages.each do |issue_package|
          package = issue_package.package
          content << content_tag(:p, "Package: #{package.ecosystem}/#{package.name}")
          
          if issue_package.version_change.present?
            content << content_tag(:p, "Version: #{issue_package.version_change}")
          elsif issue_package.old_version.present? && issue_package.new_version.present?
            content << content_tag(:p, "Version: #{issue_package.old_version} → #{issue_package.new_version}")
          end
          
          if issue_package.update_type.present?
            content << content_tag(:p, "Update Type: #{issue_package.update_type.humanize}")
          end
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