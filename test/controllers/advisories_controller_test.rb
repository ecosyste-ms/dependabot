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
  
  test "should generate advisories atom feed" do
    get feed_advisories_url, headers: { 'Accept' => 'application/atom+xml' }
    assert_response :success
    assert_equal 'application/atom+xml; charset=utf-8', response.content_type
    
    # Check feed structure
    assert_match 'Security Advisories - Ecosyste.ms: Dependabot', response.body
    assert_match 'Latest security advisories tracked by Dependabot', response.body
    
    # Check advisory entries
    assert_match @critical_advisory.title, response.body
    assert_match @high_advisory.title, response.body
    assert_match 'CVE-2023-0001', response.body
    assert_match 'CVE-2023-0002', response.body
    
    # Check severity information
    assert_match '**Severity:** CRITICAL', response.body
    assert_match '**Severity:** HIGH', response.body
    
    # Check ecosystem information
    assert_match '**Affected Ecosystems:** npm', response.body
    assert_match '**Affected Ecosystems:** pip', response.body
  end
  
  test "should exclude withdrawn advisories from feed" do
    # Create a withdrawn advisory
    withdrawn_advisory = Advisory.create!(
      uuid: 'withdrawn-uuid',
      title: 'Withdrawn Advisory',
      severity: 'HIGH',
      published_at: 1.hour.ago,
      withdrawn_at: 30.minutes.ago,
      identifiers: ['CVE-2023-9999']
    )
    
    get feed_advisories_url, headers: { 'Accept' => 'application/atom+xml' }
    assert_response :success
    
    # Should include non-withdrawn advisories
    assert_match @critical_advisory.title, response.body
    assert_match @high_advisory.title, response.body
    
    # Should exclude withdrawn advisory
    assert_no_match withdrawn_advisory.title, response.body
    assert_no_match 'CVE-2023-9999', response.body
  end
  
  test "should generate advisory issues atom feed" do
    get feed_advisory_url(@critical_advisory), headers: { 'Accept' => 'application/atom+xml' }
    assert_response :success
    assert_equal 'application/atom+xml; charset=utf-8', response.content_type
    
    # Check feed structure
    assert_match "#{@critical_advisory.primary_identifier} - Dependabot Pull Requests", response.body
    assert_match "security advisory #{@critical_advisory.primary_identifier}", response.body
    
    # Check issue entries
    assert_match @issue.title, response.body
    assert_match @issue.repository.full_name, response.body
    assert_match "#{@issue.repository.full_name}##{@issue.number}", response.body
    
    # Check issue metadata
    assert_match '**Repository:** test/repo', response.body
    assert_match '**State:** Open', response.body
    assert_match 'dependabot[bot]', response.body
  end
  
  test "should handle advisory not found in issues feed" do
    get feed_advisory_url('nonexistent-uuid'), headers: { 'Accept' => 'application/atom+xml' }
    assert_response :not_found
  end
  
  test "should show feed discovery links in HTML" do
    # Test advisories index feed discovery
    get advisories_url
    assert_response :success
    assert_select 'link[rel="alternate"][type="application/atom+xml"][title*="Security Advisories"]'
    
    # Test advisory show feed discovery
    get advisory_url(@critical_advisory.uuid)
    assert_response :success
    assert_select "link[rel=\"alternate\"][type=\"application/atom+xml\"][title*=\"#{@critical_advisory.primary_identifier}\"]"
  end
  
  test "should show RSS feed buttons in UI" do
    # Test advisories index RSS button
    get advisories_url
    assert_response :success
    assert_select 'a[href=?]', feed_advisories_url do |elements|
      assert_match 'RSS Feed', elements.first.text
    end
    
    # Test advisory show RSS button
    get advisory_url(@critical_advisory.uuid)
    assert_response :success
    assert_select 'a[href=?]', feed_advisory_url(@critical_advisory) do |elements|
      assert_match 'RSS Feed', elements.first.text
    end
  end
  
  test "should exclude withdrawn advisories from index" do
    # Create a withdrawn advisory
    withdrawn_advisory = Advisory.create!(
      uuid: 'withdrawn-index-uuid',
      title: 'Withdrawn Advisory for Index',
      severity: 'MEDIUM',
      published_at: 1.hour.ago,
      withdrawn_at: 30.minutes.ago,
      identifiers: ['CVE-2023-8888']
    )
    
    get advisories_url
    assert_response :success
    
    # Should include non-withdrawn advisories
    assert_match @critical_advisory.title, response.body
    assert_match @high_advisory.title, response.body
    
    # Should exclude withdrawn advisory
    assert_no_match withdrawn_advisory.title, response.body
  end
  
  test "should show withdrawn badge on advisory show page" do
    # Create a withdrawn advisory
    withdrawn_advisory = Advisory.create!(
      uuid: 'withdrawn-show-uuid',
      title: 'Withdrawn Advisory for Show',
      severity: 'LOW',
      published_at: 2.hours.ago,
      withdrawn_at: 1.hour.ago,
      identifiers: ['CVE-2023-7777']
    )
    
    get advisory_url(withdrawn_advisory.uuid)
    assert_response :success
    
    # Should show withdrawn badge
    assert_select '.badge.bg-warning', text: 'WITHDRAWN'
  end
end