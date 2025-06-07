class Api::V1::IssuePackagesController < Api::V1::ApplicationController
  def index
    @issue = Issue.find(params[:issue_id])
    @issue_packages = @issue.issue_packages.includes(:package)
    
    fresh_when(@issue_packages, public: true)
  end
end