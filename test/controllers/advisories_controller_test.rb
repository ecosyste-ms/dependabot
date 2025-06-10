require 'test_helper'

class AdvisoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @critical_advisory = Advisory.create!(
      uuid: 'test-uuid-critical',
      title: 'Critical Security Vulnerability',
      severity: 'CRITICAL',
      published_at: 1.day.ago,
      identifiers: ['CVE-2023-0001', 'GHSA-xxxx-yyyy-zzzz'],
      packages: [{ 'ecosystem' => 'npm', 'package_name' => 'test-package' }]
    )
    
    @high_advisory = Advisory.create!(
      uuid: 'test-uuid-high',
      title: 'High Severity Issue',
      severity: 'HIGH',
      published_at: 2.days.ago,
      identifiers: ['CVE-2023-0002'],
      packages: [{ 'ecosystem' => 'pip', 'package_name' => 'other-package' }]
    )
    
    # Create related issues
    host = Host.create!(name: 'github.com', url: 'https://github.com', kind: 'github')
    repo = Repository.create!(host: host, full_name: 'test/repo', owner: 'test')
    @issue = Issue.create!(
      repository: repo,
      host: host,
      user: 'dependabot[bot]',
      number: 1,
      title: 'Security update',
      state: 'open',
      pull_request: true,
      uuid: 'test-issue-uuid'
    )
    @issue.advisories << @critical_advisory
  end
  
  test "should get index" do
    get advisories_url
    assert_response :success
    assert_select "h1", "Security Advisories"
  end
  
  test "should filter by severity" do
    get advisories_url(severity: 'CRITICAL')
    assert_response :success
    assert_match @critical_advisory.title, response.body
    assert_no_match @high_advisory.title, response.body
  end
  
  test "should filter by ecosystem" do
    get advisories_url(ecosystem: 'npm')
    assert_response :success
    assert_match @critical_advisory.title, response.body
    assert_no_match @high_advisory.title, response.body
  end
  
  test "should search by identifier" do
    get advisories_url(q: 'CVE-2023-0001')
    assert_response :success
    assert_match @critical_advisory.title, response.body
    assert_no_match @high_advisory.title, response.body
  end
  
  test "should sort by severity" do
    get advisories_url(sort: 'severity', order: 'desc')
    assert_response :success
    # Critical should appear before High when sorted by severity desc
    body = response.body
    critical_pos = body.index(@critical_advisory.title)
    high_pos = body.index(@high_advisory.title)
    assert critical_pos < high_pos
  end
  
  test "should show advisory" do
    get advisory_url(@critical_advisory.uuid)
    assert_response :success
    assert_select "h1", @critical_advisory.title
    assert_match "CVE-2023-0001", response.body
    assert_match "GHSA-xxxx-yyyy-zzzz", response.body
  end
  
  test "should show advisory by identifier" do
    get advisory_url('CVE-2023-0001')
    assert_response :success
    assert_select "h1", @critical_advisory.title
  end
  
  test "should show related issues" do
    get advisory_url(@critical_advisory.uuid)
    assert_response :success
    assert_match @issue.title, response.body
  end
  
  test "should filter issues by state" do
    # Create a closed issue
    closed_issue = Issue.create!(
      repository: @issue.repository,
      host: @issue.host,
      user: 'dependabot[bot]',
      number: 2,
      title: 'Closed security update',
      state: 'closed',
      closed_at: Time.current,
      pull_request: true,
      uuid: 'test-closed-issue-uuid'
    )
    closed_issue.advisories << @critical_advisory
    
    get advisory_url(@critical_advisory.uuid, state: 'open')
    assert_response :success
    assert_match @issue.title, response.body
    assert_no_match closed_issue.title, response.body
  end
end