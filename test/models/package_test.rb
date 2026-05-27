require "test_helper"

class PackageTest < ActiveSupport::TestCase
  test "should validate ecosystem is supported by Dependabot" do
    # Valid ecosystem should pass
    package = Package.new(name: "test-package", ecosystem: "npm")
    assert package.valid?
    
    # Invalid ecosystem should fail
    package = Package.new(name: "test-package", ecosystem: "invalid-ecosystem")
    assert_not package.valid?
    assert_includes package.errors[:ecosystem], "must be a supported Dependabot ecosystem"
    
    # Unsupported but real ecosystem should fail
    package = Package.new(name: "test-package", ecosystem: "homebrew")
    assert_not package.valid?
    assert_includes package.errors[:ecosystem], "must be a supported Dependabot ecosystem"
  end
  
  test "should validate name presence" do
    package = Package.new(ecosystem: "npm")
    assert_not package.valid?
    assert_includes package.errors[:name], "can't be blank"
  end
  
  test "should validate ecosystem presence" do
    package = Package.new(name: "test-package")
    assert_not package.valid?
    assert_includes package.errors[:ecosystem], "can't be blank"
  end
  
  test "should validate name uniqueness within ecosystem" do
    Package.create!(name: "test-package", ecosystem: "npm")

    # Same name in same ecosystem should fail
    duplicate = Package.new(name: "test-package", ecosystem: "npm")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"

    # Same name in different ecosystem should pass
    different_ecosystem = Package.new(name: "test-package", ecosystem: "pip")
    assert different_ecosystem.valid?
  end

  test "ECOSYSTEM_TO_PURL_TYPE maps ecosystems with official PURL types" do
    # Only bazel and julia have official PURL types per purl-spec
    assert_equal 'bazel', Package::ECOSYSTEM_TO_PURL_TYPE['bazel']
    assert_equal 'julia', Package::ECOSYSTEM_TO_PURL_TYPE['julia']
  end

  test "purl_type returns official type for ecosystems with PURL spec support" do
    bazel_pkg = Package.new(name: "rules_go", ecosystem: "bazel")
    assert_equal 'bazel', bazel_pkg.purl_type

    julia_pkg = Package.new(name: "DataFrames", ecosystem: "julia")
    assert_equal 'julia', julia_pkg.purl_type
  end

  test "purl_type falls back to ecosystem name when no official PURL type exists" do
    # These ecosystems have no official PURL type, so they fall back to ecosystem name
    vcpkg_pkg = Package.new(name: "boost", ecosystem: "vcpkg")
    assert_equal 'vcpkg', vcpkg_pkg.purl_type

    devcontainers_pkg = Package.new(name: "node", ecosystem: "devcontainers")
    assert_equal 'devcontainers', devcontainers_pkg.purl_type

    rust_toolchain_pkg = Package.new(name: "stable", ecosystem: "rust-toolchain")
    assert_equal 'rust-toolchain', rust_toolchain_pkg.purl_type
  end

  test "should accept new Dependabot ecosystems" do
    %w[bazel devcontainers julia vcpkg rust-toolchain nix].each do |ecosystem|
      package = Package.new(name: "test-#{ecosystem}-package", ecosystem: ecosystem)
      assert package.valid?, "Expected #{ecosystem} to be valid but got: #{package.errors.full_messages}"
    end
  end

  test "latest_issue_at returns cached column when present" do
    package = Package.create!(name: "cached-pkg", ecosystem: "npm")
    timestamp = 3.days.ago
    package.update_column(:latest_issue_at, timestamp)

    assert_in_delta timestamp.to_f, package.latest_issue_at.to_f, 1
  end

  test "latest_issue_at falls back to issue_packages max when not cached" do
    host = Host.create!(name: 'github.com', url: 'https://github.com', kind: 'github')
    repo = Repository.create!(host: host, full_name: 'test/repo', owner: 'test')
    package = Package.create!(name: "fallback-pkg", ecosystem: "npm")

    older = Issue.create!(repository: repo, host: host, user: 'dependabot[bot]', number: 1, title: 'old', state: 'open', pull_request: true, uuid: 'ip-old', created_at: 5.days.ago)
    newer = Issue.create!(repository: repo, host: host, user: 'dependabot[bot]', number: 2, title: 'new', state: 'open', pull_request: true, uuid: 'ip-new', created_at: 1.day.ago)
    IssuePackage.create!(issue: older, package: package, pr_created_at: older.created_at)
    IssuePackage.create!(issue: newer, package: package, pr_created_at: newer.created_at)

    package.update_column(:latest_issue_at, nil)
    package.reload

    assert_in_delta newer.created_at.to_f, package.latest_issue_at.to_f, 1
  end

  test "update_unique_repositories_counts! caches latest_issue_at" do
    host = Host.create!(name: 'github.com', url: 'https://github.com', kind: 'github')
    repo = Repository.create!(host: host, full_name: 'test/repo2', owner: 'test')
    package = Package.create!(name: "counts-pkg", ecosystem: "npm")
    issue = Issue.create!(repository: repo, host: host, user: 'dependabot[bot]', number: 1, title: 'x', state: 'open', pull_request: true, uuid: 'ip-counts', created_at: 2.days.ago)
    IssuePackage.create!(issue: issue, package: package, pr_created_at: issue.created_at)

    package.update_column(:latest_issue_at, nil)
    package.update_unique_repositories_counts!
    package.reload

    assert_in_delta issue.created_at.to_f, package.read_attribute(:latest_issue_at).to_f, 1
  end

  test "issue_status_counts groups by open/merged/closed in one query" do
    host = Host.create!(name: 'github.com', url: 'https://github.com', kind: 'github')
    repo = Repository.create!(host: host, full_name: 'test/status', owner: 'test')
    package = Package.create!(name: "status-pkg", ecosystem: "npm")

    open_issue = Issue.create!(repository: repo, host: host, user: 'dependabot[bot]', number: 1, title: 'o', state: 'open', pull_request: true, uuid: 'st-open')
    merged_issue = Issue.create!(repository: repo, host: host, user: 'dependabot[bot]', number: 2, title: 'm', state: 'closed', merged_at: 1.day.ago, pull_request: true, uuid: 'st-merged')
    closed_issue = Issue.create!(repository: repo, host: host, user: 'dependabot[bot]', number: 3, title: 'c', state: 'closed', pull_request: true, uuid: 'st-closed')
    IssuePackage.create!(issue: open_issue, package: package, pr_created_at: open_issue.created_at)
    IssuePackage.create!(issue: merged_issue, package: package, pr_created_at: merged_issue.created_at)
    IssuePackage.create!(issue: closed_issue, package: package, pr_created_at: closed_issue.created_at)

    package.reload
    counts = package.issue_status_counts

    assert_equal 1, counts['open']
    assert_equal 1, counts['merged']
    assert_equal 1, counts['closed']
  end

  test "status count readers prefer cached column" do
    package = Package.create!(name: "cached-status-pkg", ecosystem: "npm")
    package.update_columns(open_issues_count: 5, merged_issues_count: 3, closed_issues_count: 2)

    assert_equal 5, package.open_issues_count
    assert_equal 3, package.merged_issues_count
    assert_equal 2, package.closed_issues_count
  end

  test "update_type_counts prefers cached column" do
    package = Package.create!(name: "cached-types-pkg", ecosystem: "npm")
    package.update_column(:update_type_counts, { 'major' => 4, 'patch' => 9 })

    assert_equal({ 'major' => 4, 'patch' => 9 }, package.update_type_counts)
  end

  test "adjust_status_count moves one between columns atomically" do
    package = Package.create!(name: "adjust-pkg", ecosystem: "npm")
    package.update_columns(open_issues_count: 5, merged_issues_count: 2, closed_issues_count: 1)

    package.adjust_status_count('open', 'merged')
    package.reload

    assert_equal 4, package.read_attribute(:open_issues_count)
    assert_equal 3, package.read_attribute(:merged_issues_count)
    assert_equal 1, package.read_attribute(:closed_issues_count)
  end

  test "adjust_status_count is a no-op when counts not yet backfilled" do
    package = Package.create!(name: "nobackfill-pkg", ecosystem: "npm")
    assert_nil package.read_attribute(:open_issues_count)

    package.adjust_status_count('open', 'merged')
    package.reload

    assert_nil package.read_attribute(:open_issues_count)
    assert_nil package.read_attribute(:merged_issues_count)
  end

  test "issue state change adjusts package status counts" do
    host = Host.create!(name: 'github.com', url: 'https://github.com', kind: 'github')
    repo = Repository.create!(host: host, full_name: 'test/adjust', owner: 'test')
    package = Package.create!(name: "issue-adjust-pkg", ecosystem: "npm")
    issue = Issue.create!(repository: repo, host: host, user: 'dependabot[bot]', number: 1, title: 'x', state: 'open', pull_request: true, uuid: 'adj-1')
    IssuePackage.create!(issue: issue, package: package, pr_created_at: issue.created_at)

    package.reload
    assert_equal 1, package.read_attribute(:open_issues_count)
    assert_equal 0, package.read_attribute(:merged_issues_count)

    issue.update!(state: 'closed', merged_at: Time.current)
    package.reload

    assert_equal 0, package.read_attribute(:open_issues_count)
    assert_equal 1, package.read_attribute(:merged_issues_count)
    assert_equal 0, package.read_attribute(:closed_issues_count)
  end

  test "issue state change to closed without merge adjusts closed count" do
    host = Host.create!(name: 'github.com', url: 'https://github.com', kind: 'github')
    repo = Repository.create!(host: host, full_name: 'test/adjust2', owner: 'test')
    package = Package.create!(name: "issue-close-pkg", ecosystem: "npm")
    issue = Issue.create!(repository: repo, host: host, user: 'dependabot[bot]', number: 1, title: 'x', state: 'open', pull_request: true, uuid: 'adj-2')
    IssuePackage.create!(issue: issue, package: package, pr_created_at: issue.created_at)

    issue.update!(state: 'closed')
    package.reload

    assert_equal 0, package.read_attribute(:open_issues_count)
    assert_equal 0, package.read_attribute(:merged_issues_count)
    assert_equal 1, package.read_attribute(:closed_issues_count)
  end

  test "update_unique_repositories_counts! caches status and update type counts" do
    host = Host.create!(name: 'github.com', url: 'https://github.com', kind: 'github')
    repo = Repository.create!(host: host, full_name: 'test/cache', owner: 'test')
    package = Package.create!(name: "cache-all-pkg", ecosystem: "npm")

    open_issue = Issue.create!(repository: repo, host: host, user: 'dependabot[bot]', number: 1, title: 'o', state: 'open', pull_request: true, uuid: 'ca-open')
    merged_issue = Issue.create!(repository: repo, host: host, user: 'dependabot[bot]', number: 2, title: 'm', state: 'closed', merged_at: 1.day.ago, pull_request: true, uuid: 'ca-merged')
    IssuePackage.create!(issue: open_issue, package: package, pr_created_at: open_issue.created_at, update_type: 'major')
    IssuePackage.create!(issue: merged_issue, package: package, pr_created_at: merged_issue.created_at, update_type: 'patch')

    package.update_unique_repositories_counts!
    package.reload

    assert_equal 1, package.read_attribute(:open_issues_count)
    assert_equal 1, package.read_attribute(:merged_issues_count)
    assert_equal 0, package.read_attribute(:closed_issues_count)
    assert_equal({ 'major' => 1, 'patch' => 1 }, package.read_attribute(:update_type_counts))
  end
end
