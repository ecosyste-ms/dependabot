require "test_helper"
require "rake"

class TakedownRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("takedown:hide_user")
    ENV.delete("HOST")
    ENV.delete("LOGIN")
  end

  teardown do
    ENV.delete("HOST")
    ENV.delete("LOGIN")
  end

  test "hide_user hides an owner and removes their repositories and issues" do
    host = Host.create!(name: "GitHub", url: "https://github.com", kind: "github")
    owner = Owner.create!(host: host, login: "Target-Org")
    repository = Repository.create!(
      host: host,
      full_name: "target-org/project",
      owner: "target-org"
    )
    other_repository = Repository.create!(
      host: host,
      full_name: "other-org/project",
      owner: "other-org"
    )
    issue = Issue.create!(
      repository: repository,
      host: host,
      number: 1,
      title: "Bump example",
      state: "open",
      pull_request: true,
      uuid: "target-issue",
      user: "dependabot[bot]"
    )
    package = Package.create!(ecosystem: "rubygems", name: "example")
    advisory = Advisory.create!(uuid: "target-advisory")
    IssuePackage.create!(issue: issue, package: package)
    IssueAdvisory.create!(issue: issue, advisory: advisory)
    ENV["LOGIN"] = "TARGET-ORG"

    output, = capture_io { Rake::Task["takedown:hide_user"].execute }

    assert owner.reload.hidden?
    assert_not Repository.exists?(repository.id)
    assert Repository.exists?(other_repository.id)
    assert_not Issue.exists?(issue.id)
    assert_not IssuePackage.exists?(issue_id: issue.id)
    assert_not IssueAdvisory.exists?(issue_id: issue.id)
    assert_equal 0, package.reload.issues_count
    assert_equal 0, advisory.reload.issues_count
    assert_includes output, "[dependabot] hidden owner GitHub/Target-Org"
    assert_includes output, "[dependabot] destroyed 1 repositories and 1 issues"
  end

  test "hide_user creates a hidden tombstone for an unknown owner" do
    Host.create!(name: "GitHub", url: "https://github.com", kind: "github")
    ENV["LOGIN"] = "Missing-Owner"

    capture_io { Rake::Task["takedown:hide_user"].execute }

    owner = Owner.find_by(login: "missing-owner")
    assert owner.hidden?
  end

  test "hide_user aborts without LOGIN" do
    assert_raises(SystemExit) do
      capture_io { Rake::Task["takedown:hide_user"].execute }
    end
  end

  test "report describes a hidden owner and their data" do
    host = Host.create!(name: "GitHub", url: "https://github.com", kind: "github")
    Owner.create!(host: host, login: "Hidden-Owner", hidden: true)
    repository = Repository.create!(
      host: host,
      full_name: "hidden-owner/project",
      owner: "hidden-owner"
    )
    Issue.create!(
      repository: repository,
      host: host,
      number: 1,
      title: "Bump example",
      state: "open",
      pull_request: true,
      uuid: "report-issue",
      user: "dependabot[bot]"
    )
    ENV["LOGIN"] = "HIDDEN-OWNER"

    output, = capture_io { Rake::Task["takedown:report"].execute }

    assert_includes output, "[dependabot] GitHub/HIDDEN-OWNER: owner=hidden repositories=1 issues=1"
  end
end
