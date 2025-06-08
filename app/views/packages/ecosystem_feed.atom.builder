atom_feed(language: 'en-US') do |feed|
  feed.title "#{@ecosystem.capitalize} - Dependabot PRs"
  feed.description "Recent Dependabot pull requests for packages in the #{@ecosystem} ecosystem"
  feed.link ecosystem_issues_packages_url(@ecosystem)
  
  # Add self link
  feed.link rel: 'self', href: ecosystem_feed_packages_url(@ecosystem, page: @pagy.page)
  
  # Add alternate link to HTML version
  feed.link rel: 'alternate', type: 'text/html', href: ecosystem_issues_packages_url(@ecosystem)
  
  # Add pagination links
  if @pagy.prev
    feed.link rel: 'previous', href: ecosystem_feed_packages_url(@ecosystem, page: @pagy.prev)
  end
  
  if @pagy.next
    feed.link rel: 'next', href: ecosystem_feed_packages_url(@ecosystem, page: @pagy.next)
  end
  
  @issues.each do |issue|
    feed.entry(issue, url: host_repository_issue_url(issue.host, issue.repository, issue)) do |entry|
      entry.title "#{issue.repository.full_name}: #{issue.title}"
      entry.content type: 'html' do |content|
        content << content_tag(:p, "Repository: #{link_to issue.repository.full_name, host_repository_url(issue.host, issue.repository)}", escape: false)
        content << content_tag(:p, "Ecosystem: #{@ecosystem}")
        content << content_tag(:p, "State: #{issue.state.capitalize}")
        content << content_tag(:p, "Created: #{issue.created_at.strftime('%B %d, %Y at %I:%M %p UTC')}")
        content << content_tag(:p, "Author: #{issue.user}")
        
        # Show package information from issue_packages
        issue.issue_packages.each do |issue_package|
          package = issue_package.package
          content << content_tag(:p, "Package: #{package.name}")
          
          if issue_package.version_change.present?
            content << content_tag(:p, "Version: #{issue_package.version_change}")
          end
          
          if issue_package.update_type.present?
            content << content_tag(:p, "Update Type: #{issue_package.update_type.humanize}")
          end
        end
        
        if issue.merged_at.present?
          content << content_tag(:p, "Merged: #{issue.merged_at.strftime('%B %d, %Y at %I:%M %p UTC')}")
        elsif issue.closed_at.present?
          content << content_tag(:p, "Closed: #{issue.closed_at.strftime('%B %d, %Y at %I:%M %p UTC')}")
        end
        
        if issue.comments_count && issue.comments_count > 0
          content << content_tag(:p, "Comments: #{issue.comments_count}")
        end
      end
      
      entry.author issue.user
      entry.updated issue.updated_at
      entry.published issue.created_at
      
      # Add categories for ecosystem and package names
      entry.category(@ecosystem)
      issue.issue_packages.each do |issue_package|
        entry.category(issue_package.package.name)
      end
    end
  end
end