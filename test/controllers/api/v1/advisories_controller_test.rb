require 'test_helper'

class Api::V1::AdvisoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @advisory1 = Advisory.create!(
      uuid: 'api-test-uuid-1',
      title: 'Test Advisory 1',
      severity: 'HIGH',
      published_at: 1.day.ago,
      identifiers: ['CVE-2023-1111'],
      packages: [{ 'ecosystem' => 'npm', 'package_name' => 'test-pkg' }],
      cvss_score: 7.5,
      epss_percentage: 0.02,
      epss_percentile: 0.80
    )
    
    @advisory2 = Advisory.create!(
      uuid: 'api-test-uuid-2',
      title: 'Test Advisory 2',
      severity: 'LOW',
      published_at: 3.days.ago,
      identifiers: ['GHSA-aaaa-bbbb-cccc'],
      packages: [{ 'ecosystem' => 'pip', 'package_name' => 'another-pkg' }]
    )
    
    # Create test issue linked to advisory1
    host = Host.create!(name: 'github.com', url: 'https://github.com', kind: 'github')
    repo = Repository.create!(host: host, full_name: 'test/repo', owner: 'test')
    @issue = Issue.create!(
      repository: repo,
      host: host,
      user: 'dependabot[bot]',
      number: 1,
      title: 'Security fix for CVE-2023-1111',
      state: 'open',
      pull_request: true,
      uuid: 'api-test-issue-uuid'
    )
    @issue.advisories << @advisory1
  end
  
  test "should get index as JSON" do
    get api_v1_advisories_url, as: :json
    assert_response :success
    
    json = JSON.parse(response.body)
    assert_equal 2, json.length
    
    # Check first advisory structure
    advisory = json.find { |a| a['uuid'] == @advisory1.uuid }
    assert_not_nil advisory
    assert_equal @advisory1.title, advisory['title']
    assert_equal 'HIGH', advisory['severity']
    assert_equal ['CVE-2023-1111'], advisory['identifiers']
    assert_equal 1, advisory['issues_count']
    assert_equal ['npm'], advisory['ecosystems']
  end
  
  test "should filter by severity" do
    get api_v1_advisories_url(severity: 'HIGH'), as: :json
    assert_response :success
    
    json = JSON.parse(response.body)
    assert_equal 1, json.length
    assert_equal @advisory1.uuid, json.first['uuid']
  end
  
  test "should filter by ecosystem" do
    get api_v1_advisories_url(ecosystem: 'npm'), as: :json
    assert_response :success
    
    json = JSON.parse(response.body)
    assert_equal 1, json.length
    assert_equal @advisory1.uuid, json.first['uuid']
  end
  
  test "should filter by identifier" do
    get api_v1_advisories_url(identifier: 'CVE-2023-1111'), as: :json
    assert_response :success
    
    json = JSON.parse(response.body)
    assert_equal 1, json.length
    assert_equal @advisory1.uuid, json.first['uuid']
  end
  
  test "should show advisory" do
    get api_v1_advisory_url(@advisory1.uuid), as: :json
    assert_response :success
    
    json = JSON.parse(response.body)
    assert_equal @advisory1.uuid, json['uuid']
    assert_equal @advisory1.title, json['title']
    assert_equal 7.5, json['cvss_score']
    assert_equal 0.02, json['epss_percentage']
    assert_equal 0.80, json['epss_percentile']
  end
  
  test "should show advisory by identifier" do
    get api_v1_advisory_url('CVE-2023-1111'), as: :json
    assert_response :success
    
    json = JSON.parse(response.body)
    assert_equal @advisory1.uuid, json['uuid']
  end
  
  test "should get advisory issues" do
    get issues_api_v1_advisory_url(@advisory1.uuid), as: :json
    assert_response :success
    
    json = JSON.parse(response.body)
    assert_equal 1, json.length
    assert_equal @issue.number, json.first['number']
  end
  
  test "should handle pagination" do
    # Create many advisories to test pagination
    15.times do |i|
      Advisory.create!(
        uuid: "page-test-#{i}",
        title: "Page Test #{i}",
        severity: 'MEDIUM',
        published_at: i.days.ago
      )
    end
    
    get api_v1_advisories_url(per_page: 10), as: :json
    assert_response :success
    
    json = JSON.parse(response.body)
    assert_equal 10, json.length  # Should only return 10 items due to pagination
  end
end