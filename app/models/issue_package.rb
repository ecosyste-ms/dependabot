class IssuePackage < ApplicationRecord
  belongs_to :issue
  belongs_to :package, counter_cache: :issues_count
  
  validates :issue_id, uniqueness: { scope: :package_id }
  
  after_create :update_package_unique_repositories_counts
  after_destroy :update_package_unique_repositories_counts
  
  # Update types including removals
  UPDATE_TYPES = %w[major minor patch removal].freeze
  
  validates :update_type, inclusion: { in: UPDATE_TYPES }, allow_nil: true
  
  scope :major_updates, -> { where(update_type: 'major') }
  scope :minor_updates, -> { where(update_type: 'minor') }
  scope :patch_updates, -> { where(update_type: 'patch') }
  scope :removals, -> { where(update_type: 'removal') }
  
  # Time-based scopes for quick graphing
  scope :created_after, ->(date) { where('pr_created_at > ?', date) }
  scope :created_before, ->(date) { where('pr_created_at < ?', date) }
  scope :created_between, ->(start_date, end_date) { where(pr_created_at: start_date..end_date) }
  scope :past_year, -> { where('pr_created_at > ?', 1.year.ago) }
  scope :past_month, -> { where('pr_created_at > ?', 1.month.ago) }
  scope :past_week, -> { where('pr_created_at > ?', 1.week.ago) }
  
  def version_change
    if update_type == 'removal'
      old_version ? "#{old_version} → removed" : "removed"
    elsif old_version && new_version
      "#{old_version} → #{new_version}"
    else
      nil
    end
  end
  
  private
  
  def update_package_unique_repositories_counts
    package.update_unique_repositories_counts!
  end
end
