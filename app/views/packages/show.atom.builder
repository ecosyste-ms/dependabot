atom_feed(language: 'en-US') do |feed|
  feed.title "#{@package.ecosystem}/#{@package.name} - Dependabot Updates"
  feed.description "Recent Dependabot updates for the #{@package.name} package in the #{@package.ecosystem} ecosystem"
  feed.link show_packages_url(@package.ecosystem, @package.name)
  
  # Add self link
  feed.link rel: 'self', href: feed_packages_url(@package.ecosystem, @package.name, page: @pagy.page)
  
  # Add alternate link to HTML version
  feed.link rel: 'alternate', type: 'text/html', href: show_packages_url(@package.ecosystem, @package.name)
  
  # Add pagination links
  if @pagy.prev
    feed.link rel: 'previous', href: feed_packages_url(@package.ecosystem, @package.name, page: @pagy.prev)
  end
  
  if @pagy.next
    feed.link rel: 'next', href: feed_packages_url(@package.ecosystem, @package.name, page: @pagy.next)
  end
  
  @issue_packages.each do |issue_package|
    issue = issue_package.issue
    feed.entry(issue, url: host_repository_issue_url(issue.host, issue.repository, issue)) do |entry|
      entry.title "#{issue.repository.full_name}: #{issue.title}"
      entry.content type: 'html' do |content|
        content << content_tag(:p, "Repository: #{issue.repository.full_name}")
        content << content_tag(:p, "State: #{issue.state.capitalize}")
        content << content_tag(:p, "Update Type: #{issue_package.update_type.humanize}") if issue_package.update_type.present?
        content << content_tag(:p, "Created: #{issue.created_at.strftime('%B %d, %Y')}")
        content << content_tag(:p, "Author: #{issue.user}")
        
        if issue_package.version_change.present?
          content << content_tag(:p, "Version: #{issue_package.version_change}")
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