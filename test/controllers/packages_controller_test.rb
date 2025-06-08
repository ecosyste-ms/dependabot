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


end