class HomeController < ApplicationController
  def index
    scope = Issue.includes(:repository, :host)
                 .order(created_at: :desc)
    @pagy, @issues = pagy_countless(scope, limit: 50)
  end
end