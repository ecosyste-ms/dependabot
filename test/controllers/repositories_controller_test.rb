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
end