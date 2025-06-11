class AdvisoriesController < ApplicationController
  def index
    @scope = Advisory.not_withdrawn
    
    # Apply filters
    @scope = @scope.by_severity(params[:severity]) if params[:severity].present?
    @scope = @scope.by_ecosystem(params[:ecosystem]) if params[:ecosystem].present?
    @scope = @scope.by_package(params[:ecosystem], params[:package_name]) if params[:ecosystem].present? && params[:package_name].present?
    @scope = @scope.by_repository_url(params[:repository_url]) if params[:repository_url].present?
    
    # Search by identifier
    if params[:q].present?
      @scope = @scope.where("identifiers @> ?", [params[:q]].to_json)
    end
    
    # Sort
    @sort = params[:sort] || 'published_at'
    @order = params[:order] || 'desc'
    
    case @sort
    when 'published_at'
      @scope = @scope.order(published_at: @order)
    when 'severity'
      # Custom severity ordering
      severity_order = case @order
      when 'asc'
        "CASE severity WHEN 'LOW' THEN 1 WHEN 'MODERATE' THEN 2 WHEN 'MEDIUM' THEN 2 WHEN 'HIGH' THEN 3 WHEN 'CRITICAL' THEN 4 ELSE 0 END"
      else
        "CASE severity WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MODERATE' THEN 3 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 4 ELSE 5 END"
      end
      @scope = @scope.order(Arel.sql(severity_order))
    when 'issues_count'
      @scope = @scope.order(issues_count: @order)
    when 'merge_rate'
      @scope = @scope.order(merge_rate: @order)
    else
      @scope = @scope.order(published_at: :desc)
    end
    
    @pagy, @advisories = pagy(@scope)
    
    # Stats for sidebar
    @severity_counts = Advisory.group(:severity).count
    @total_count = Advisory.count
    @with_issues_count = Advisory.with_issues.count
  end
  
  def show
    @advisory = Advisory.find_by(uuid: params[:id]) || Advisory.find_by_identifier(params[:id])
    raise ActiveRecord::RecordNotFound unless @advisory
    
    @issues_scope = @advisory.issues.includes(:repository, :host, packages: [])
    
    # Filter issues by state
    if params[:state].present?
      case params[:state]
      when 'open'
        @issues_scope = @issues_scope.open
      when 'closed'
        @issues_scope = @issues_scope.not_merged
      when 'merged'
        @issues_scope = @issues_scope.merged
      end
    end
    
    @pagy, @issues = pagy(@issues_scope.order(created_at: :desc))
  end
  
  def feed
    @advisories = Advisory.not_withdrawn.recent.limit(50)
    
    expires_in 1.hour, public: true
    render 'feed', formats: [:atom]
  end
  
  def issues_feed
    @advisory = Advisory.find_by(uuid: params[:id]) || Advisory.find_by_identifier(params[:id])
    raise ActiveRecord::RecordNotFound unless @advisory
    
    @issues = @advisory.issues.includes(:repository, :host, packages: [])
                              .order(created_at: :desc)
                              .limit(50)
    
    expires_in 1.hour, public: true
    render 'issues_feed', formats: [:atom]
  end
end