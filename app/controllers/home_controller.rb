class HomeController < ApplicationController
  def index
    # Show recent Dependabot pull requests
    @pagy, @issues = pagy_countless(recent_dependabot_prs, limit: 50)
  end

  private

  def recent_dependabot_prs
    Issue.dependabot
         .pull_request
         .joins(:repository, :host)
         .includes(:repository, :host)
         .order(created_at: :desc)
  end
end