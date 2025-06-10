class IssueAdvisory < ApplicationRecord
  belongs_to :issue
  belongs_to :advisory, counter_cache: :issues_count

  validates :issue_id, uniqueness: { scope: :advisory_id }

  scope :recent, -> { order(created_at: :desc) }
end