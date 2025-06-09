class ImportsController < ApplicationController
  def index
    @pagy, @imports = pagy(Import.order("created_at DESC"))
    @recent_stats = {
      total_recent: Import.where('created_at > ?', 24.hours.ago).count,
      successful_recent: Import.where('created_at > ?', 24.hours.ago).where(success: true).count,
      failed_recent: Import.where('created_at > ?', 24.hours.ago).where(success: false).count,
      recent_dependabot_count: Import.where('created_at > ?', 24.hours.ago).where(success: true).sum(:dependabot_count),
      recent_issues_created: Import.where('created_at > ?', 24.hours.ago).where(success: true).sum(:created_count)
    }
    fresh_when(@imports, public: true)
  end
end