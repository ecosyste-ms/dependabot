class Api::V1::AdvisoriesController < Api::V1::ApplicationController
  def index
    @scope = Advisory.all
    
    # Apply filters
    @scope = @scope.by_severity(params[:severity]) if params[:severity].present?
    @scope = @scope.by_ecosystem(params[:ecosystem]) if params[:ecosystem].present?
    @scope = @scope.by_package(params[:ecosystem], params[:package_name]) if params[:ecosystem].present? && params[:package_name].present?
    @scope = @scope.by_repository_url(params[:repository_url]) if params[:repository_url].present?
    @scope = @scope.created_after(params[:created_after]) if params[:created_after].present?
    @scope = @scope.updated_after(params[:updated_after]) if params[:updated_after].present?
    
    # Search by identifier
    if params[:identifier].present?
      @scope = @scope.where("identifiers @> ?", [params[:identifier]].to_json)
    end
    
    # Sort
    sort = params[:sort] || 'published_at'
    order = params[:order] || 'desc'
    
    case sort
    when 'published_at'
      @scope = @scope.order(published_at: order)
    when 'severity'
      severity_order = case order
      when 'asc'
        "CASE severity WHEN 'LOW' THEN 1 WHEN 'MODERATE' THEN 2 WHEN 'MEDIUM' THEN 2 WHEN 'HIGH' THEN 3 WHEN 'CRITICAL' THEN 4 ELSE 0 END"
      else
        "CASE severity WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MODERATE' THEN 3 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 4 ELSE 5 END"
      end
      @scope = @scope.order(Arel.sql(severity_order))
    else
      @scope = @scope.order(published_at: :desc)
    end
    
    @pagy, @advisories = pagy_countless(@scope)
  end
  
  def show
    @advisory = Advisory.find_by(uuid: params[:id]) || Advisory.find_by_identifier(params[:id])
    raise ActiveRecord::RecordNotFound unless @advisory
  end
  
  def issues
    @advisory = Advisory.find_by(uuid: params[:id]) || Advisory.find_by_identifier(params[:id])
    raise ActiveRecord::RecordNotFound unless @advisory
    
    @scope = @advisory.issues.includes(:repository)
    
    # Filter by state
    if params[:state].present?
      case params[:state]
      when 'open'
        @scope = @scope.open
      when 'closed'
        @scope = @scope.closed
      when 'merged'
        @scope = @scope.merged
      end
    end
    
    @pagy, @issues = pagy_countless(@scope.order(created_at: :desc))
  end
  
  def lookup
    purls = Array(params[:purl]) + Array(params[:purls])
    
    if purls.empty?
      render json: { error: 'purl parameter required' }, status: :bad_request
      return
    end
    
    results = {}
    
    purls.each do |purl_string|
      begin
        purl = parse_purl(purl_string)
        advisories = find_advisories_for_purl(purl)
        
        results[purl_string] = {
          advisories: advisories.map { |advisory| advisory_json(advisory) },
          vulnerable: advisories.any?,
          count: advisories.count
        }
      rescue => e
        results[purl_string] = {
          error: "Invalid PURL format: #{e.message}",
          vulnerable: false,
          count: 0
        }
      end
    end
    
    render json: results
  end
  
  private
  
  def parse_purl(purl_string)
    # Parse pkg:npm/express@4.17.1 format
    match = purl_string.match(/^pkg:([^\/]+)\/([^@]+)(?:@(.+))?$/)
    raise "Invalid PURL format" unless match
    
    {
      ecosystem: normalize_ecosystem(match[1]),
      name: match[2],
      version: match[3]
    }
  end
  
  def normalize_ecosystem(purl_type)
    # Map PURL types to our ecosystem names
    {
      'npm' => 'npm',
      'pypi' => 'pip', 
      'maven' => 'maven',
      'gem' => 'rubygems',
      'cargo' => 'cargo',
      'nuget' => 'nuget',
      'golang' => 'go'
    }[purl_type] || purl_type
  end
  
  def find_advisories_for_purl(purl)
    advisories = Advisory.by_package(purl[:ecosystem], purl[:name])
    
    # If version specified, filter to advisories affecting that version
    if purl[:version].present?
      advisories = advisories.select do |advisory|
        advisory.packages.any? do |pkg|
          pkg['ecosystem'] == purl[:ecosystem] && 
          pkg['package_name'] == purl[:name] &&
          version_affected?(purl[:version], pkg['versions'])
        end
      end
    end
    
    advisories
  end
  
  def version_affected?(version, version_ranges)
    return true if version_ranges.blank?
    
    version_ranges.any? do |range|
      # Simple check - in production would use proper semver library
      range['vulnerable_version_range']&.include?(version) ||
      range['vulnerable_version_range'] == '<= ' + version ||
      range['vulnerable_version_range'] == '< ' + next_version(version)
    end
  end
  
  def advisory_json(advisory)
    {
      uuid: advisory.uuid,
      identifiers: advisory.identifiers,
      severity: advisory.severity,
      title: advisory.title,
      published_at: advisory.published_at,
      dependabot_prs: advisory.issues_count
    }
  end
end