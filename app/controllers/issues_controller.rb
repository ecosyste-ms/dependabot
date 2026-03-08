class IssuesController < ApplicationController
  before_action :find_host

  def index
    @repository = @host.repositories.find_by!('lower(full_name) = ?', params[:repository_id].downcase)
    
    scope = @repository.issues
    
    # Apply security filter if requested
    scope = scope.security_prs if params[:security] == 'true'
    
    @pagy, @issues = pagy_countless(scope.includes(:host).order('number DESC'))
  end

  def show
    @repository = @host.repositories.find_by!('lower(full_name) = ?', params[:repository_id].downcase)
    @issue = @repository.issues.find_by!(number: params[:id])
  end
end