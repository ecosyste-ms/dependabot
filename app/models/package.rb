class Package < ApplicationRecord
  has_many :issue_packages, dependent: :destroy
  has_many :issues, through: :issue_packages
  
  validates :name, presence: true
  validates :ecosystem, presence: true
  validates :name, uniqueness: { scope: :ecosystem }
  
  scope :by_ecosystem, ->(ecosystem) { where(ecosystem: ecosystem) }
  scope :without_metadata, -> { where("LENGTH(metadata::text) = 2") }
  
  after_create :sync_async
  
  # Mapping from GitHub ecosystem names to PURL type names
  # Based on https://github.com/package-url/purl-spec/blob/main/PURL-TYPES.rst
  ECOSYSTEM_TO_PURL_TYPE = {
    'npm' => 'npm',
    'rubygems' => 'gem',
    'pip' => 'pypi',
    'go' => 'golang',
    'maven' => 'maven',
    'gradle' => 'maven',  # Gradle uses Maven format
    'nuget' => 'nuget',
    'cargo' => 'cargo',
    'docker' => 'docker',
    'hex' => 'hex',
    'packagist' => 'composer',
    'pub' => 'pub',
    'terraform' => 'terraform',
    'actions' => 'githubactions',  # GitHub Actions
    'elm' => 'elm',
    'swift' => 'swift',
    'cocoapods' => 'cocoapods',
    'carthage' => 'carthage',
    'conda' => 'conda',
    'helm' => 'helm',
    'kubernetes' => 'k8s'
  }.freeze
  
  def to_s
    "#{name} (#{ecosystem})"
  end
  
  def purl_type
    ECOSYSTEM_TO_PURL_TYPE[ecosystem] || ecosystem
  end
  
  def purl
    "pkg:#{purl_type}/#{name}"
  end
  
  def to_param
    "#{ecosystem}/#{CGI.escape(name)}"
  end
  
  def fetch_metadata_from_ecosyste_ms
    return metadata if metadata.present? && metadata != {}
    
    purl_encoded = CGI.escape(purl)
    url = "https://packages.ecosyste.ms/api/v1/packages/lookup?purl=#{purl_encoded}"
    
    begin
      response = Faraday.get(url)
      if response.success?
        data_array = JSON.parse(response.body)
        # API returns an array, we want the first item
        data = data_array.first || {}
        return {} if data.empty?
        # Update metadata and repository_url if available
        update_columns(
          metadata: data,
          repository_url: data['repository_url'] || repository_url
        )
        
        data
      else
        Rails.logger.warn "Failed to fetch metadata for #{purl}: #{response.status}"
        {}
      end
    rescue => e
      Rails.logger.error "Error fetching metadata for #{purl}: #{e.message}"
      {}
    end
  end
  
  def infer_ecosystem_from_metadata
    return ecosystem if ecosystem.present?
    
    metadata_info = fetch_metadata_from_ecosyste_ms
    
    # Extract ecosystem from the PURL type in the metadata
    if metadata_info['purl']
      purl_parts = metadata_info['purl'].split(':')
      if purl_parts.length >= 2
        purl_type = purl_parts[1]
        
        # Map PURL types back to our ecosystem names
        inferred_ecosystem = case purl_type
        when 'npm' then 'npm'
        when 'pypi' then 'pip'
        when 'gem' then 'rubygems'
        when 'maven' then 'maven'
        when 'cargo' then 'cargo'
        when 'nuget' then 'nuget'
        when 'golang' then 'go'
        when 'composer' then 'packagist'
        when 'github' then 'actions'
        else purl_type
        end
        
        update_column(:ecosystem, inferred_ecosystem) if inferred_ecosystem != ecosystem
        return inferred_ecosystem
      end
    end
    
    ecosystem
  end
  
  def sync_async
    SyncPackageWorker.perform_async(id)
  end
  
  def sync
    fetch_metadata_from_ecosyste_ms
  end
end
