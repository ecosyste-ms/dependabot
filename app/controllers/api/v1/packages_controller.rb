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
  
  def ecosystems
    @ecosystems = Package.distinct.pluck(:ecosystem).compact.sort
    
    render json: @ecosystems
  end
end