require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get root_path
    assert_response :success
    assert_select 'h1', 'Recent Dependabot Pull Requests'
  end

  test "homepage includes global feed discovery link" do
    get root_path
    assert_response :success
    assert_select 'link[rel="alternate"][type="application/atom+xml"]'
  end

  test "homepage has visible RSS feed button" do
    get root_path
    assert_response :success
    assert_select 'a[href=?]', global_feed_path do
      assert_select 'svg' # RSS icon
    end
  end

  test "global atom feed" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    repository = Repository.create!(host: host, full_name: 'test/repo')
    package = Package.create!(ecosystem: 'npm', name: 'test-package')

    issue = Issue.create!(
      repository: repository,
      host: host,
      number: 1,
      title: 'Global feed test issue',
      body: 'Test body',
      node_id: 'test-node-id',
      state: 'open',
      pull_request: true,
      uuid: 'test-uuid-global',
      user: 'dependabot[bot]'
    )
    
    issue_package = IssuePackage.create!(
      issue: issue,
      package: package,
      update_type: 'minor'
    )
    
    get global_feed_path
    assert_response :success
    assert_equal 'application/atom+xml', response.content_type.split(';').first
    assert_match 'Dependabot Updates', response.body
    assert_match issue.title, response.body
    assert_match repository.full_name, response.body
  end

  test "chart data endpoint" do
    get chart_data_path
    assert_response :success
    assert_equal 'application/json', response.content_type.split(';').first
    
    json_response = JSON.parse(response.body)
    assert json_response.is_a?(Array)
    assert_equal 3, json_response.length # Open, Merged, Closed
    assert_equal 'Open', json_response.first['name']
  end

  test "homepage shows security indicator for issues with security identifiers" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    repository = Repository.create!(host: host, full_name: 'test/repo')

    # Create a security-related issue
    security_issue = Issue.create!(
      repository: repository,
      host: host,
      number: 1,
      title: 'Security fix for vulnerability',
      body: 'This PR addresses CVE-2023-1234',
      node_id: 'test-node-id-security',
      state: 'open',
      pull_request: true,
      uuid: 'test-uuid-security',
      user: 'dependabot[bot]',
      created_at: 1.hour.ago
    )
    
    get root_path
    assert_response :success
    
    # Should have security badge and shield icon for security issue
    assert_select 'span.badge.bg-warning', text: /Security/
    assert_select 'span.badge.bg-warning svg'
  end

  test "homepage does not show security indicator for regular issues" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    repository = Repository.create!(host: host, full_name: 'test/repo')

    # Create a regular issue
    regular_issue = Issue.create!(
      repository: repository,
      host: host,
      number: 2,
      title: 'Regular dependency update',
      body: 'Updates package from 1.0.0 to 1.1.0',
      node_id: 'test-node-id-regular',
      state: 'open',
      pull_request: true,
      uuid: 'test-uuid-regular',
      user: 'dependabot[bot]',
      created_at: 1.hour.ago
    )
    
    get root_path
    assert_response :success
    
    # Should not have security badge
    assert_select 'span.badge.bg-warning', text: /Security/, count: 0
  end
  
  test "should filter for security PRs when security param is true" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    repository = Repository.create!(host: host, full_name: 'test/repo')

    # Create a security issue
    security_issue = Issue.create!(
      repository: repository,
      host: host,
      uuid: 'home-security-uuid',
      number: 1,
      title: 'Security fix',
      body: 'This fixes CVE-2023-1234',
      node_id: 'test-node-id-home-security',
      state: 'open',
      user: 'dependabot[bot]',
      pull_request: true,
      created_at: 1.hour.ago
    )

    # Create a non-security issue
    regular_issue = Issue.create!(
      repository: repository,
      host: host,
      uuid: 'home-regular-uuid',
      number: 2,
      title: 'Regular update',
      body: 'Updates package from 1.0 to 2.0',
      node_id: 'test-node-id-home-regular',
      state: 'open',
      user: 'dependabot[bot]',
      pull_request: true,
      created_at: 2.hours.ago
    )
    
    # Test with security filter
    get root_path(security: 'true')
    assert_response :success
    
    # Should include security issue but not regular issue
    assert_match security_issue.title, response.body
    assert_no_match regular_issue.title, response.body
    
    # Test without security filter
    get root_path
    assert_response :success
    
    # Should include both issues
    assert_match security_issue.title, response.body
    assert_match regular_issue.title, response.body
  end
  
  test "should filter security PRs in atom feed when security param is true" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    repository = Repository.create!(host: host, full_name: 'test/repo')

    # Create a security issue
    security_issue = Issue.create!(
      repository: repository,
      host: host,
      uuid: 'feed-security-uuid',
      number: 1,
      title: 'Security fix',
      body: 'This fixes GHSA-abcd-efgh-ijkl',
      node_id: 'test-node-id-feed-security',
      state: 'open',
      user: 'dependabot[bot]',
      pull_request: true,
      created_at: 1.hour.ago
    )

    # Create a non-security issue
    regular_issue = Issue.create!(
      repository: repository,
      host: host,
      uuid: 'feed-regular-uuid',
      number: 2,
      title: 'Regular update',
      body: 'Updates package from 1.0 to 2.0',
      node_id: 'test-node-id-feed-regular',
      state: 'open',
      user: 'dependabot[bot]',
      pull_request: true,
      created_at: 2.hours.ago
    )

    # Test security filter in feed
    get global_feed_path(security: 'true')
    assert_response :success
    assert_equal 'application/atom+xml', response.content_type.split(';').first

    # Should include security issue but not regular issue
    assert_match security_issue.title, response.body
    assert_no_match regular_issue.title, response.body
  end

  test "should exclude incomplete PRs from homepage" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    repository = Repository.create!(host: host, full_name: 'test/repo')

    # Create a complete PR
    complete_pr = Issue.create!(
      repository: repository,
      host: host,
      uuid: 'complete-pr-uuid',
      number: 1,
      title: 'Complete PR',
      body: 'This is a complete PR',
      node_id: 'complete-node-id',
      state: 'open',
      user: 'dependabot[bot]',
      pull_request: true,
      created_at: 1.hour.ago
    )

    # Create an incomplete PR (missing title)
    incomplete_pr = Issue.create!(
      repository: repository,
      host: host,
      uuid: 'incomplete-pr-uuid',
      number: 2,
      title: nil,
      body: 'This is an incomplete PR',
      node_id: 'incomplete-node-id',
      state: 'open',
      user: 'dependabot[bot]',
      pull_request: true,
      created_at: 30.minutes.ago
    )

    get root_path
    assert_response :success

    # Should include complete PR but not incomplete PR
    assert_match complete_pr.title, response.body
    assert_select 'h5', text: complete_pr.title
    # Incomplete PR has no title so can't search for it, but verify count
    assert_select '.package-card', count: 1
  end

  test "should exclude incomplete PRs from atom feed" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    repository = Repository.create!(host: host, full_name: 'test/repo')

    # Create a complete PR
    complete_pr = Issue.create!(
      repository: repository,
      host: host,
      uuid: 'complete-feed-uuid',
      number: 1,
      title: 'Complete PR',
      body: 'This is a complete PR',
      node_id: 'complete-node-id',
      state: 'open',
      user: 'dependabot[bot]',
      pull_request: true,
      created_at: 1.hour.ago
    )

    # Create an incomplete PR (missing body)
    incomplete_pr = Issue.create!(
      repository: repository,
      host: host,
      uuid: 'incomplete-feed-uuid',
      number: 2,
      title: 'Incomplete PR',
      body: nil,
      node_id: 'incomplete-node-id',
      state: 'open',
      user: 'dependabot[bot]',
      pull_request: true,
      created_at: 30.minutes.ago
    )

    get global_feed_path
    assert_response :success
    assert_equal 'application/atom+xml', response.content_type.split(';').first

    # Should include complete PR but not incomplete PR
    assert_match complete_pr.title, response.body
    assert_no_match incomplete_pr.title, response.body
  end
end