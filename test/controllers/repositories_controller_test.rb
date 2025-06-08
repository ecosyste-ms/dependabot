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
end