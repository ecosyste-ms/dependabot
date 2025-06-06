class Package < ApplicationRecord
  has_many :issue_packages, dependent: :destroy
  has_many :issues, through: :issue_packages
  
  validates :name, presence: true
  validates :ecosystem, presence: true
  validates :name, uniqueness: { scope: :ecosystem }
  
  scope :by_ecosystem, ->(ecosystem) { where(ecosystem: ecosystem) }
  
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
    'actions' => 'github',  # GitHub Actions
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
end
