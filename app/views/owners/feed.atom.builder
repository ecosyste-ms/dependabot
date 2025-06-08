atom_feed(language: 'en-US') do |feed|
  feed.title "#{@owner} - Dependabot PRs"
  feed.description "Recent Dependabot pull requests for repositories owned by #{@owner}"
  feed.link issues_host_owner_url(@host, @owner)
  feed.updated @issues.maximum(:updated_at) if @issues.any?
  
  @issues.each do |issue|
    feed.entry(issue, url: host_repository_issue_url(issue.host, issue.repository, issue)) do |entry|
      entry.title "#{issue.repository.full_name}: #{issue.title}"
      entry.content type: 'html' do |content|
        content << content_tag(:p, "Repository: #{link_to issue.repository.full_name, host_repository_url(issue.host, issue.repository)}", escape: false)
        content << content_tag(:p, "Owner: #{@owner}")
        content << content_tag(:p, "State: #{issue.state.capitalize}")
        content << content_tag(:p, "Created: #{issue.created_at.strftime('%B %d, %Y at %I:%M %p UTC')}")
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
      
      # Add categories for ecosystem, package names, and owner
      entry.category(@owner)
      issue.issue_packages.each do |issue_package|
        entry.category(issue_package.package.ecosystem)
        entry.category(issue_package.package.name)
      end
    end
  end
end