require 'test_helper'

class Api::V1::RepositoriesControllerTest < ActionDispatch::IntegrationTest
  test "lookup syncs a stale repository" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    repository = Repository.create!(host: host, full_name: 'test/lookup-repo', last_synced_at: 2.days.ago)
    Repository.any_instance.expects(:sync_repository_async)

    get api_v1_repositories_lookup_path(url: 'https://github.com/test/lookup-repo')

    assert_redirected_to api_v1_host_repository_path(host, repository)
  end
end
