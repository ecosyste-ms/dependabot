class IssuesController < ApplicationController
  def index
    @host = Host.find_by_name!(params[:host_id])
    @repository = @host.repositories.find_by!('lower(full_name) = ?', params[:repository_id].downcase)
    
    scope = @repository.issues
    
    # Apply security filter if requested
    scope = scope.security_prs if params[:security] == 'true'
    
    @pagy, @issues = pagy_countless(scope.includes(:host).order('number DESC'))
    expires_in 1.hour, public: true
  end

  def show
    @host = Host.find_by_name!(params[:host_id])
    @repository = @host.repositories.find_by!('lower(full_name) = ?', params[:repository_id].downcase)
    @issue = @repository.issues.find_by!(number: params[:id])
    expires_in 1.hour, public: true
  end
end