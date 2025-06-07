class HomeController < ApplicationController
  def index
    scope = Issue.includes(:repository, :host)
                 .order(created_at: :desc)
    @pagy, @issues = pagy_countless(scope, limit: 50)
    
    # High level stats
    @stats = {
      total_prs: Issue.count,
      merged_prs: Issue.where.not(merged_at: nil).count,
      total_repositories: Repository.where('issues_count > 0').count,
      total_packages: Package.where('issues_count > 0').count,
      past_week_prs: Issue.where('created_at > ?', 1.week.ago).count
    }
    
    expires_in 1.hour, public: true
  end
  
  def chart_data
    # Chart data for past 30 days PR activity using groupdate
    start_date = 30.days.ago
    scope = Issue.where(created_at: start_date..)
    
    # Get counts for each status using groupdate
    open_data = scope.where(state: 'open').group_by_day(:created_at, last: 30).count
    merged_data = scope.where.not(merged_at: nil).group_by_day(:created_at, last: 30).count  
    closed_data = scope.where(state: 'closed', merged_at: nil).group_by_day(:created_at, last: 30).count
    
    # Format for chartkick stacked chart
    result = [
      { name: 'Open', data: open_data },
      { name: 'Merged', data: merged_data },
      { name: 'Closed', data: closed_data }
    ]
    
    expires_in 1.hour, public: true
    render json: result
  end
end