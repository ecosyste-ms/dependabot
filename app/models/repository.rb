class Repository < ApplicationRecord
  belongs_to :host

  has_many :issues, dependent: :delete_all

  validates :full_name, presence: true

  after_create :sync_repository_async

  scope :active, -> { where(status: nil) }
  scope :visible, -> { active.where.not(last_synced_at: nil) }
  scope :created_after, ->(date) { where('created_at > ?', date) }
  scope :updated_after, ->(date) { where('updated_at > ?', date) }
  scope :owner, ->(owner) { where(owner: owner) }
  scope :fork, -> { where("metadata->>'fork' = 'true'") }
  scope :archived, -> { where("metadata->>'archived' = 'true'") }
  scope :without_metadata, -> { where("LENGTH(metadata::text) = 2") }

  def self.sync_least_recently_synced
    Repository.active.order('last_synced_at ASC').limit(3000).each(&:sync_repository_async)
  end
  
  def self.enqueue_stale_for_sync(limit: 1000)
    stale_repository_ids = active
                             .where(last_synced_at: ..1.week.ago)
                             .or(active.where(last_synced_at: nil))
                             .order(Arel.sql('RANDOM()'))
                             .limit(limit)
                             .pluck(:id)
    
    # Bulk enqueue jobs - more efficient than individual perform_async calls
    jobs = stale_repository_ids.map { |id| [id] }
    SyncRepositoryWorker.perform_bulk(jobs) if jobs.any?
    
    stale_repository_ids.count
  end

  def to_s
    full_name
  end

  def to_param
    full_name
  end

  def subgroups
    return [] if full_name.split('/').size < 3
    full_name.split('/')[1..-2]
  end

  def project_slug
    full_name.split('/').last
  end

  def project_name
    full_name.split('/')[1..-1].join('/')
  end

  def owner
    read_attribute(:owner) || full_name.split('/').first
  end

  def sync_details
    conn = Faraday.new(repos_api_url) do |f|
      f.request :json
      f.request :retry
      f.response :json
    end
    response = conn.get
    if response.status == 404
      self.status = 'not_found'
      self.save
      return
    end
    return if response.status != 200
    json = response.body

    # Store all metadata from repos.ecosyste.ms
    self.metadata = json
    self.owner = json['owner']
    self.status = json['status']
    self.default_branch = json['default_branch']
    self.last_synced_at = Time.now
    self.save    
  end

  def repos_url
    "https://repos.ecosyste.ms/hosts/#{host.name}/repositories/#{full_name}"
  end

  def repos_api_url
    "https://repos.ecosyste.ms/api/v1/hosts/#{host.name}/repositories/#{full_name}"
  end

  def html_url
    "#{host.url}/#{full_name}"
  end

  def issue_labels_count
    issues.where(pull_request: false).pluck(:labels).flatten.compact.group_by(&:itself).map{|k,v| [k, v.count]}.to_h.sort_by{|k,v| -v}
  end

  def pull_request_labels_count
    issues.where(pull_request: true).pluck(:labels).flatten.compact.group_by(&:itself).map{|k,v| [k, v.count]}.to_h.sort_by{|k,v| -v}
  end

  def past_year_issue_labels_count
    issues.where(pull_request: false).past_year.pluck(:labels).flatten.compact.group_by(&:itself).map{|k,v| [k, v.count]}.to_h.sort_by{|k,v| -v}
  end

  def past_year_pull_request_labels_count
    issues.where(pull_request: true).past_year.pluck(:labels).flatten.compact.group_by(&:itself).map{|k,v| [k, v.count]}.to_h.sort_by{|k,v| -v}
  end

  def issue_author_associations_count
    issues.where(pull_request: false).with_author_association.group(:author_association).count.sort_by{|k,v| -v }
  end

  def pull_request_author_associations_count
    issues.where(pull_request: true).with_author_association.group(:author_association).count.sort_by{|k,v| -v }
  end

  def past_year_issue_author_associations_count
    issues.where(pull_request: false).past_year.with_author_association.group(:author_association).count.sort_by{|k,v| -v }
  end

  def past_year_pull_request_author_associations_count
    issues.where(pull_request: true).past_year.with_author_association.group(:author_association).count.sort_by{|k,v| -v }
  end

  def issue_authors
    issues.where(pull_request: false).group(:user).count.sort_by{|k,v| -v }
  end

  def pull_request_authors
    issues.where(pull_request: true).group(:user).count.sort_by{|k,v| -v }
  end

  def past_year_issue_authors
    issues.where(pull_request: false).past_year.group(:user).count.sort_by{|k,v| -v }
  end

  def past_year_pull_request_authors
    issues.where(pull_request: true).past_year.group(:user).count.sort_by{|k,v| -v }
  end

  def sync_issues
    host.host_instance.load_issues(self) do |data|
      data.each do |issue|
        i = issues.find_or_create_by(uuid: issue[:uuid])
        i.assign_attributes issue
        i.parse_dependabot_metadata
        i.time_to_close = i.closed_at - i.created_at if i.closed_at.present?
        i.host_id = host.id
        i.save(touch: false)
      end
    end

    self.pull_requests_count = issues.where(pull_request: true).count

    self.avg_time_to_close_issue = issues.where(pull_request: false).average(:time_to_close)
    self.avg_time_to_close_pull_request = issues.where(pull_request: true).average(:time_to_close)
    self.issues_closed_count = issues.where(pull_request: false, state: 'closed').count
    self.pull_requests_closed_count = issues.where(pull_request: true, state: 'closed').count
    self.pull_request_authors_count = issues.where(pull_request: true).distinct.count(:user)
    self.issue_authors_count = issues.where(pull_request: false).distinct.count(:user)
    self.avg_comments_per_issue = issues.where(pull_request: false).average(:comments_count)
    self.avg_comments_per_pull_request = issues.where(pull_request: true).average(:comments_count)
    self.bot_issues_count = issues.where(pull_request: false).bot.count
    self.bot_pull_requests_count = issues.where(pull_request: true).bot.count
    self.merged_pull_requests_count = issues.where(pull_request: true).merged.count

    self.past_year_issues_count = issues.where(pull_request: false).past_year.count
    self.past_year_pull_requests_count = issues.where(pull_request: true).past_year.count

    self.past_year_avg_time_to_close_issue = issues.where(pull_request: false).past_year.average(:time_to_close)
    self.past_year_avg_time_to_close_pull_request = issues.where(pull_request: true).past_year.average(:time_to_close)
    self.past_year_issues_closed_count = issues.where(pull_request: false, state: 'closed').past_year.count
    self.past_year_pull_requests_closed_count = issues.where(pull_request: true, state: 'closed').past_year.count
    self.past_year_pull_request_authors_count = issues.where(pull_request: true).past_year.distinct.count(:user)
    self.past_year_issue_authors_count = issues.where(pull_request: false).past_year.distinct.count(:user)
    self.past_year_avg_comments_per_issue = issues.where(pull_request: false).past_year.average(:comments_count)
    self.past_year_avg_comments_per_pull_request = issues.where(pull_request: true).past_year.average(:comments_count)
    self.past_year_bot_issues_count = issues.where(pull_request: false).past_year.bot.count
    self.past_year_bot_pull_requests_count = issues.where(pull_request: true).past_year.bot.count
    self.past_year_merged_pull_requests_count = issues.where(pull_request: true).past_year.merged.count

    self.last_synced_at = Time.now
    self.status = nil
    self.save
  rescue
    self.status = 'error'
    self.last_synced_at = Time.now
    self.save
  end

  def latest_issue_number
    issues.maximum(:number)
  end
  
  def sync_repository_async
    SyncRepositoryWorker.perform_async(id)
  end
  
  def sync
    sync_details
  end
  
  def avatar_url
    "https://github.com/#{owner}.png"
  end
end
