require "test_helper"

class PackagesControllerTest < ActionDispatch::IntegrationTest
  test "package atom feed" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    repository = Repository.create!(host: host, full_name: 'test/repo')
    package = Package.create!(ecosystem: 'npm', name: 'test-package', issues_count: 1)
    
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
    
    issue_package = IssuePackage.create!(
      issue: issue,
      package: package,
      update_type: 'major'
    )
    
    get feed_packages_path(package.ecosystem, package.name)
    assert_response :success
    assert_equal 'application/atom+xml', response.content_type.split(';').first
    assert_match package.name, response.body
    assert_match 'Dependabot Updates', response.body
  end

  test "package html page includes feed discovery link" do
    package = Package.create!(ecosystem: 'npm', name: 'test-package')
    
    get show_packages_path(package.ecosystem, package.name)
    assert_response :success
    assert_select 'link[rel="alternate"][type="application/atom+xml"]'
  end
  
  test "ecosystem issues should filter for security PRs when security param is true" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    repository = Repository.create!(host: host, full_name: 'test/repo')
    package = Package.create!(ecosystem: 'npm', name: 'test-package', issues_count: 2)
    
    # Create a security issue
    security_issue = Issue.create!(
      repository: repository,
      host: host,
      uuid: 'ecosystem-security-uuid',
      number: 1,
      title: 'Security fix',
      body: 'This fixes CVE-2023-1234',
      state: 'open',
      user: 'dependabot[bot]',
      pull_request: true,
      created_at: 1.hour.ago
    )
    
    # Create a non-security issue
    regular_issue = Issue.create!(
      repository: repository,
      host: host,
      uuid: 'ecosystem-regular-uuid',
      number: 2,
      title: 'Regular update',
      body: 'Updates package from 1.0 to 2.0',
      state: 'open',
      user: 'dependabot[bot]',
      pull_request: true,
      created_at: 2.hours.ago
    )
    
    # Create issue packages
    IssuePackage.create!(issue: security_issue, package: package, update_type: 'patch')
    IssuePackage.create!(issue: regular_issue, package: package, update_type: 'major')
    
    # Test with security filter
    get ecosystem_issues_packages_path(package.ecosystem, security: 'true')
    assert_response :success
    
    # Should include security issue but not regular issue
    assert_match security_issue.title, response.body
    assert_no_match regular_issue.title, response.body
    
    # Test without security filter
    get ecosystem_issues_packages_path(package.ecosystem)
    assert_response :success
    
    # Should include both issues
    assert_match security_issue.title, response.body
    assert_match regular_issue.title, response.body
  end
  
  test "ecosystem feed should filter for security PRs when security param is true" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    repository = Repository.create!(host: host, full_name: 'test/repo')
    package = Package.create!(ecosystem: 'npm', name: 'test-package', issues_count: 2)
    
    # Create a security issue
    security_issue = Issue.create!(
      repository: repository,
      host: host,
      uuid: 'ecosystem-feed-security-uuid',
      number: 1,
      title: 'Security fix',
      body: 'This fixes RUSTSEC-2023-0001',
      state: 'open',
      user: 'dependabot[bot]',
      pull_request: true,
      created_at: 1.hour.ago
    )
    
    # Create a non-security issue
    regular_issue = Issue.create!(
      repository: repository,
      host: host,
      uuid: 'ecosystem-feed-regular-uuid',
      number: 2,
      title: 'Regular update',
      body: 'Updates package from 1.0 to 2.0',
      state: 'open',
      user: 'dependabot[bot]',
      pull_request: true,
      created_at: 2.hours.ago
    )
    
    # Create issue packages
    IssuePackage.create!(issue: security_issue, package: package, update_type: 'patch')
    IssuePackage.create!(issue: regular_issue, package: package, update_type: 'major')
    
    # Test with security filter in feed
    get ecosystem_feed_packages_path(package.ecosystem, security: 'true')
    assert_response :success
    assert_equal 'application/atom+xml', response.content_type.split(';').first
    
    # Should include security issue but not regular issue
    assert_match security_issue.title, response.body
    assert_no_match regular_issue.title, response.body
  end

end