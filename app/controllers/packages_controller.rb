class PackagesController < ApplicationController
  before_action :set_package, only: [:show, :feed]

  def index
    @ecosystem_counts = Package.group(:ecosystem).count
    @ecosystems = @ecosystem_counts.sort_by { |ecosystem, count| -count }.map(&:first)
    @total_packages = Package.count
    
    # Fetch a sample package from each ecosystem to get registry metadata
    @ecosystem_registries = {}
    @ecosystems.each do |ecosystem|
      sample_package = Package.where(ecosystem: ecosystem)
                             .where.not(metadata: nil)
                             .where("LENGTH(metadata::text) > 2")
                             .first
      if sample_package&.metadata&.dig('registry')
        registry = sample_package.metadata['registry']
        @ecosystem_registries[ecosystem] = registry
        
        # Calculate "per packita" - percentage of total registry packages with Dependabot activity
        if registry['packages_count'] && registry['packages_count'] > 0
          dependabot_packages = @ecosystem_counts[ecosystem]
          total_registry_packages = registry['packages_count']
        end
      end
    end
  end

  def ecosystem
    @ecosystem = params[:ecosystem]
    
    # Get packages for pagination
    packages = Package.where(ecosystem: @ecosystem)
                     .where('issues_count > 0')
                     .order('issues_count DESC, name ASC')
    
    @pagy, @packages = pagy_countless(packages)
    
    # Calculate ecosystem-level statistics
    all_packages = Package.where(ecosystem: @ecosystem)
    issue_packages = IssuePackage.joins(:package).where(packages: { ecosystem: @ecosystem })
    
    unique_repositories_count = Issue.joins(issue_packages: :package)
                                  .where(packages: { ecosystem: @ecosystem })
                                  .distinct.count(:repository_id)
    
    # Get registry metadata for this ecosystem
    sample_package = Package.where(ecosystem: @ecosystem)
                           .where.not(metadata: nil)
                           .where("LENGTH(metadata::text) > 2")
                           .first
    @registry_data = sample_package&.metadata&.dig('registry')
    
    # Calculate PR status breakdown
    pr_status_scope = Issue.joins(issue_packages: :package).where(packages: { ecosystem: @ecosystem })
    open_count = pr_status_scope.where(state: 'open').count
    merged_count = pr_status_scope.where.not(merged_at: nil).count
    closed_count = pr_status_scope.where(state: 'closed', merged_at: nil).count
    
    @stats = {
      total_packages: all_packages.count,
      total_updates: issue_packages.count,
      unique_repositories: unique_repositories_count,
      update_types: issue_packages.group(:update_type).count,
      pr_status: {
        open: open_count,
        merged: merged_count,
        closed: closed_count
      },
      recent_activity: issue_packages.where('pr_created_at > ?', 30.days.ago).count,
      avg_updates_per_package: all_packages.where('issues_count > 0').average(:issues_count)&.round(1),
      avg_updates_per_repo: (unique_repositories_count > 0 ? (issue_packages.count.to_f / unique_repositories_count).round(1) : 0),
      most_updated_package: all_packages.order(:issues_count).last,
      latest_update: Issue.joins(issue_packages: :package)
                          .where(packages: { ecosystem: @ecosystem })
                          .order(:created_at).last
    }
    
    # Calculate per packita if registry data is available
    if @registry_data && @registry_data['packages_count'] && @registry_data['packages_count'] > 0
      @per_packita = (@stats[:total_packages].to_f / @registry_data['packages_count'] * 100).round(2)
    end
  end

  def ecosystem_chart_data
    @ecosystem = params[:ecosystem]
    
    # Chart data for past 30 days PR activity for this ecosystem
    start_date = 30.days.ago
    scope = Issue.joins(issue_packages: :package)
                 .where(packages: { ecosystem: @ecosystem })
                 .where(created_at: start_date..)
    
    # Get counts for each status using groupdate
    open_data = scope.where(state: 'open').group_by_day(:created_at, last: 30).count
    merged_data = scope.where.not(merged_at: nil).group_by_day(:created_at, last: 30).count  
    closed_data = scope.where(state: 'closed', merged_at: nil).group_by_day(:created_at, last: 30).count
    
    # Format for chartkick stacked chart
    result = [
      { name: 'Open', data: open_data },
      { name: 'Merged', data: merged_data },
      { name: 'Closed', data: closed_data }
    ]
    
    expires_in 1.hour, public: true
    render json: result
  end

  def show
    issue_packages = @package.issue_packages
                            .includes(issue: [:repository, :host])
                            .order('issues.created_at DESC')
    
    # Filter by status if provided
    if params[:status].present?
      case params[:status]
      when 'open'
        issue_packages = issue_packages.joins(:issue).where(issues: { state: 'open' })
      when 'merged'
        issue_packages = issue_packages.joins(:issue).where.not(issues: { merged_at: nil })
      when 'closed'
        issue_packages = issue_packages.joins(:issue).where(issues: { state: 'closed', merged_at: nil })
      end
    end
    
    # Filter by update type if provided
    if params[:type].present?
      issue_packages = issue_packages.where(update_type: params[:type])
    end
    
    @pagy, @issue_packages = pagy_countless(issue_packages)
  end

  def feed
    issue_packages = @package.issue_packages
                            .includes(issue: [:repository, :host])
                            .order('issues.created_at DESC')
    
    # Filter by status if provided
    if params[:status].present?
      case params[:status]
      when 'open'
        issue_packages = issue_packages.joins(:issue).where(issues: { state: 'open' })
      when 'merged'
        issue_packages = issue_packages.joins(:issue).where.not(issues: { merged_at: nil })
      when 'closed'
        issue_packages = issue_packages.joins(:issue).where(issues: { state: 'closed', merged_at: nil })
      end
    end
    
    # Filter by update type if provided
    if params[:type].present?
      issue_packages = issue_packages.where(update_type: params[:type])
    end
    
    @pagy, @issue_packages = pagy_countless(issue_packages, limit: 50)
    
    expires_in 1.hour, public: true
    render 'show', formats: [:atom]
  end

  def ecosystem_issues
    @ecosystem = params[:ecosystem]
    
    # Get all issues for packages in this ecosystem
    scope = Issue.joins(issue_packages: :package)
                 .where(packages: { ecosystem: @ecosystem })
                 .includes(:repository, :host, issue_packages: :package)
                 .order('issues.created_at DESC')
    
    @pagy, @issues = pagy_countless(scope)
    
    expires_in 1.hour, public: true
  end

  def ecosystem_feed
    @ecosystem = params[:ecosystem]
    
    # Get recent issues for packages in this ecosystem with pagination
    scope = Issue.joins(issue_packages: :package)
                 .where(packages: { ecosystem: @ecosystem })
                 .includes(:repository, :host, issue_packages: :package)
                 .order('issues.created_at DESC')
    
    @pagy, @issues = pagy_countless(scope, limit: 50)
    
    expires_in 1.hour, public: true
    render formats: [:atom]
  end

  def search
    @query = params[:q]
    @ecosystem = params[:ecosystem]
    
    if @query.present?
      # Get ecosystems that have results for this search query
      @ecosystems = Package.where("name ILIKE ?", "%#{@query}%")
                          .where('issues_count > 0')
                          .distinct
                          .pluck(:ecosystem)
                          .sort
      
      packages = Package.where("name ILIKE ?", "%#{@query}%")
                       .where('issues_count > 0')
                       .order('issues_count DESC, name ASC')
      
      # Filter by ecosystem if provided
      if @ecosystem.present?
        packages = packages.where(ecosystem: @ecosystem)
      end
      
      @pagy, @packages = pagy_countless(packages)
      
      # Fetch registry metadata for each ecosystem in search results
      @ecosystem_registries = {}
      @packages.map(&:ecosystem).uniq.each do |ecosystem|
        sample_package = Package.where(ecosystem: ecosystem)
                               .where.not(metadata: nil)
                               .where("LENGTH(metadata::text) > 2")
                               .first
        if sample_package&.metadata&.dig('registry')
          @ecosystem_registries[ecosystem] = sample_package.metadata['registry']
        end
      end
    else
      # When no search query, show all ecosystems
      @ecosystems = Package.where('issues_count > 0').distinct.pluck(:ecosystem).sort
      @pagy, @packages = pagy_countless(Package.none)
    end
  end

  private

  def set_package
    if params[:ecosystem] && params[:name]
      # URL decode the name parameter to handle special characters
      decoded_name = CGI.unescape(params[:name])
      @package = Package.find_by!(ecosystem: params[:ecosystem], name: decoded_name)
    else
      @package = Package.find(params[:id])
    end
  end
end