require 'test_helper'

class Api::V1::IssuesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    @repository = Repository.create!(host: @host, full_name: 'owner/example-project')
  end
  
  test "should get index" do
    get api_v1_host_repository_issues_path(@host, @repository)
    assert_response :success
    assert_equal 'application/json; charset=utf-8', response.content_type
  end
  
  test "should filter for security PRs when security param is true" do
    # Create a security issue
    security_issue = Issue.create!(
      repository: @repository,
      host: @host,
      uuid: 'security-api-uuid',
      number: 1,
      title: 'Security fix',
      body: 'This fixes CVE-2023-1234',
      state: 'open',
      user: 'dependabot[bot]',
      pull_request: true
    )
    
    # Create a non-security issue
    regular_issue = Issue.create!(
      repository: @repository,
      host: @host,
      uuid: 'regular-api-uuid',
      number: 2,
      title: 'Regular update',
      body: 'Updates package from 1.0 to 2.0',
      state: 'open',
      user: 'dependabot[bot]',
      pull_request: true
    )
    
    # Test with security filter
    get api_v1_host_repository_issues_path(@host, @repository, security: 'true')
    assert_response :success
    
    json_response = JSON.parse(response.body)
    issue_titles = json_response.map { |issue| issue['title'] }
    
    # Should include security issue but not regular issue
    assert_includes issue_titles, security_issue.title
    assert_not_includes issue_titles, regular_issue.title
    
    # Test without security filter
    get api_v1_host_repository_issues_path(@host, @repository)
    assert_response :success
    
    json_response = JSON.parse(response.body)
    issue_titles = json_response.map { |issue| issue['title'] }
    
    # Should include both issues
    assert_includes issue_titles, security_issue.title
    assert_includes issue_titles, regular_issue.title
  end
  
  test "should work with other filters combined" do
    # Create a security issue
    security_issue = Issue.create!(
      repository: @repository,
      host: @host,
      uuid: 'security-combined-uuid',
      number: 1,
      title: 'Security fix',
      body: 'This fixes GHSA-abcd-efgh-ijkl',
      state: 'open',
      user: 'dependabot[bot]',
      pull_request: true
    )
    
    # Create a closed security issue
    closed_security_issue = Issue.create!(
      repository: @repository,
      host: @host,
      uuid: 'closed-security-uuid',
      number: 2,
      title: 'Closed security fix',
      body: 'Fixed RUSTSEC-2023-0001',
      state: 'closed',
      user: 'dependabot[bot]',
      pull_request: true
    )
    
    # Test combining security filter with state filter
    get api_v1_host_repository_issues_path(@host, @repository, security: 'true', state: 'open')
    assert_response :success
    
    json_response = JSON.parse(response.body)
    issue_titles = json_response.map { |issue| issue['title'] }
    
    # Should include only open security issue
    assert_includes issue_titles, security_issue.title
    assert_not_includes issue_titles, closed_security_issue.title
  end
end