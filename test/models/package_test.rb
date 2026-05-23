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
end
