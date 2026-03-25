class Api::V1::RepositoriesController < Api::V1::ApplicationController
  skip_before_action :set_cache_headers, only: [:lookup, :ping]
  skip_before_action :set_api_cache_headers, only: [:lookup, :ping]
  before_action :find_host, only: [:index, :show, :ping]

  def index
    scope = @host.repositories.visible.order('last_synced_at DESC').includes(:host)
    scope = scope.created_after(params[:created_after]) if params[:created_after].present?
    scope = scope.updated_after(params[:updated_after]) if params[:updated_after].present?

    if params[:sort].present? || params[:order].present?
      sort = params[:sort] || 'last_synced_at'
      order = params[:order] || 'desc'
      sort_options = sort.split(',').zip(order.split(',')).to_h
      scope = scope.order(sort_options)
    else
      scope = scope.order('last_synced_at DESC')
    end

    @pagy, @repositories = pagy_countless(scope)
    fresh_when @repositories, public: true
  end

  def lookup
    url = params[:url]
    parsed_url = Addressable::URI.parse(url)
    @host = Host.find_by_domain(parsed_url.host)
    raise ActiveRecord::RecordNotFound unless @host
    path = parsed_url.path.delete_prefix('/').chomp('/')
    @repository = @host.repositories.find_by('lower(full_name) = ?', path.downcase)
    if @repository
      raise ActiveRecord::RecordNotFound if @repository.owner_hidden?
      @repository.sync_async(request.remote_ip) unless @repository.last_synced_at.present? && @repository.last_synced_at > 1.day.ago
      redirect_to api_v1_host_repository_path(@host, @repository)
    else
      raise ActiveRecord::RecordNotFound, "Repository not found for URL: #{url}"
    end
  end

  def show
    @repository = @host.repositories.find_by!('lower(full_name) = ?', params[:id].downcase)
    raise ActiveRecord::RecordNotFound if @repository.owner_hidden?
    fresh_when @repository, public: true
    @maintainers = @repository.issues.maintainers.group(:user).count.sort_by{|k,v| -v }
    @active_maintainers = @repository.issues.maintainers.where('issues.created_at > ?', 1.year.ago).group(:user).count.sort_by{|k,v| -v }
  end

  def ping
    @repository = @host.repositories.find_by!('lower(full_name) = ?', params[:id].downcase)
    raise ActiveRecord::RecordNotFound if @repository.owner_hidden?
    if @repository
      @repository.sync_async
    end
    render json: { message: 'pong' }
  end
end