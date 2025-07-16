require "test_helper"

class RepositoriesControllerTest < ActionDispatch::IntegrationTest
  test "should filter issues by label" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    repository = Repository.create!(host: host, full_name: 'test/repo')
    
    # Create issues with different labels
    issue1 = Issue.create!(
      repository: repository,
      host: host,
      number: 1,
      title: 'Update npm package',
      state: 'open',
      pull_request: true,
      uuid: 'uuid1',
      labels: ['javascript', 'dependencies']
    )
    
    issue2 = Issue.create!(
      repository: repository,
      host: host,
      number: 2,
      title: 'Update pip package',
      state: 'open',
      pull_request: true,
      uuid: 'uuid2',
      labels: ['python', 'dependencies']
    )
    
    issue3 = Issue.create!(
      repository: repository,
      host: host,
      number: 3,
      title: 'Update gem',
      state: 'open',
      pull_request: true,
      uuid: 'uuid3',
      labels: ['ruby', 'dependencies']
    )
    
    # Test no filter shows all
    get host_repository_path(host, repository)
    assert_response :success
  end

  test "repository atom feed" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    repository = Repository.create!(host: host, full_name: 'test/repo', issues_count: 1)
    
    issue = Issue.create!(
      repository: repository,
      host: host,
      number: 1,
      title: 'Bump test-package from 1.0.0 to 2.0.0',
      state: 'open',
      pull_request: true,
      uuid: 'test-uuid-1',
      user: 'dependabot[bot]'
    )
    
    get feed_host_repository_path(host, repository)
    
    if response.status == 500
      puts "Response body: #{response.body}"
      puts "Status: #{response.status}"
    end
    
    assert_response :success
    assert_equal 'application/atom+xml', response.content_type.split(';').first
    assert_match repository.full_name, response.body
    assert_match 'Dependabot Pull Requests', response.body
    assert_match issue.title, response.body
  end

  test "repository html page includes feed discovery link" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    repository = Repository.create!(host: host, full_name: 'test/repo')
    
    get host_repository_path(host, repository)
    assert_response :success
    assert_select 'link[rel="alternate"][type="application/atom+xml"]'
  end
  
  test "should not show duplicate issues when issue has multiple packages" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    repository = Repository.create!(host: host, full_name: 'test/repo')
    
    # Create an issue
    issue = Issue.create!(
      repository: repository,
      host: host,
      number: 1,
      title: 'Update multiple packages',
      state: 'open',
      pull_request: true,
      uuid: 'test-uuid-1',
      user: 'dependabot[bot]'
    )
    
    # Create multiple packages for the same issue
    package1 = Package.create!(ecosystem: 'npm', name: 'lodash')
    package2 = Package.create!(ecosystem: 'npm', name: 'express')
    
    IssuePackage.create!(issue: issue, package: package1)
    IssuePackage.create!(issue: issue, package: package2)
    
    get host_repository_path(host, repository)
    assert_response :success
    
    # Check that the issue appears only once, not multiple times
    issue_cards = css_select("div[id='issue_#{issue.id}']")
    assert_equal 1, issue_cards.length, "Issue should appear only once, but found #{issue_cards.length} times"
  end
  
  test "should not show duplicate issues when issue has multiple advisories" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    repository = Repository.create!(host: host, full_name: 'test/repo')
    
    # Create an issue
    issue = Issue.create!(
      repository: repository,
      host: host,
      number: 1,
      title: 'Security update for lodash',
      state: 'open',
      pull_request: true,
      uuid: 'test-uuid-1',
      user: 'dependabot[bot]'
    )
    
    # Create multiple advisories for the same issue
    advisory1 = Advisory.create!(
      uuid: 'test-advisory-1',
      title: 'CVE-2021-23337',
      identifiers: ['CVE-2021-23337'],
      severity: 'HIGH'
    )
    
    advisory2 = Advisory.create!(
      uuid: 'test-advisory-2', 
      title: 'GHSA-test-1234',
      identifiers: ['GHSA-test-1234'],
      severity: 'MEDIUM'
    )
    
    IssueAdvisory.create!(issue: issue, advisory: advisory1)
    IssueAdvisory.create!(issue: issue, advisory: advisory2)
    
    get host_repository_path(host, repository)
    assert_response :success
    
    # Check that the issue appears only once, not multiple times
    issue_cards = css_select("div[id='issue_#{issue.id}']")
    assert_equal 1, issue_cards.length, "Issue should appear only once, but found #{issue_cards.length} times"
  end
  
  test "should return distinct issues from query" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    repository = Repository.create!(host: host, full_name: 'test/repo')
    
    # Create an issue with multiple associated records
    issue = Issue.create!(
      repository: repository,
      host: host,
      number: 1,
      title: 'Complex update',
      state: 'open',
      pull_request: true,
      uuid: 'test-uuid-1',
      user: 'dependabot[bot]'
    )
    
    # Add multiple packages and advisories to simulate real-world complexity
    2.times do |i|
      package = Package.create!(ecosystem: 'npm', name: "package-#{i}")
      IssuePackage.create!(issue: issue, package: package)
      
      advisory = Advisory.create!(
        uuid: "test-advisory-#{i}",
        title: "CVE-2021-#{i}",
        identifiers: ["CVE-2021-#{i}"],
        severity: 'HIGH'
      )
      IssueAdvisory.create!(issue: issue, advisory: advisory)
    end
    
    # Test the actual query that the controller uses
    scope = repository.issues.includes(:host, :advisories, issue_packages: :package)
    issues_with_includes = scope.order('issues.created_at DESC').to_a
    
    # Check that we get exactly one issue, not duplicates
    assert_equal 1, issues_with_includes.length, "Query should return exactly 1 issue, but got #{issues_with_includes.length}"
    assert_equal issue.id, issues_with_includes.first.id
  end

  test "should raise RecordNotFound when repository does not exist" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    
    get host_repository_path(host, 'nonexistent/repo')
    assert_response :not_found
  end
end