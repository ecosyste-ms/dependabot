class Issue < ApplicationRecord
  belongs_to :repository
  belongs_to :host
  has_many :issue_packages, dependent: :destroy
  has_many :packages, through: :issue_packages

  scope :past_year, -> { where('created_at > ?', 1.year.ago) }
  scope :bot, -> { where('issues.user ILIKE ?', '%[bot]') }
  scope :human, -> { where.not('issues.user ILIKE ?', '%[bot]') }
  scope :with_author_association, -> { where.not(author_association: nil) }
  scope :merged, -> { where.not(merged_at: nil) }
  scope :not_merged, -> { where(merged_at: nil).where.not(closed_at: nil) }
  scope :closed, -> { where.not(closed_at: nil) }
  scope :open, -> { where(state: 'open') }
  scope :merged_prs, -> { where(pull_request: true).where.not(merged_at: nil) }
  scope :unmerged_closed_prs, -> { where(pull_request: true, merged_at: nil).where.not(closed_at: nil) }
  scope :created_after, ->(date) { where('created_at > ?', date) }
  scope :created_before, ->(date) { where('created_at < ?', date) }
  scope :updated_after, ->(date) { where('updated_at > ?', date) }
  scope :pull_request, -> { where(pull_request: true) }
  scope :issue, -> { where(pull_request: false) }

  scope :user, ->(user) { where(user: user) }
  scope :owner, ->(owner) { joins(:repository).where('repositories.owner = ?', owner) }
  scope :maintainers, -> { where(author_association: MAINTAINER_ASSOCIATIONS) }

  MAINTAINER_ASSOCIATIONS = ["MEMBER", "OWNER", "COLLABORATOR"]

  DEPENDABOT_USERNAMES = ['dependabot[bot]', 'dependabot-preview[bot]'].freeze
  DEPENDABOT_ECOSYSTEMS = {
    # Ruby
    'ruby' => 'rubygems',
    'rubygems' => 'rubygems',
    'bundler' => 'rubygems',
    
    # JavaScript/Node.js
    'javascript' => 'npm',
    'npm' => 'npm',
    'yarn' => 'npm',
    'pnpm' => 'npm',
    
    # Python
    'python' => 'pip',
    'pip' => 'pip',
    'pipenv' => 'pip',
    'poetry' => 'pip',
    'uv' => 'pip',
    
    # Java/JVM
    'java' => 'maven',
    'maven' => 'maven',
    'gradle' => 'gradle',
    'kotlin' => 'maven',
    'scala' => 'maven',
    
    # .NET
    '.net' => 'nuget',
    'nuget' => 'nuget',
    'dotnet' => 'nuget',
    
    # Go
    'go' => 'go',
    'gomod' => 'go',
    'golang' => 'go',
    
    # PHP
    'php' => 'packagist',
    'composer' => 'packagist',
    'packagist' => 'packagist',
    
    # Rust
    'rust' => 'cargo',
    'cargo' => 'cargo',
    
    # Docker
    'docker' => 'docker',
    'dockerfile' => 'docker',
    
    # GitHub Actions
    'github_actions' => 'actions',
    'github-actions' => 'actions',
    'actions' => 'actions',
    
    # Infrastructure
    'terraform' => 'terraform',
    'helm' => 'helm',
    'kubernetes' => 'kubernetes',
    
    # Other languages
    'elixir' => 'hex',
    'hex' => 'hex',
    'dart' => 'pub',
    'pub' => 'pub',
    'elm' => 'elm',
    'swift' => 'swift',
    'cocoapods' => 'cocoapods',
    'carthage' => 'carthage',
    'mix' => 'hex',
    
    # Package managers by ecosystem
    'conda' => 'conda',
    'conda-forge' => 'conda',
  }

  scope :dependabot, -> { where(user: DEPENDABOT_USERNAMES) }
  scope :with_dependency_metadata, -> { where('length(dependency_metadata::text) > 2') }
  scope :without_dependency_metadata, -> { where(dependency_metadata: nil) }
  scope :package_name, ->(package_name) { dependabot.with_dependency_metadata.where("dependency_metadata->>'package_name' = ?", package_name) }
  scope :ecosystem, ->(ecosystem) { dependabot.with_dependency_metadata.where("dependency_metadata->>'ecosystem' = ?", ecosystem) }

  def to_param
    number.to_s
  end

  def html_url
    host.host_instance.issue_url(repository, self)
  end

  def parse_dependabot_metadata
    return unless user.in?(DEPENDABOT_USERNAMES)
    ecosystem = DEPENDABOT_ECOSYSTEMS.keys & labels.map(&:downcase)
    
    # Try single package first
    single_match = title.match(/^(?<prefix>.+?)(?:\s+|:\s+)(?:bump\s+)?(?<package_name>\S+) from (?<old_version>\S+) to (?<new_version>\S+)(?: in (?<path>.+))?$/)
    
    if single_match
      return {
        prefix: single_match[:prefix],
        packages: [{
          name: single_match[:package_name],
          old_version: single_match[:old_version],
          new_version: single_match[:new_version]
        }],
        path: single_match[:path],
        ecosystem: DEPENDABOT_ECOSYSTEMS[ecosystem.first],
      }
    end
    
    # Try multiple packages format: "Bump package1 and package2"
    multi_match = title.match(/^(?<prefix>.+?)(?:\s+|:\s+)(?:bump\s+)?(?<package_names>.+?)(?: in (?<path>.+))?$/)
    
    if multi_match && multi_match[:package_names].include?(' and ')
      package_names = multi_match[:package_names].split(' and ').map(&:strip)
      
      # Parse version information from body if available
      packages = package_names.map do |name|
        package_data = { name: name }
        
        if body.present?
          # Look for "Updates `package_name` from X.X.X to Y.Y.Y"
          version_match = body.match(/Updates `#{Regexp.escape(name)}` from (?<old_version>\S+) to (?<new_version>\S+)/)
          if version_match
            package_data[:old_version] = version_match[:old_version]
            package_data[:new_version] = version_match[:new_version]
          end
        end
        
        package_data
      end
      
      return {
        prefix: multi_match[:prefix],
        packages: packages,
        path: multi_match[:path],
        ecosystem: DEPENDABOT_ECOSYSTEMS[ecosystem.first],
      }
    end
    
    # Try single package without version in title: "Bump package-name"
    single_no_version_match = title.match(/^(?<prefix>.+?)(?:\s+|:\s+)(?:bump\s+)?(?<package_name>\S+)(?: in (?<path>.+))?$/i)
    
    if single_no_version_match && body.present?
      package_name = single_no_version_match[:package_name]
      # Look for version information in body
      version_match = body.match(/Updates `#{Regexp.escape(package_name)}` from (?<old_version>\S+) to (?<new_version>\S+)/)
      
      if version_match
        return {
          prefix: single_no_version_match[:prefix],
          packages: [{
            name: package_name,
            old_version: version_match[:old_version],
            new_version: version_match[:new_version]
          }],
          path: single_no_version_match[:path],
          ecosystem: DEPENDABOT_ECOSYSTEMS[ecosystem.first],
        }
      end
    end
    
    # Try group updates with table in body
    group_match = title.match(/^(?<prefix>.+?)(?:\s+|:\s+)(?:the\s+)?(?<group_name>[\w_-]+) group (?:across \d+ director(?:y|ies) )?(?:with (?<update_count>\d+) updates?(?:\s+in (?<path>.+?))?|(?:in (?<path2>[^\s]+) )?with (?<update_count2>\d+) updates?)$/i)
    
    if group_match && body.present?
      # Handle both "with X updates in path" and "in path with X updates" formats
      update_count = (group_match[:update_count] || group_match[:update_count2]).to_i
      path = group_match[:path] || group_match[:path2]
      
      # Parse markdown table from body
      packages = parse_group_update_table(body)
      
      if packages.any?
        return {
          prefix: group_match[:prefix],
          group_name: group_match[:group_name],
          update_count: update_count,
          packages: packages,
          path: path,
          ecosystem: DEPENDABOT_ECOSYSTEMS[ecosystem.first],
        }
      else
        # For group updates without parseable package details, return basic info
        return {
          prefix: group_match[:prefix],
          group_name: group_match[:group_name],
          update_count: update_count,
          packages: [],
          path: path,
          ecosystem: DEPENDABOT_ECOSYSTEMS[ecosystem.first],
        }
      end
    end
    
    # Try requirement update formats
    if title.include?(" requirement ")
      # Format: "Update package requirement from X to Y" (handles complex version ranges)
      requirement_from_to_match = title.match(/^(?<prefix>.*?)(?<update_word>Update|update) (?<package_name>\S+) requirement from (?<old_version>.+?) to (?<new_version>.+?)(?:\s+in (?<path>.+?))?$/i)
      if requirement_from_to_match
        prefix = requirement_from_to_match[:prefix].present? ? 
                 requirement_from_to_match[:prefix] + requirement_from_to_match[:update_word] :
                 requirement_from_to_match[:update_word]
        
        return {
          prefix: prefix,
          packages: [{
            name: requirement_from_to_match[:package_name],
            old_version: requirement_from_to_match[:old_version].strip,
            new_version: requirement_from_to_match[:new_version].strip
          }],
          path: requirement_from_to_match[:path],
          ecosystem: DEPENDABOT_ECOSYSTEMS[ecosystem.first],
        }
      end
      
      # Format: "Update package requirement to X"
      requirement_to_match = title.match(/^(?<prefix>.*?)(?:Update|update) (?<package_name>\S+) requirement to (?<new_version>\S+)$/i)
      if requirement_to_match
        return {
          prefix: requirement_to_match[:prefix],
          packages: [{
            name: requirement_to_match[:package_name],
            new_version: requirement_to_match[:new_version]
          }],
          ecosystem: DEPENDABOT_ECOSYSTEMS[ecosystem.first],
        }
      end
    end
    
    # Try version range format: "Bump package to X, Y" or "Update package to X"
    version_range_match = title.match(/^(?<prefix>.+?)\s+(?<package_name>\S+) to (?<versions>[\d\.,\s]+)$/i)
    
    if version_range_match
      versions = version_range_match[:versions].split(',').map(&:strip)
      # For now, just use the last version as the new version
      return {
        prefix: version_range_match[:prefix],
        packages: [{
          name: version_range_match[:package_name],
          new_version: versions.last
        }],
        ecosystem: DEPENDABOT_ECOSYSTEMS[ecosystem.first],
      }
    end
    
    # Try simple bump format: "bump package" or "all: bump package"
    simple_bump_match = title.match(/^(?<prefix>.*?)(?:bump|Bump)\s+(?<package_name>\S+)$/i)
    
    if simple_bump_match && body.present?
      package_name = simple_bump_match[:package_name]
      # Look for version information in body
      version_match = body.match(/Updates `#{Regexp.escape(package_name)}` from (?<old_version>\S+) to (?<new_version>\S+)/)
      
      if version_match
        return {
          prefix: simple_bump_match[:prefix] + "bump",
          packages: [{
            name: package_name,
            old_version: version_match[:old_version],
            new_version: version_match[:new_version]
          }],
          ecosystem: DEPENDABOT_ECOSYSTEMS[ecosystem.first],
        }
      else
        # Return basic info even without version details
        return {
          prefix: simple_bump_match[:prefix] + "bump",
          packages: [{
            name: package_name
          }],
          ecosystem: DEPENDABOT_ECOSYSTEMS[ecosystem.first],
        }
      end
    end
    
    nil
  end
  
  def parse_group_update_table(body)
    packages = []
    
    # Look for markdown table with Package | From | To format
    table_match = body.match(/\| Package \| From \| To \|(.*?)(?=\n\n|\n$|\z)/m)
    
    if table_match
      table_content = table_match[1]
      
      # Parse each row of the table (skip header separator row)
      table_content.scan(/\|\s*(.+?)\s*\|\s*`?([^|`]+)`?\s*\|\s*`?([^|`]+)`?\s*\|/) do |package_cell, from_version, to_version|
        # Skip header separator row (contains --- | --- | ---)
        next if package_cell.strip.match?(/^-+$/)
        # Extract package name from markdown link or plain text
        package_name = if package_cell.include?('[')
          # Extract from [package-name](url) format
          package_cell.match(/\[([^\]]+)\]/)[1]
        else
          # Plain text package name
          package_cell.strip
        end
        
        packages << {
          name: package_name,
          old_version: from_version.strip,
          new_version: to_version.strip
        }
      end
    else
      # Look for individual "Updates `package` from X to Y" lines
      body.scan(/Updates `([^`]+)` from ([^\s]+) to ([^\s]+)/) do |package_name, from_version, to_version|
        packages << {
          name: package_name,
          old_version: from_version,
          new_version: to_version
        }
      end
      
      # Look for "Performed the following updates:" format
      if packages.empty? && body.include?("Performed the following updates:")
        # Parse "- Updated PackageName from X to Y in /path" lines
        body.scan(/- Updated ([^\s]+) from ([^\s]+) to ([^\s]+)(?: in ([^\n]+))?/) do |package_name, from_version, to_version, path|
          packages << {
            name: package_name,
            old_version: from_version,
            new_version: to_version,
            path: path&.strip
          }
        end
      end
    end
    
    packages
  end

  def update_dependabot_metadata
    metadata = parse_dependabot_metadata
    if metadata.present?
      update_column(:dependency_metadata, metadata)
      create_package_associations(metadata)
    end
  end

  def bot?
    user.ends_with?('[bot]')
  end
  
  def effective_state
    return 'merged' if pull_request && merged_at.present?
    state
  end
  
  def merged?
    pull_request && merged_at.present?
  end
  
  private
  
  def create_package_associations(metadata)
    return unless metadata[:ecosystem] && metadata[:packages]
    
    metadata[:packages].each do |package_data|
      next unless package_data[:name]
      
      # Find or create the package
      package = Package.find_or_create_by(
        name: package_data[:name],
        ecosystem: metadata[:ecosystem]
      )
      
      # Create the association if it doesn't exist
      issue_package = issue_packages.find_or_initialize_by(package: package)
      
      # Update the version information
      issue_package.assign_attributes(
        old_version: package_data[:old_version],
        new_version: package_data[:new_version],
        path: metadata[:path],
        update_type: determine_update_type(package_data[:old_version], package_data[:new_version]),
        pr_created_at: created_at
      )
      
      issue_package.save! if issue_package.changed?
    end
  end
  
  def determine_update_type(old_version, new_version)
    return nil unless old_version && new_version
    
    # Simple semantic version detection
    old_parts = old_version.gsub(/^v/, '').split('.').map(&:to_i)
    new_parts = new_version.gsub(/^v/, '').split('.').map(&:to_i)
    
    return nil if old_parts.length < 3 || new_parts.length < 3
    
    if new_parts[0] > old_parts[0]
      'major'
    elsif new_parts[1] > old_parts[1]
      'minor'
    elsif new_parts[2] > old_parts[2]
      'patch'
    else
      nil
    end
  rescue
    nil
  end
end