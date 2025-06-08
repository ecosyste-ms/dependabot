require "test_helper"

class OwnersControllerTest < ActionDispatch::IntegrationTest
  test "owner issues page" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    repository = Repository.create!(host: host, full_name: 'rails/rails', owner: 'rails')
    package = Package.create!(ecosystem: 'rubygems', name: 'rails')
    
    issue = Issue.create!(
      repository: repository,
      host: host,
      number: 1,
      title: 'Bump activesupport from 7.0.0 to 7.1.0',
      state: 'open',
      pull_request: true,
      uuid: 'test-uuid-owner',
      user: 'dependabot[bot]'
    )
    
    issue_package = IssuePackage.create!(
      issue: issue,
      package: package,
      update_type: 'minor'
    )
    
    get issues_host_owner_path(host, 'rails')
    assert_response :success
    assert_match 'rails', response.body
    assert_match issue.title, response.body
  end

  test "owner feed" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    repository = Repository.create!(host: host, full_name: 'rails/rails', owner: 'rails')
    package = Package.create!(ecosystem: 'rubygems', name: 'rails')
    
    issue = Issue.create!(
      repository: repository,
      host: host,
      number: 1,
      title: 'Owner feed test issue',
      state: 'merged',
      pull_request: true,
      uuid: 'test-uuid-owner-feed',
      user: 'dependabot[bot]'
    )
    
    issue_package = IssuePackage.create!(
      issue: issue,
      package: package,
      update_type: 'patch'
    )
    
    get feed_host_owner_path(host, 'rails')
    assert_response :success
    assert_equal 'application/atom+xml', response.content_type.split(';').first
    assert_match 'rails - Dependabot PRs', response.body
    assert_match issue.title, response.body
    assert_match 'rails/rails', response.body
  end

  test "owner show page includes issues link and feed" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    repository = Repository.create!(host: host, full_name: 'rails/rails', owner: 'rails', issues_count: 5)
    
    get host_owner_path(host, 'rails')
    assert_response :success
    assert_select 'a[href=?]', issues_host_owner_path(host, 'rails')
    assert_select 'a[href=?]', feed_host_owner_path(host, 'rails')
  end

  test "owner issues page with no issues" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    repository = Repository.create!(host: host, full_name: 'empty/repo', owner: 'empty')
    
    get issues_host_owner_path(host, 'empty')
    assert_response :success
    assert_match 'No Dependabot PRs Found', response.body
  end

  test "owner feed with multiple repositories" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    repo1 = Repository.create!(host: host, full_name: 'rails/rails', owner: 'rails')
    repo2 = Repository.create!(host: host, full_name: 'rails/activesupport', owner: 'rails')
    package = Package.create!(ecosystem: 'rubygems', name: 'minitest')
    
    issue1 = Issue.create!(
      repository: repo1,
      host: host,
      number: 1,
      title: 'Update minitest in rails',
      state: 'open',
      pull_request: true,
      uuid: 'test-uuid-multi-1',
      user: 'dependabot[bot]'
    )
    
    issue2 = Issue.create!(
      repository: repo2,
      host: host,
      number: 2,
      title: 'Update minitest in activesupport',
      state: 'merged',
      pull_request: true,
      uuid: 'test-uuid-multi-2',
      user: 'dependabot[bot]'
    )
    
    IssuePackage.create!(issue: issue1, package: package, update_type: 'minor')
    IssuePackage.create!(issue: issue2, package: package, update_type: 'patch')
    
    get feed_host_owner_path(host, 'rails')
    assert_response :success
    assert_match 'rails/rails', response.body
    assert_match 'rails/activesupport', response.body
    assert_match issue1.title, response.body
    assert_match issue2.title, response.body
  end

  test "owner issues page includes feed discovery link" do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    
    get issues_host_owner_path(host, 'rails')
    assert_response :success
    assert_select 'link[rel="alternate"][type="application/atom+xml"]'
  end
end