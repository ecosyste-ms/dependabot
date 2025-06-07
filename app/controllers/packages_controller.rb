class PackagesController < ApplicationController
  before_action :set_package, only: [:show]

  def index
    @ecosystem_counts = Package.group(:ecosystem).count
    @ecosystems = @ecosystem_counts.sort_by { |ecosystem, count| -count }.map(&:first)
  end

  def ecosystem
    @ecosystem = params[:ecosystem]
    
    # Get packages for pagination
    packages = Package.where(ecosystem: @ecosystem)
                     .where('issues_count > 0')
                     .order('issues_count DESC, name ASC')
    
    @pagy, @packages = pagy(packages)
    
    # Calculate ecosystem-level statistics
    all_packages = Package.where(ecosystem: @ecosystem)
    issue_packages = IssuePackage.joins(:package).where(packages: { ecosystem: @ecosystem })
    
    @stats = {
      total_packages: all_packages.count,
      total_updates: issue_packages.count,
      unique_repositories: Issue.joins(issue_packages: :package)
                                .where(packages: { ecosystem: @ecosystem })
                                .distinct.count(:repository_id),
      update_types: issue_packages.group(:update_type).count,
      recent_activity: issue_packages.where('pr_created_at > ?', 30.days.ago).count,
      avg_updates_per_package: all_packages.where('issues_count > 0').average(:issues_count)&.round(1),
      most_updated_package: all_packages.order(:issues_count).last,
      latest_update: Issue.joins(issue_packages: :package)
                          .where(packages: { ecosystem: @ecosystem })
                          .order(:created_at).last
    }
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
    
    @pagy, @issue_packages = pagy(issue_packages)
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
      
      @pagy, @packages = pagy(packages)
    else
      # When no search query, show all ecosystems
      @ecosystems = Package.where('issues_count > 0').distinct.pluck(:ecosystem).sort
      @pagy, @packages = pagy(Package.none)
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