class RepositoriesController < ApplicationController
  skip_before_action :set_cache_headers, only: [:lookup]

  def lookup
    url = params[:url]
    raise ActiveRecord::RecordNotFound unless url.present?
    parsed_url = Addressable::URI.parse(url)
    @host = Host.find_by_domain(parsed_url.host)
    raise ActiveRecord::RecordNotFound unless @host
    path = parsed_url.path.delete_prefix('/').chomp('/')
    @repository = @host.repositories.find_by('lower(full_name) = ?', path.downcase)
    if @repository
      @repository.sync_async(request.remote_ip) unless @repository.last_synced_at.present? && @repository.last_synced_at > 1.day.ago
      redirect_to host_repository_path(@host, @repository)
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  def index
    @host = Host.find_by_name!(params[:host_id])
    redirect_to host_path(@host)
  end

  def show
    @host = Host.find_by_name!(params[:host_id])
    @repository = @host.repositories.find_by('lower(full_name) = ?', params[:id].downcase)
    raise ActiveRecord::RecordNotFound unless @repository
    fresh_when(@repository, public: true)
    
    # Get issues for the main content area with optional label filtering
    scope = @repository.issues.includes(:host, :advisories, issue_packages: :package)
    
    if params[:label].present?
      scope = scope.with_label(params[:label])
    end
    
    @pagy, @issues = pagy_countless(scope.order('issues.created_at DESC'))
  end

  def feed
    @host = Host.find_by_name!(params[:host_id])
    @repository = @host.repositories.find_by('lower(full_name) = ?', params[:id].downcase)
    raise ActiveRecord::RecordNotFound unless @repository
    
    # Get issues for the feed with optional label filtering
    scope = @repository.issues.includes(:host, issue_packages: :package)
    
    if params[:label].present?
      scope = scope.with_label(params[:label])
    end
    
    @pagy, @issues = pagy_countless(scope.order('issues.created_at DESC'), limit: 50)
    
    render 'show', formats: [:atom]
  end

  private
end