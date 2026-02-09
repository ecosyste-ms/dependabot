require "test_helper"

class RepositoryTest < ActiveSupport::TestCase
  setup do
    @host = Host.find_or_create_by!(name: "GitHub") do |h|
      h.url = "https://github.com"
      h.kind = "github"
    end
    @repository = Repository.create!(
      host: @host,
      full_name: "owner/repo",
      owner: "owner"
    )
  end

  context 'sync_details' do
    should "update repository from API response" do
      stub_request(:get, @repository.repos_api_url)
        .to_return(
          status: 200,
          body: { owner: "new-owner", status: nil, default_branch: "main", fork: false, archived: false }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      @repository.sync_details
      @repository.reload

      assert_equal "new-owner", @repository.owner
      assert_equal "main", @repository.default_branch
      assert_not_nil @repository.last_synced_at
    end

    should "mark repository as not_found on 404" do
      stub_request(:get, @repository.repos_api_url)
        .to_return(status: 404, body: '{}', headers: { 'Content-Type' => 'application/json' })

      @repository.sync_details
      @repository.reload

      assert_equal "not_found", @repository.status
    end

    should "return early on non-200 response" do
      stub_request(:get, @repository.repos_api_url)
        .to_return(status: 500, body: '', headers: {})

      @repository.sync_details
      @repository.reload

      assert_nil @repository.last_synced_at
    end

    should "return early when response body is not valid JSON" do
      stub_request(:get, @repository.repos_api_url)
        .to_return(
          status: 200,
          body: '<html>Bad Gateway</html>',
          headers: { 'Content-Type' => 'text/html' }
        )

      assert_nothing_raised do
        @repository.sync_details
      end

      @repository.reload
      assert_nil @repository.last_synced_at
    end

    should "return early when response body is empty" do
      stub_request(:get, @repository.repos_api_url)
        .to_return(
          status: 200,
          body: '',
          headers: { 'Content-Type' => 'application/json' }
        )

      assert_nothing_raised do
        @repository.sync_details
      end

      @repository.reload
      assert_nil @repository.last_synced_at
    end
  end
end
