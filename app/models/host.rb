class Host < ApplicationRecord
  has_many :repositories
  has_many :issues

  validates :name, presence: true, uniqueness: true
  validates :url, presence: true
  validates :kind, presence: true

  scope :visible, -> { where('repositories_count > 0') }
  scope :with_issues, -> { where('issues_count > 0') }
  scope :with_pull_requests, -> { where('pull_requests_count > 0') }

  def self.find_by_name(name)
    Host.all.find { |host| host.name == name }
  end

  def self.find_by_domain(domain)
    Host.all.find { |host| host.domain == domain }
  end

  def host_class
    "Hosts::#{kind.capitalize}".constantize
  end

  def host_instance
    host_class.new(self)
  end

  def to_s
    name
  end

  def to_param
    name
  end

  def domain
    Addressable::URI.parse(url).host
  end

  def display_kind?
    return false if name.split('.').length == 2 && name.split('.').first.downcase == kind
    name.downcase != kind
  end

  def self.update_counts
    Host.all.each(&:update_counts)
  end

  def update_counts
    self.repositories_count = repositories.count
    self.issues_count = repositories.sum(:issues_count)
    self.pull_requests_count = repositories.sum(:pull_requests_count)
    self.authors_count = issues.distinct.count(:user)
    save
  end

  def self.sync_all
    conn = Faraday.new('https://repos.ecosyste.ms') do |f|
      f.request :json
      f.request :retry
      f.response :json
      f.headers['X-API-Key'] = ENV['ECOSYSTEMS_API_KEY'] if ENV['ECOSYSTEMS_API_KEY']
    end
    
    response = conn.get('/api/v1/hosts')
    return nil unless response.success?
    json = response.body

    json.each do |host|
      Host.find_or_create_by(name: host['name']).tap do |r|
        r.url = host['url']
        r.kind = host['kind']
        r.icon_url = host['icon_url']
        r.last_synced_at = Time.now
        r.save
      end
    end
  end
end
