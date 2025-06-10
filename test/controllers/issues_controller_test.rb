require 'test_helper'

class IssuesControllerTest < ActionDispatch::IntegrationTest
  test "should show issue with markdown rendered body" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    repository = Repository.create!(host: host, full_name: 'owner/example-project')
    
    markdown_body = <<~MARKDOWN
      Bumps [lodash](https://github.com/lodash/lodash) from 4.17.20 to 4.17.21.
      
      <details>
      <summary>Release notes</summary>
      <p><em>Sourced from <a href="https://github.com/lodash/lodash/releases">lodash's releases</a>.</em></p>
      <blockquote>
      <h2>4.17.21</h2>
      <p>Security fixes</p>
      </blockquote>
      </details>
      
      **Note:** This contains security fixes.
    MARKDOWN
    
    issue = Issue.create!(
      repository: repository,
      host: host,
      uuid: 'test-uuid-123',
      number: 1,
      title: 'Bump lodash from 4.17.20 to 4.17.21',
      state: 'closed',
      user: 'dependabot[bot]',
      pull_request: true,
      body: markdown_body
    )
    
    get host_repository_issue_path(host, repository, issue)
    assert_response :success
    
    # Check that the page renders the issue title
    assert_select 'h1', text: issue.title
    
    # Check that markdown is rendered (HTML details tag should be preserved)
    assert_select 'details'
    assert_select 'summary', text: 'Release notes'
    
    # Check that the body content is present
    assert_match 'Security fixes', response.body
    
    # Check that markdown links are converted to HTML
    assert_select 'a[href="https://github.com/lodash/lodash"]'
  end
  
  test "should show issue without body gracefully" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    repository = Repository.create!(host: host, full_name: 'owner/example-project')
    
    issue = Issue.create!(
      repository: repository,
      host: host,
      uuid: 'test-uuid-456',
      number: 2,
      title: 'Bump express from 4.17.0 to 4.17.1',
      state: 'open',
      user: 'dependabot[bot]',
      pull_request: true,
      body: nil
    )
    
    get host_repository_issue_path(host, repository, issue)
    assert_response :success
    
    # Check that the page renders the issue title
    assert_select 'h1', text: issue.title
    
    # Should not render any markdown content when body is nil
    assert_no_match '<details>', response.body
  end
  
  test "should return 404 for missing issue" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    repository = Repository.create!(host: host, full_name: 'owner/example-project')
    
    # Try to access an issue number that doesn't exist
    get host_repository_issue_path(host, repository, 999999)
    
    # The route constraint allows any id pattern, but controller should raise RecordNotFound
    # which Rails handles as 404
    assert_response :not_found
  end
end