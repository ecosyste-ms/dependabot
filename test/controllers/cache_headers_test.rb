require 'test_helper'

class CacheHeadersTest < ActionDispatch::IntegrationTest
  test "home page sets cache headers with s-maxage" do
    get root_path
    assert_response :success

    cache_control = response.headers['Cache-Control']
    assert_match(/public/, cache_control)
    assert_match(/s-maxage=21600/, cache_control)
    assert_match(/max-age=300/, cache_control)
    assert_match(/stale-while-revalidate=21600/, cache_control)
    assert_match(/stale-if-error=86400/, cache_control)
  end

  test "repository show page sets cache headers" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    repository = Repository.create!(host: host, full_name: 'test/cache-repo')

    get host_repository_path(host, repository)
    assert_response :success

    cache_control = response.headers['Cache-Control']
    assert_match(/s-maxage=21600/, cache_control)
  end

  test "API endpoint sets shorter s-maxage" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')

    get api_v1_hosts_url, as: :json
    assert_response :success

    cache_control = response.headers['Cache-Control']
    assert_match(/s-maxage=3600/, cache_control)
    assert_match(/max-age=300/, cache_control)
  end

  test "API ping endpoint does not set cache headers" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    repository = Repository.create!(host: host, full_name: 'test/ping-repo')
    Repository.any_instance.expects(:sync_async)

    get ping_api_v1_host_repository_url(host, repository), as: :json
    assert_response :success

    cache_control = response.headers['Cache-Control'].to_s
    assert_no_match(/s-maxage/, cache_control)
  end

  test "repository lookup does not set cache headers" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    repository = Repository.create!(host: host, full_name: 'test/lookup-repo', last_synced_at: 1.hour.ago)

    get lookup_repositories_path(url: 'https://github.com/test/lookup-repo')
    assert_response :redirect

    cache_control = response.headers['Cache-Control'].to_s
    assert_no_match(/s-maxage/, cache_control)
  end
end
