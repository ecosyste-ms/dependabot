class OwnersController < ApplicationController
  def index
    @host = Host.find_by!(name: params[:host_id])
    @scope = @host.repositories.where.not(owner: nil).group(:owner).count.sort_by{|k,v| -v }
    @pagy, @owners = pagy_array(@scope)
    expires_in 1.day, public: true
  end

  def show
    @host = Host.find_by!(name: params[:host_id])
    @owner = params[:id]

    @pull_requests_count = @host.issues.owner(@owner).where(pull_request: true).count
    @merged_pull_requests_count = @host.issues.owner(@owner).where(pull_request: true).where.not(merged_at: nil).count
    @average_pull_request_close_time = @host.issues.owner(@owner).where(pull_request: true).average(:time_to_close)
    @average_pull_request_comments_count = @host.issues.owner(@owner).where(pull_request: true).average(:comments_count)
    @pull_request_labels_count = @host.issues.owner(@owner).where(pull_request: true).pluck(:labels).flatten.compact.group_by(&:itself).map{|k,v| [k, v.count]}.to_h.sort_by{|k,v| -v}

    # Get repositories with Dependabot PRs for this owner
    scope = @host.repositories.where(owner: @owner).where('issues_count > 0')
    
    sort = params[:sort].presence || 'issues_count'
    if params[:order] == 'asc'
      scope = scope.order(Arel.sql(sort).asc.nulls_last)
    else
      scope = scope.order(Arel.sql(sort).desc.nulls_last)
    end

    @pagy, @repositories = pagy_countless(scope)

    expires_in 1.day, public: true
  end

  def issues
    @host = Host.find_by!(name: params[:host_id])
    @owner = params[:id]
    
    # Get all issues for repositories owned by this owner
    scope = @host.issues.joins(:repository)
                       .where(repositories: { owner: @owner })
                       .includes(:repository, :host, issue_packages: :package)
                       .order('issues.created_at DESC')
    
    @pagy, @issues = pagy_countless(scope)
    
    expires_in 1.hour, public: true
  end

  def feed
    @host = Host.find_by!(name: params[:host_id])
    @owner = params[:id]
    
    # Get recent issues for repositories owned by this owner
    @issues = @host.issues.joins(:repository)
                          .where(repositories: { owner: @owner })
                          .includes(:repository, :host, issue_packages: :package)
                          .order('issues.created_at DESC')
                          .limit(50)
    
    expires_in 1.hour, public: true
    render formats: [:atom]
  end
end