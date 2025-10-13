class Issue < ApplicationRecord
  belongs_to :repository
  belongs_to :host
  has_many :issue_packages, dependent: :destroy
  has_many :packages, through: :issue_packages
  has_many :issue_advisories, dependent: :destroy
  has_many :advisories, through: :issue_advisories

  counter_culture :repository, column_name: :issues_count

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
    
    # Git submodules
    'submodules' => 'submodules',
    'submodule' => 'submodules',
    'git-submodules' => 'submodules',
  }

  scope :with_dependency_metadata, -> { where('length(dependency_metadata::text) > 2') }
  scope :without_dependency_metadata, -> { where(dependency_metadata: nil) }
  scope :package_name, ->(package_name) { with_dependency_metadata.where("dependency_metadata->>'package_name' = ?", package_name) }
  scope :ecosystem, ->(ecosystem) { with_dependency_metadata.where("dependency_metadata->>'ecosystem' = ?", ecosystem) }
  scope :with_label, ->(label) { where("labels @> ARRAY[?]::varchar[]", label) }
  scope :has_body, -> { where.not(body: [nil, '']) }
  scope :security_prs, -> { has_body.where("body ~* 'CVE-\\d{4}-\\d+|GHSA-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}|RUSTSEC-\\d{4}-\\d+'") }
  scope :incomplete_prs, -> {
    where(pull_request: true)
      .where('"issues"."user" ILIKE ?', '%dependabot%')
      .where("title IS NULL OR body IS NULL OR node_id IS NULL")
  }

  def to_param
    number.to_s
  end

  def html_url
    host.host_instance.issue_url(repository, self)
  end

  def parse_dependabot_metadata
    # Return nil if we don't have enough data to parse
    return nil if title.blank?

    ecosystem = DEPENDABOT_ECOSYSTEMS.keys & labels.map(&:downcase)
    inferred_ecosystem = DEPENDABOT_ECOSYSTEMS[ecosystem.first]

    # Try requirement update formats first (before generic "from X to Y" pattern)
    if title.include?(" requirement ")
      # Format: "Update package requirement from X to Y" (handles complex version ranges)
      requirement_from_to_match = title.match(/^(?<prefix>.*?)(?<update_word>Update|update)\s+(?<package_name>\S+)\s+requirement\s+from\s+(?<old_version>.+?)\s+to\s+(?<new_version>.+?)(?:\s+in\s+(?<path>.+?))?$/i)
      if requirement_from_to_match
        prefix = requirement_from_to_match[:prefix].present? ? 
                 requirement_from_to_match[:prefix] + requirement_from_to_match[:update_word] :
                 requirement_from_to_match[:update_word]
        
        # For Python packages, remove extras (e.g., "moto[dynamodb]" -> "moto")
        package_name = requirement_from_to_match[:package_name].split('[').first
        repo_url = extract_repo_url_for_package(package_name)
        
        return {
          prefix: prefix,
          packages: [{
            name: package_name,
            old_version: requirement_from_to_match[:old_version].strip,
            new_version: requirement_from_to_match[:new_version].strip,
            repository_url: repo_url
          }],
          path: requirement_from_to_match[:path],
          ecosystem: infer_ecosystem_from_path(requirement_from_to_match[:path], inferred_ecosystem) || discover_ecosystem_from_repository_url(repo_url),
        }
      end
      
      # Format: "Update package requirement to X"
      requirement_to_match = title.match(/^(?<prefix>.*?)(?:Update|update)\s+(?<package_name>\S+)\s+requirement\s+to\s+(?<new_version>\S+)$/i)
      if requirement_to_match
        package_name = requirement_to_match[:package_name]
        repo_url = extract_repo_url_for_package(package_name)
        
        return {
          prefix: requirement_to_match[:prefix],
          packages: [{
            name: package_name,
            new_version: requirement_to_match[:new_version],
            repository_url: repo_url
          }],
          ecosystem: infer_ecosystem_from_path(nil, inferred_ecosystem) || discover_ecosystem_from_repository_url(repo_url),
        }
      end
    end
    
    # Try comma-separated packages format: "Bump package1, package2 from X to Y"
    comma_separated_match = title.match(/^(?<prefix>.+?)(?:\s+|:\s+)(?:bump\s+)?(?<package_names>[^,]+(?:,\s*[^,\s]+)+) from (?<old_version>\S+) to (?<new_version>\S+)(?: in (?<path>.+))?$/i)
    
    if comma_separated_match
      package_names = comma_separated_match[:package_names].split(',').map(&:strip)
      packages = package_names.map do |package_name|
        # For Python packages, remove extras (e.g., "moto[dynamodb]" -> "moto")
        clean_package_name = package_name.split('[').first.strip.gsub(/\s+/, '')
        repo_url = extract_repo_url_for_package(clean_package_name)
        {
          name: clean_package_name,
          old_version: comma_separated_match[:old_version],
          new_version: comma_separated_match[:new_version],
          repository_url: repo_url
        }
      end
      
      return {
        prefix: comma_separated_match[:prefix],
        packages: packages,
        path: comma_separated_match[:path],
        ecosystem: infer_ecosystem_from_path(comma_separated_match[:path], inferred_ecosystem),
      }
    end
    
    # Try single package format
    single_match = title.match(/^(?<prefix>.+?)(?:\s+|:\s+)(?:bump\s+)?(?<package_name>\S+) from (?<old_version>\S+) to (?<new_version>\S+)(?: in (?<path>.+))?$/)
    
    if single_match
      # For Python packages, remove extras (e.g., "moto[dynamodb]" -> "moto")
      package_name = single_match[:package_name].split('[').first.strip.gsub(/\s+/, '')
      repo_url = extract_repo_url_for_package(package_name)
      
      return {
        prefix: single_match[:prefix],
        packages: [{
          name: package_name,
          old_version: single_match[:old_version],
          new_version: single_match[:new_version],
          repository_url: repo_url
        }],
        path: single_match[:path],
        ecosystem: infer_ecosystem_from_path(single_match[:path], inferred_ecosystem) || discover_ecosystem_from_repository_url(repo_url),
      }
    end
    
    # Try multiple packages format: "Bump package1 and package2"
    multi_match = title.match(/^(?<prefix>.+?)(?:\s+|:\s+)(?:bump\s+)?(?<package_names>.+?)(?: in (?<path>.+))?$/)
    
    if multi_match && multi_match[:package_names].include?(' and ')
      package_names = multi_match[:package_names].split(' and ').map(&:strip)
      
      # Parse version information from body if available
      packages = package_names.map do |name|
        package_data = { name: name }
        
        # Extract repository URL for this package
        repo_url = extract_repo_url_for_package(name)
        package_data[:repository_url] = repo_url if repo_url
        
        if body.present?
          # Check if this package is being removed
          if body.match(/Removes `#{Regexp.escape(name)}`/) || body.match(/Removes \[#{Regexp.escape(name)}\]/)
            # This is a removal
            package_data[:old_version] = nil
            package_data[:new_version] = nil
            package_data[:is_removal] = true
          else
            # Look for "Updates `package_name` from X.X.X to Y.Y.Y"
            version_match = body.match(/Updates `#{Regexp.escape(name)}` from (?<old_version>\S+) to (?<new_version>\S+)/)
            if version_match
              package_data[:old_version] = version_match[:old_version]
              package_data[:new_version] = version_match[:new_version]
            end
          end
        end
        
        package_data
      end
      
      return {
        prefix: multi_match[:prefix],
        packages: packages,
        path: multi_match[:path],
        ecosystem: infer_ecosystem_from_path(multi_match[:path], inferred_ecosystem) || discover_ecosystem_from_repository_urls(packages),
      }
    end
    
    # Try single package without version in title: "Bump package-name"
    single_no_version_match = title.match(/^(?<prefix>.+?)(?:\s+|:\s+)(?:bump\s+)?(?<package_name>\S+)(?: in (?<path>.+))?$/i)
    
    if single_no_version_match && body.present?
      package_name = single_no_version_match[:package_name]
      repo_url = extract_repo_url_for_package(package_name)
      
      # Look for version information in body
      version_match = body.match(/Updates `#{Regexp.escape(package_name)}` from (?<old_version>\S+) to (?<new_version>\S+)/)
      
      if version_match
        return {
          prefix: single_no_version_match[:prefix],
          packages: [{
            name: package_name,
            old_version: version_match[:old_version],
            new_version: version_match[:new_version],
            repository_url: repo_url
          }],
          path: single_no_version_match[:path],
          ecosystem: infer_ecosystem_from_path(single_no_version_match[:path], inferred_ecosystem) || discover_ecosystem_from_repository_url(repo_url),
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
          ecosystem: infer_ecosystem_from_path(path, inferred_ecosystem) || discover_ecosystem_from_repository_urls(packages),
        }
      else
        # For group updates without parseable package details, return basic info
        return {
          prefix: group_match[:prefix],
          group_name: group_match[:group_name],
          update_count: update_count,
          packages: [],
          path: path,
          ecosystem: infer_ecosystem_from_path(path, inferred_ecosystem),
        }
      end
    end
    
    
    # Try version range format: "Bump package to X, Y" or "Update package to X"
    # Use [^\s,]+ to avoid capturing commas in package names
    version_range_match = title.match(/^(?<prefix>.+?)\s+(?<package_name>[^\s,]+) to (?<versions>[\d\.,\s]+)$/i)
    
    if version_range_match
      versions = version_range_match[:versions].split(',').map(&:strip)
      # For Python packages, remove extras (e.g., "moto[dynamodb]" -> "moto")
      package_name = version_range_match[:package_name].split('[').first.strip.gsub(/\s+/, '')
      repo_url = extract_repo_url_for_package(package_name)
      
      # For now, just use the last version as the new version
      return {
        prefix: version_range_match[:prefix],
        packages: [{
          name: package_name,
          new_version: versions.last,
          repository_url: repo_url
        }],
        ecosystem: infer_ecosystem_from_path(nil, inferred_ecosystem),
      }
    end
    
    # Try simple bump format: "bump package" or "all: bump package"
    # Use [^\s,]+ to avoid capturing commas in package names
    simple_bump_match = title.match(/^(?<prefix>.*?)(?:bump|Bump)\s+(?<package_name>[^\s,]+)$/i)
    
    if simple_bump_match && body.present?
      # For Python packages, remove extras (e.g., "moto[dynamodb]" -> "moto")
      package_name = simple_bump_match[:package_name].split('[').first.strip.gsub(/\s+/, '')
      repo_url = extract_repo_url_for_package(package_name)
      
      # Look for version information in body
      version_match = body.match(/Updates `#{Regexp.escape(package_name)}` from (?<old_version>\S+) to (?<new_version>\S+)/)
      
      if version_match
        return {
          prefix: simple_bump_match[:prefix] + "bump",
          packages: [{
            name: package_name,
            old_version: version_match[:old_version],
            new_version: version_match[:new_version],
            repository_url: repo_url
          }],
          ecosystem: infer_ecosystem_from_path(nil, inferred_ecosystem) || discover_ecosystem_from_repository_url(repo_url),
        }
      else
        # Return basic info even without version details
        return {
          prefix: simple_bump_match[:prefix] + "bump",
          packages: [{
            name: package_name,
            repository_url: repo_url
          }],
          ecosystem: infer_ecosystem_from_path(nil, inferred_ecosystem) || discover_ecosystem_from_repository_url(repo_url),
        }
      end
    end
    
    # Try to detect package removals from body text
    if body.present?
      removal_packages = parse_package_removals(body)
      if removal_packages.any?
        return {
          prefix: "Remove",
          packages: removal_packages,
          ecosystem: infer_ecosystem_from_path(nil, inferred_ecosystem) || discover_ecosystem_from_repository_urls(removal_packages),
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
          full_name = package_cell.match(/\[([^\]]+)\]/)[1]
          # For Python packages, remove extras and clean up spaces
          full_name.split('[').first.strip.gsub(/\s+/, '')
        else
          # Plain text package name, also handle extras and spaces
          package_cell.strip.split('[').first.strip.gsub(/\s+/, '')
        end
        
        repo_url = extract_repo_url_for_package(package_name)
        package_data = {
          name: package_name,
          old_version: from_version.strip,
          new_version: to_version.strip
        }
        package_data[:repository_url] = repo_url if repo_url
        packages << package_data
      end
    else
      # Look for individual "Updates `package` from X to Y" lines
      body.scan(/Updates `([^`]+)` from ([^\s]+) to ([^\s]+)/) do |package_name, from_version, to_version|
        # For Python packages, remove extras (e.g., "moto[dynamodb]" -> "moto")
        clean_package_name = package_name.split('[').first.strip.gsub(/\s+/, '')
        repo_url = extract_repo_url_for_package(clean_package_name)
        package_data = {
          name: clean_package_name,
          old_version: from_version,
          new_version: to_version
        }
        package_data[:repository_url] = repo_url if repo_url
        packages << package_data
      end
      
      # Look for "Performed the following updates:" format
      if packages.empty? && body.include?("Performed the following updates:")
        # Parse "- Updated PackageName from X to Y in /path" lines
        body.scan(/- Updated ([^\s]+) from ([^\s]+) to ([^\s]+)(?: in ([^\n]+))?/) do |package_name, from_version, to_version, path|
          # For Python packages, remove extras (e.g., "moto[dynamodb]" -> "moto")
          clean_package_name = package_name.split('[').first.strip.gsub(/\s+/, '')
          repo_url = extract_repo_url_for_package(clean_package_name)
          package_data = {
            name: clean_package_name,
            old_version: from_version,
            new_version: to_version,
            path: path&.strip
          }
          package_data[:repository_url] = repo_url if repo_url
          packages << package_data
        end
      end
    end
    
    packages
  end
  
  def parse_package_removals(body)
    packages = []
    
    # Look for "Removes `package-name`" patterns
    body.scan(/Removes `([^`]+)`/) do |package_name|
      # For Python packages, remove extras (e.g., "moto[dynamodb]" -> "moto")
      clean_package_name = package_name[0].split('[').first
      repo_url = extract_repo_url_for_package(clean_package_name)
      package_data = {
        name: clean_package_name,
        old_version: nil, # We don't usually get version info for removals
        new_version: nil
      }
      package_data[:repository_url] = repo_url if repo_url
      packages << package_data
    end
    
    # Look for "Removes [package-name]" patterns
    body.scan(/Removes \[([^\]]+)\]/) do |package_name|
      # For Python packages, remove extras (e.g., "moto[dynamodb]" -> "moto")
      clean_package_name = package_name[0].split('[').first
      repo_url = extract_repo_url_for_package(clean_package_name)
      package_data = {
        name: clean_package_name,
        old_version: nil,
        new_version: nil
      }
      package_data[:repository_url] = repo_url if repo_url
      packages << package_data
    end
    
    # Look for "- Removes package-name" patterns in lists
    body.scan(/^[\s]*[-*]\s+Removes\s+([^\s\n]+)/i) do |package_name|
      # For Python packages, remove extras (e.g., "moto[dynamodb]" -> "moto")
      clean_package_name = package_name[0].split('[').first
      repo_url = extract_repo_url_for_package(clean_package_name)
      package_data = {
        name: clean_package_name,
        old_version: nil,
        new_version: nil
      }
      package_data[:repository_url] = repo_url if repo_url
      packages << package_data
    end
    
    packages.uniq { |p| p[:name] }
  end

  def update_dependabot_metadata
    metadata = parse_dependabot_metadata
    affected_package_ids = if metadata.present?
      update_column(:dependency_metadata, metadata)
      create_package_associations(metadata)
    else
      []
    end
    
    # Also parse and link any security advisories mentioned in the PR
    parse_and_link_advisories
    
    # Return the package IDs that were affected
    affected_package_ids || []
  end

  def bot?
    user.ends_with?('[bot]')
  end
  
  def effective_state
    return 'merged' if pull_request && merged_at.present?
    state || 'open'  # Default to 'open' if state is somehow nil
  end
  
  def merged?
    pull_request && merged_at.present?
  end
  
  def user_avatar_url
    return "https://github.com/dependabot.png" if user.blank?
    
    # Remove [bot] suffix for GitHub avatar URLs
    username = user.gsub(/\[bot\]$/, '')
    "https://github.com/#{username}.png"
  end
  
  def auto_closed_as_outdated?
    closed_by.present? && closed_by == user && merged_at.blank?
  end
  
  private
  
  def infer_ecosystem_from_path(path, label_ecosystem)
    # Try to infer ecosystem from path if labels don't provide it
    return label_ecosystem if label_ecosystem
    
    case path
    when '/.github/workflows'
      'actions'
    else
      nil
    end
  end
  
  def create_package_associations(metadata)
    return [] unless metadata[:ecosystem] && metadata[:packages]
    
    affected_package_ids = []
    
    metadata[:packages].each do |package_data|
      next unless package_data[:name]
      
      # Find or create the package with proper race condition handling
      begin
        package = Package.find_or_create_by!(
          name: package_data[:name], 
          ecosystem: metadata[:ecosystem]
        )
      rescue ActiveRecord::RecordNotUnique
        # Handle race condition - another process created the package between find and create
        package = Package.find_by(name: package_data[:name], ecosystem: metadata[:ecosystem])
        unless package
          Rails.logger.warn "Race condition handling failed for package #{package_data[:name]} (#{metadata[:ecosystem]}) - could not find existing record"
          next # Skip this package and continue with the rest
        end
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.warn "Failed to create package #{package_data[:name]} (#{metadata[:ecosystem]}): #{e.message}"
        next # Skip this package and continue with the rest
      end
      
      # Create or find the association with race condition handling
      update_type = if package_data[:is_removal]
        'removal'
      else
        determine_update_type(package_data[:old_version], package_data[:new_version])
      end
      
      begin
        # Try to create the association
        issue_package = issue_packages.create!(
          package: package,
          old_version: package_data[:old_version],
          new_version: package_data[:new_version],
          path: metadata[:path],
          update_type: update_type,
          pr_created_at: created_at
        )
        affected_package_ids << package.id
      rescue ActiveRecord::RecordNotUnique, PG::UniqueViolation
        # Handle race condition - association already exists, skip it
        Rails.logger.info "IssuePackage already exists for issue #{id} and package #{package.id}, skipping"
        affected_package_ids << package.id
      rescue ActiveRecord::RecordInvalid => e
        # already exists
      end
    end
    
    affected_package_ids
  end
  
  def determine_update_type(old_version, new_version)
    # Check for removals (no new version)
    return 'removal' if old_version.present? && new_version.blank?
    
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
  
  def extract_repo_url_for_package(package_name)
    return nil unless body.present?
    
    # Look for markdown links: [package-name](repo-url)
    escaped_name = Regexp.escape(package_name)
    pattern = Regexp.new("\\[#{escaped_name}\\]\\(([^)]+)\\)")
    match = body.match(pattern)
    
    if match && match[1].include?('github.com')
      return clean_github_url(match[1])
    end
    
    # Also try without escaping for simple package names
    simple_pattern = Regexp.new("\\[#{Regexp.escape(package_name)}\\]\\(([^)]+)\\)")
    match = body.match(simple_pattern)
    if match && match[1].include?('github.com')
      return clean_github_url(match[1])
    end
    
    nil
  end
  
  def clean_github_url(url)
    # Remove tree/HEAD paths, blob paths, and other GitHub-specific paths
    # Convert https://github.com/owner/repo/tree/HEAD/path to https://github.com/owner/repo
    cleaned = url.gsub(%r{/(tree|blob|commits?)/[^/]+(/.*)?$}, '')
    
    # Also remove trailing paths like /types/node
    # Match pattern: https://github.com/owner/repo and stop there
    match = cleaned.match(%r{^(https://github\.com/[^/]+/[^/?#]+)})
    match ? match[1] : cleaned
  end
  
  def discover_ecosystem_from_repository_url(repository_url)
    return nil unless repository_url
    
    # First, look for existing packages in our database with this repository URL (case insensitive)
    existing_package = Package.where("LOWER(repository_url) = LOWER(?)", repository_url).first
    return existing_package.ecosystem if existing_package
    
    # If not found locally, try packages.ecosyste.ms API
    fetch_ecosystem_from_packages_api(repository_url)
  end
  
  def discover_ecosystem_from_repository_urls(packages)
    return nil unless packages.present?
    
    packages.each do |package_data|
      repository_url = package_data[:repository_url]
      next unless repository_url
      
      ecosystem = discover_ecosystem_from_repository_url(repository_url)
      return ecosystem if ecosystem
    end
    
    nil
  end
  
  def fetch_ecosystem_from_packages_api(repository_url)
    begin
      # URL encode the repository URL parameter
      encoded_url = CGI.escape(repository_url)
      
      response = Faraday.get("https://packages.ecosyste.ms/api/v1/packages/lookup?repository_url=#{encoded_url}")
      
      if response.success?
        data = JSON.parse(response.body)
        
        # Create reverse mapping from PURL types to Dependabot ecosystem names
        # Handle duplicates by preferring exact matches (e.g., 'maven' over 'gradle' for maven PURL type)
        purl_to_ecosystem = {}
        Package::ECOSYSTEM_TO_PURL_TYPE.each do |ecosystem, purl_type|
          # Prefer exact matches (e.g., maven -> maven over gradle -> maven)
          if purl_to_ecosystem[purl_type].nil? || purl_type == ecosystem
            purl_to_ecosystem[purl_type] = ecosystem
          end
        end
        supported_purl_types = Package::ECOSYSTEM_TO_PURL_TYPE.values.uniq
        
        # Filter packages to only include Dependabot-supported ecosystems
        supported_packages = data.select do |package|
          ecosystem = package['ecosystem']
          ecosystem && supported_purl_types.include?(ecosystem)
        end
        
        # Return the Dependabot ecosystem name for the first supported package
        first_supported_package = supported_packages.first
        if first_supported_package
          ecosyste_ms_ecosystem = first_supported_package['ecosystem']
          return purl_to_ecosystem[ecosyste_ms_ecosystem] || ecosyste_ms_ecosystem
        end
      end
    rescue => e
      Rails.logger.warn "Failed to fetch ecosystem from packages API for #{repository_url}: #{e.message}"
      nil
    end
    
    nil
  end
  
  public
  
  def parse_and_link_advisories
    return unless body.present?
    
    advisory_identifiers = extract_advisory_identifiers(body)
    
    advisory_identifiers.each do |identifier|
      advisory = Advisory.find_by_identifier(identifier)
      
      if advisory
        advisories << advisory unless advisories.exists?(advisory.id)
      end
    end
  end
  
  def extract_advisory_identifiers(text)
    self.class.cached_advisory_identifiers.select do |identifier|
      text.include?(identifier)
    end
  end
  
  def self.cached_advisory_identifiers
    @cached_advisory_identifiers ||= Advisory.pluck(:identifiers).flatten.uniq
  end
  
  def self.clear_advisory_identifiers_cache
    @cached_advisory_identifiers = nil
  end
  
  def security_related?
    return true if advisories.any?
    
    security_keywords = [
      'security fix',
      'security update',
      'vulnerability',
      'CVE-',
      'GHSA-',
      'RUSTSEC-',
      'security patch'
    ]
    
    return false unless body.present?
    
    security_keywords.any? { |keyword| body.downcase.include?(keyword.downcase) }
  end
  
  def has_security_identifier?
    return false unless body.present?
    
    # Check for CVE, GHSA, and other security advisory identifiers
    body.match?(/CVE-\d{4}-\d+|GHSA-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}|RUSTSEC-\d{4}-\d+/i)
  end
  
  def advisory_severity
    severities = advisories.pluck(:severity).compact
    return nil if severities.empty?

    severity_order = %w[CRITICAL HIGH MODERATE LOW]
    severities.min_by { |s| severity_order.index(s.upcase) || 999 }
  end

  def enrich_from_github_api
    return false unless pull_request && host.name == 'GitHub'
    return false unless repository

    begin
      # Use the host's API client to fetch PR details
      github = host.host_instance
      api_client = github.send(:api_client)

      # Fetch the full PR details from GitHub API
      pr_data = api_client.pull_request(repository.full_name, number)

      # Map the PR data to attributes
      attrs = {}
      attrs[:node_id] = pr_data.node_id if pr_data.node_id && node_id.blank?
      attrs[:title] = pr_data.title if pr_data.title && title.blank?
      attrs[:body] = pr_data.body if pr_data.body && body.blank?
      attrs[:state] = pr_data.state if pr_data.state
      attrs[:locked] = pr_data.locked unless locked
      attrs[:comments_count] = pr_data.comments if pr_data.comments
      attrs[:labels] = pr_data.labels.map(&:name) if pr_data.labels && labels.blank?
      attrs[:assignees] = pr_data.assignees.map(&:login) if pr_data.assignees && assignees.blank?
      attrs[:author_association] = pr_data.author_association if pr_data.author_association
      attrs[:state_reason] = pr_data.state_reason if pr_data.state_reason
      attrs[:merged_at] = pr_data.merged_at if pr_data.merged_at
      attrs[:merged_by] = pr_data.merged_by&.login if pr_data.merged_by
      attrs[:closed_by] = pr_data.closed_by&.login if pr_data.closed_by
      attrs[:draft] = pr_data.draft unless draft
      attrs[:mergeable] = pr_data.mergeable unless mergeable
      attrs[:mergeable_state] = pr_data.mergeable_state if pr_data.mergeable_state
      attrs[:rebaseable] = pr_data.rebaseable unless rebaseable
      attrs[:review_comments_count] = pr_data.review_comments if pr_data.review_comments
      attrs[:commits_count] = pr_data.commits if pr_data.commits
      attrs[:additions] = pr_data.additions if pr_data.additions
      attrs[:deletions] = pr_data.deletions if pr_data.deletions
      attrs[:changed_files] = pr_data.changed_files if pr_data.changed_files

      # Update the issue with new attributes
      update!(attrs) if attrs.any?

      # Parse and update metadata
      update_dependabot_metadata if attrs[:title] || attrs[:body]

      true
    rescue Octokit::NotFound
      Rails.logger.warn "PR not found on GitHub: #{repository.full_name}##{number}"
      false
    rescue Octokit::Unauthorized, Octokit::Forbidden => e
      Rails.logger.warn "GitHub API auth error for #{repository.full_name}##{number}: #{e.message}"
      false
    rescue => e
      Rails.logger.error "Failed to enrich PR #{repository.full_name}##{number}: #{e.message}"
      false
    end
  end

  def self.enrich_incomplete_prs(limit: 1000, max_duration: 55.minutes)
    start_time = Time.current
    enriched_count = 0
    failed_count = 0

    incomplete_prs.limit(limit).find_each do |issue|
      # Check if we've exceeded the time limit
      if Time.current - start_time >= max_duration
        Rails.logger.info "Stopping enrichment: reached time limit of #{max_duration / 60} minutes"
        break
      end

      if issue.enrich_from_github_api
        enriched_count += 1
      else
        failed_count += 1
      end

      # Sleep to respect rate limits (5000 requests/hour = 0.72s per request)
      # Use 0.8s to be conservative and leave headroom
      sleep 0.8
    end

    { enriched: enriched_count, failed: failed_count, duration: (Time.current - start_time).to_i }
  end
end