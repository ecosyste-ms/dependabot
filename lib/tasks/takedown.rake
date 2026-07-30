namespace :takedown do
  desc "Hide a user and remove their repositories. LOGIN=username [HOST=GitHub]"
  task hide_user: :environment do
    login = ENV['LOGIN']
    host_name = ENV['HOST'] || 'GitHub'
    abort "LOGIN is required" if login.blank?

    host = Host.find_by_name(host_name)
    abort "Host #{host_name} not found" if host.nil?

    owner = nil
    repository_count = 0
    issue_count = 0

    ActiveRecord::Base.transaction do
      owner = host.owners.find_by('lower(login) = ?', login.downcase)
      owner ||= host.owners.create!(login: login.downcase)
      owner.update!(hidden: true)

      repositories = host.repositories.where('lower(owner) = ?', login.downcase)
      repository_count = repositories.count
      issue_count = Issue.where(repository_id: repositories.select(:id)).count
      repositories.find_each(&:destroy!)
    end

    puts "[dependabot] hidden owner #{host.name}/#{owner.login}"
    puts "[dependabot] destroyed #{repository_count} repositories and #{issue_count} issues for #{host.name}/#{login}"
  end

  desc "Report what exists for a user. LOGIN=username [HOST=GitHub]"
  task report: :environment do
    login = ENV['LOGIN']
    host_name = ENV['HOST'] || 'GitHub'
    abort "LOGIN is required" if login.blank?

    host = Host.find_by_name(host_name)
    abort "Host #{host_name} not found" if host.nil?

    owner = host.owners.find_by('lower(login) = ?', login.downcase)
    repositories = host.repositories.where('lower(owner) = ?', login.downcase)
    repository_count = repositories.count
    issue_count = Issue.where(repository_id: repositories.select(:id)).count
    state = owner ? (owner.hidden? ? 'hidden' : 'visible') : 'none'

    puts "[dependabot] #{host.name}/#{login}: owner=#{state} repositories=#{repository_count} issues=#{issue_count}"
  end
end
