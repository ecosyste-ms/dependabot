class Advisory < ApplicationRecord
  has_many :issue_advisories, dependent: :destroy
  has_many :issues, through: :issue_advisories

  validates :uuid, presence: true, uniqueness: true
  
  after_save :clear_issue_advisory_cache
  after_destroy :clear_issue_advisory_cache

  scope :by_severity, ->(severity) { where(severity: severity.upcase) if severity.present? }
  scope :by_ecosystem, ->(ecosystem) { 
    where("EXISTS (SELECT 1 FROM jsonb_array_elements(packages) AS pkg WHERE pkg->>'ecosystem' = ?)", ecosystem) if ecosystem.present?
  }
  scope :by_package, ->(ecosystem, package_name) {
    where("EXISTS (SELECT 1 FROM jsonb_array_elements(packages) AS pkg WHERE pkg->>'ecosystem' = ? AND pkg->>'package_name' = ?)", ecosystem, package_name)
  }
  scope :by_repository_url, ->(url) { where(repository_url: url) if url.present? }
  scope :recent, -> { order(published_at: :desc) }
  scope :with_issues, -> { joins(:issues).distinct }
  scope :created_after, ->(date) { where('advisories.created_at > ?', date) if date.present? }
  scope :updated_after, ->(date) { where('advisories.updated_at > ?', date) if date.present? }
  scope :not_withdrawn, -> { where(withdrawn_at: nil) }

  def self.find_by_identifier(identifier)
    where("identifiers @> ?", [identifier].to_json).first
  end

  def cve_identifiers
    identifiers.select { |id| id.match?(/^CVE-\d{4}-\d+$/) }
  end

  def ghsa_identifiers
    identifiers.select { |id| id.match?(/^GHSA-/) }
  end

  def primary_identifier
    cve_identifiers.first || ghsa_identifiers.first || identifiers.first
  end

  def affects_package?(ecosystem, package_name)
    packages.any? do |pkg|
      pkg['ecosystem'] == ecosystem && pkg['package_name'] == package_name
    end
  end

  def affected_packages_for_ecosystem(ecosystem)
    packages.select { |pkg| pkg['ecosystem'] == ecosystem }
  end

  def severity_class
    case severity&.downcase
    when 'critical' then 'danger'
    when 'high' then 'warning' 
    when 'moderate', 'medium' then 'info'
    when 'low' then 'secondary'
    else 'light'
    end
  end

  def severity_badge_class
    "badge bg-#{severity_class}"
  end

  def to_param
    primary_identifier || uuid
  end

  def to_s
    title.presence || primary_identifier || uuid
  end
  
  def withdrawn?
    withdrawn_at.present?
  end

  def repository_urls
    urls = [repository_url].compact
    packages.each do |pkg|
      if pkg['repository_url'].present?
        urls << pkg['repository_url']
      end
    end
    urls.uniq
  end

  def ecosystems
    packages.map { |pkg| pkg['ecosystem'] }.uniq.sort
  end

  def package_names
    packages.map { |pkg| pkg['package_name'] }.uniq.sort
  end
  
  def self.sync_from_api(params = {})
    sync_params = {
      per_page: params[:per_page] || 1000,
      page: params[:page] || 1
    }
    
    sync_params[:ecosystem] = params[:ecosystem] if params[:ecosystem].present?
    sync_params[:severity] = params[:severity] if params[:severity].present?
    
    total_synced = 0
    current_page = sync_params[:page]
    
    loop do
      sync_params[:page] = current_page
      
      response = fetch_advisories_from_api(sync_params)
      break unless response[:success]
      
      advisories_data = response[:data]
      break if advisories_data.empty?
      
      advisories_data.each do |advisory_data|
        process_advisory_data(advisory_data)
        total_synced += 1
      end
      
      current_page += 1
    end
    
    total_synced
  end
  
  def self.sync_all
    sync_from_api
  end
  
  def self.sync_ecosystem(ecosystem)
    sync_from_api({ ecosystem: ecosystem })
  end
  
  def self.sync_hourly
    sync_all
  end
  
  def self.sync_fast
    sync_from_api_fast
  end
  
  def self.sync_from_api_fast(params = {})
    sync_params = {
      per_page: params[:per_page] || 1000,
      page: params[:page] || 1
    }
    
    sync_params[:ecosystem] = params[:ecosystem] if params[:ecosystem].present?
    sync_params[:severity] = params[:severity] if params[:severity].present?
    
    total_synced = 0
    current_page = sync_params[:page]
    
    loop do
      sync_params[:page] = current_page
      
      response = fetch_advisories_from_api(sync_params)
      break unless response[:success]
      
      advisories_data = response[:data]
      break if advisories_data.empty?
      
      advisories_data.each do |advisory_data|
        process_advisory_data_fast(advisory_data)
        total_synced += 1
      end
      
      current_page += 1
      puts "Page #{current_page - 1}: #{advisories_data.length} advisories, #{total_synced} total synced"
    end
    
    total_synced
  end
  
  private
  
  def self.fetch_advisories_from_api(params)
    begin
      response = Faraday.get("https://advisories.ecosyste.ms/api/v1/advisories", params) do |req|
        req.headers['Accept'] = 'application/json'
        req.headers['User-Agent'] = 'Dependabot-Tracker/1.0'
      end
      
      if response.success?
        data = JSON.parse(response.body)
        
        {
          success: true,
          data: data
        }
      else
        { success: false, error: "HTTP #{response.status}" }
      end
    rescue Faraday::Error => e
      { success: false, error: e.message }
    rescue => e
      { success: false, error: e.message }
    end
  end
  
  def self.process_advisory_data(advisory_data)
    advisory = find_or_initialize_by(uuid: advisory_data['uuid'])
    
    advisory.assign_attributes(
      url: advisory_data['url'],
      title: advisory_data['title'],
      description: advisory_data['description'],
      origin: advisory_data['origin'],
      severity: advisory_data['severity'],
      published_at: advisory_data['published_at'],
      withdrawn_at: advisory_data['withdrawn_at'],
      classification: advisory_data['classification'],
      cvss_score: advisory_data['cvss_score'],
      cvss_vector: advisory_data['cvss_vector'],
      references: advisory_data['references'] || [],
      source_kind: advisory_data['source_kind'],
      identifiers: advisory_data['identifiers'] || [],
      repository_url: advisory_data['repository_url'],
      blast_radius: advisory_data['blast_radius'],
      packages: advisory_data['packages'] || [],
      epss_percentage: advisory_data['epss_percentage'],
      epss_percentile: advisory_data['epss_percentile']
    )
    
    if advisory.save
      match_advisory_to_issues(advisory) if advisory.packages.present?
    end
  rescue => e
  end
  
  def self.process_advisory_data_fast(advisory_data)
    advisory = find_or_initialize_by(uuid: advisory_data['uuid'])
    
    advisory.assign_attributes(
      url: advisory_data['url'],
      title: advisory_data['title'],
      description: advisory_data['description'],
      origin: advisory_data['origin'],
      severity: advisory_data['severity'],
      published_at: advisory_data['published_at'],
      withdrawn_at: advisory_data['withdrawn_at'],
      classification: advisory_data['classification'],
      cvss_score: advisory_data['cvss_score'],
      cvss_vector: advisory_data['cvss_vector'],
      references: advisory_data['references'] || [],
      source_kind: advisory_data['source_kind'],
      identifiers: advisory_data['identifiers'] || [],
      repository_url: advisory_data['repository_url'],
      blast_radius: advisory_data['blast_radius'],
      packages: advisory_data['packages'] || [],
      epss_percentage: advisory_data['epss_percentage'],
      epss_percentile: advisory_data['epss_percentile']
    )
    
    advisory.save
  rescue => e
  end
  
  def self.match_advisory_to_issues(advisory)
    advisory.packages.each do |package_info|
      ecosystem = package_info['ecosystem']
      package_name = package_info['package_name']
      
      package = Package.find_by(ecosystem: ecosystem, name: package_name)
      next unless package
      
      package.issues.where.not(body: [nil, '']).find_each do |issue|
        next if issue.advisories.exists?(advisory.id)
        
        if mentions_advisory?(issue, advisory)
          issue.advisories << advisory
        end
      end
    end
  end
  
  def self.mentions_advisory?(issue, advisory)
    return false unless issue.body.present?
    
    advisory.identifiers.any? do |identifier|
      issue.body.include?(identifier)
    end
  end
  
  private
  
  def clear_issue_advisory_cache
    Issue.clear_advisory_identifiers_cache
  end
end