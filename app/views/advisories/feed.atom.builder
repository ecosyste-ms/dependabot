atom_feed(language: 'en-US') do |feed|
  feed.title "Security Advisories - Ecosyste.ms: Dependabot"
  feed.description "Latest security advisories tracked by Dependabot"
  feed.link href: advisories_url
  feed.updated @advisories.maximum(:updated_at)

  @advisories.each do |advisory|
    feed.entry advisory, url: advisory_url(advisory), published: advisory.published_at do |entry|
      entry.title "#{advisory.primary_identifier}: #{advisory.title}"
      
      content = ""
      
      if advisory.description.present?
        content += advisory.description
        content += "\n\n"
      end
      
      if advisory.severity.present?
        content += "**Severity:** #{advisory.severity}\n\n"
      end
      
      if advisory.ecosystems.any?
        content += "**Affected Ecosystems:** #{advisory.ecosystems.join(', ')}\n\n"
      end
      
      if advisory.package_names.any?
        content += "**Affected Packages:** #{advisory.package_names.join(', ')}\n\n"
      end
      
      if advisory.issues_count > 0
        content += "**Dependabot PRs:** #{advisory.issues_count}\n\n"
      end
      
      if advisory.references.any?
        content += "**References:**\n"
        advisory.references.each do |ref|
          content += "- #{ref}\n"
        end
      end
      
      entry.content content, type: 'text'
      entry.author do |author|
        author.name "Ecosyste.ms"
      end
    end
  end
end