class HostsController < ApplicationController
  def index
    github_host = Host.find_by(name: 'GitHub')
    if github_host
      redirect_to host_path(github_host)
    else
      # Fallback to first host if GitHub not found
      first_host = Host.first
      if first_host
        redirect_to host_path(first_host)
      else
        redirect_to root_path
      end
    end
  end

  def show
    @host = Host.find_by_name!(params[:id])

    scope = @host.repositories

    sort = params[:sort].presence || 'last_synced_at'
    if params[:order] == 'asc'
      scope = scope.order(Arel.sql(sort).asc.nulls_last)
    else
      scope = scope.order(Arel.sql(sort).desc.nulls_last)
    end

    @pagy, @repositories = pagy_countless(scope)
    fresh_when(@repositories, public: true)
  end
end