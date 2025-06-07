require 'package_url'

class Api::V1::PackagesController < Api::V1::ApplicationController
  def index
    scope = Package.includes(:issues)
    
    # Filter by ecosystem
    if params[:ecosystem].present?
      scope = scope.by_ecosystem(params[:ecosystem])
    end
    
    # Search by name
    if params[:name].present?
      scope = scope.where("name ILIKE ?", "%#{params[:name]}%")
    end
    
    # Filter by repository URL
    if params[:repository_url].present?
      scope = scope.where("repository_url ILIKE ?", "%#{params[:repository_url]}%")
    end
    
    # Order by issues count by default
    order = params[:sort] == 'name' ? :name : :issues_count
    direction = params[:order] == 'asc' ? :asc : :desc
    scope = scope.order(order => direction)
    
    @pagy, @packages = pagy(scope)
    
    fresh_when(@packages, public: true)
  end
  
  def show
    @package = Package.includes(:issues, :issue_packages).find_by!(
      ecosystem: params[:ecosystem], 
      name: params[:name]
    )
    
    fresh_when(@package, public: true)
  end
  
  def lookup
    purl_string = params[:purl]
    
    if purl_string.blank?
      render json: { error: 'PURL parameter is required' }, status: :bad_request
      return
    end
    
    begin
      # Handle scoped npm packages - encode @ symbol in namespace
      purl_param = purl_string.gsub('pkg:npm/@', 'pkg:npm/%40')
      
      # Parse the PURL using the packageurl-ruby gem
      purl = PackageURL.parse(purl_param)
      
      # Convert PURL type to Dependabot ecosystem
      ecosystem = purl_type_to_ecosystem(purl.type)
      
      if ecosystem.nil?
        render json: { error: "Unsupported PURL type: #{purl.type}" }, status: :bad_request
        return
      end
      
      # Handle different package name formats based on ecosystem
      package_name = build_package_name(purl)
      
      # Look up package by ecosystem and name (ignoring version)
      @package = Package.find_by(ecosystem: ecosystem, name: package_name)
      
      if @package
        fresh_when(@package, public: true)
        render 'show'
      else
        render json: { error: 'Package not found' }, status: :not_found
      end
      
    rescue PackageURL::InvalidPackageURL => e
      render json: { error: "Invalid PURL format: #{e.message}" }, status: :bad_request
    rescue => e
      render json: { error: 'Package lookup failed' }, status: :internal_server_error
    end
  end
  
  def ecosystems
    @ecosystems = Package.distinct.pluck(:ecosystem).compact.sort
    
    render json: @ecosystems
  end
  
  private
  
  def build_package_name(purl)
    # Handle different package name formats based on ecosystem
    case purl.type
    when 'docker'
      # Docker packages: handle library namespace for official images
      namespace = purl.namespace || 'library'
      [namespace, purl.name].join('/')
    when 'maven'
      # Maven packages: group:artifact format
      [purl.namespace, purl.name].compact.join(':')
    when 'npm'
      # NPM packages: handle scoped packages
      if purl.namespace
        # Namespace already includes @ symbol when parsed from encoded PURL
        "#{purl.namespace}/#{purl.name}"
      else
        purl.name
      end
    when 'nuget', 'pypi', 'gem', 'cargo'
      # These ecosystems typically don't use namespaces in the same way
      purl.name
    else
      # Default: just use the name, optionally with namespace
      if purl.namespace
        "#{purl.namespace}/#{purl.name}"
      else
        purl.name
      end
    end
  end
  
  def purl_type_to_ecosystem(purl_type)
    # Create reverse mapping from PURL type to Dependabot ecosystem
    mapping = {
      'npm' => 'npm',
      'gem' => 'rubygems',
      'pypi' => 'pip',
      'golang' => 'go',
      'maven' => 'maven',
      'nuget' => 'nuget',
      'cargo' => 'cargo',
      'docker' => 'docker',
      'hex' => 'hex',
      'composer' => 'packagist',
      'pub' => 'pub',
      'terraform' => 'terraform',
      'githubactions' => 'actions',
      'elm' => 'elm',
      'swift' => 'swift',
      'cocoapods' => 'cocoapods',
      'carthage' => 'carthage',
      'conda' => 'conda',
      'helm' => 'helm',
      'k8s' => 'kubernetes'
    }
    
    mapping[purl_type]
  end
end