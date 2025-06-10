require 'test_helper'

class AdvisoryTest < ActiveSupport::TestCase
  context 'validations' do
    should validate_presence_of(:uuid)
    
    context 'with a valid advisory' do
      subject { Advisory.new(uuid: 'test-uuid') }
      should validate_uniqueness_of(:uuid)
    end
  end
  
  context 'associations' do
    should have_many(:issue_advisories).dependent(:destroy)
    should have_many(:issues).through(:issue_advisories)
  end
  
  context 'scopes' do
    setup do
      @critical_advisory = Advisory.create!(
        uuid: 'test-uuid-1',
        severity: 'CRITICAL',
        published_at: 1.day.ago,
        repository_url: 'https://github.com/test/repo',
        packages: [{ 'ecosystem' => 'npm', 'package_name' => 'test-package' }],
        identifiers: ['CVE-2023-1234'],
        title: 'Test Advisory'
      )
      
      @low_advisory = Advisory.create!(
        uuid: 'test-uuid-2',
        severity: 'LOW',
        published_at: 2.days.ago,
        repository_url: 'https://github.com/other/repo',
        packages: [{ 'ecosystem' => 'pip', 'package_name' => 'other-package' }],
        identifiers: ['GHSA-xxxx-yyyy-zzzz']
      )
    end
    
    should 'filter by severity' do
      assert_includes Advisory.by_severity('CRITICAL'), @critical_advisory
      assert_not_includes Advisory.by_severity('CRITICAL'), @low_advisory
    end
    
    should 'filter by ecosystem' do
      assert_includes Advisory.by_ecosystem('npm'), @critical_advisory
      assert_not_includes Advisory.by_ecosystem('npm'), @low_advisory
    end
    
    should 'filter by package' do
      assert_includes Advisory.by_package('npm', 'test-package'), @critical_advisory
      assert_not_includes Advisory.by_package('npm', 'test-package'), @low_advisory
    end
    
    should 'filter by repository url' do
      assert_includes Advisory.by_repository_url('https://github.com/test/repo'), @critical_advisory
      assert_not_includes Advisory.by_repository_url('https://github.com/test/repo'), @low_advisory
    end
    
    should 'order by recent' do
      advisories = Advisory.recent
      assert_equal @critical_advisory, advisories.first
      assert_equal @low_advisory, advisories.second
    end
  end
  
  context 'methods' do
    setup do
      @advisory = Advisory.create!(
        uuid: 'test-uuid',
        identifiers: ['CVE-2023-1234', 'GHSA-abcd-efgh-ijkl', 'RUSTSEC-2023-0001'],
        severity: 'HIGH',
        packages: [
          { 'ecosystem' => 'npm', 'package_name' => 'package1' },
          { 'ecosystem' => 'pip', 'package_name' => 'package2' }
        ],
        title: 'Test Advisory'
      )
    end
    
    should 'find by identifier' do
      assert_equal @advisory, Advisory.find_by_identifier('CVE-2023-1234')
      assert_equal @advisory, Advisory.find_by_identifier('GHSA-abcd-efgh-ijkl')
      assert_nil Advisory.find_by_identifier('CVE-2023-9999')
    end
    
    should 'extract CVE identifiers' do
      assert_equal ['CVE-2023-1234'], @advisory.cve_identifiers
    end
    
    should 'extract GHSA identifiers' do
      assert_equal ['GHSA-abcd-efgh-ijkl'], @advisory.ghsa_identifiers
    end
    
    should 'get primary identifier' do
      assert_equal 'CVE-2023-1234', @advisory.primary_identifier
    end
    
    should 'check if affects package' do
      assert @advisory.affects_package?('npm', 'package1')
      assert @advisory.affects_package?('pip', 'package2')
      assert_not @advisory.affects_package?('npm', 'package3')
    end
    
    should 'get affected packages for ecosystem' do
      npm_packages = @advisory.affected_packages_for_ecosystem('npm')
      assert_equal 1, npm_packages.size
      assert_equal 'package1', npm_packages.first['package_name']
    end
    
    should 'get severity class' do
      assert_equal 'warning', @advisory.severity_class
      
      @advisory.severity = 'CRITICAL'
      assert_equal 'danger', @advisory.severity_class
      
      @advisory.severity = 'LOW'
      assert_equal 'secondary', @advisory.severity_class
    end
    
    should 'get ecosystems' do
      assert_equal ['npm', 'pip'], @advisory.ecosystems
    end
    
    should 'get package names' do
      assert_equal ['package1', 'package2'], @advisory.package_names
    end
  end
  
  test "should detect CVE identifiers in markdown links" do
    # Create advisories
    advisory1 = Advisory.create!(
      uuid: 'cve-2025-46727',
      identifiers: ['CVE-2025-46727', 'GHSA-gjh7-p2fx-99vx'],
      title: 'Unbounded parameter parsing vulnerability'
    )
    
    advisory2 = Advisory.create!(
      uuid: 'cve-2025-27610', 
      identifiers: ['CVE-2025-27610', 'GHSA-7wqh-767x-r66v'],
      title: 'Local file inclusion vulnerability'
    )
    
    # Issue body with CVEs embedded in markdown links (like real Dependabot PRs)
    issue_body = <<~BODY
      Bumps [rack](https://github.com/rack/rack) from 2.2.10 to 2.2.14.
      <details>
      <summary>Changelog</summary>
      <p><em>Sourced from <a href="https://github.com/rack/rack/blob/main/CHANGELOG.md">rack's changelog</a>.</em></p>
      <blockquote>
      <h2>[2.2.14] - 2025-05-06</h2>
      <h3>Security</h3>
      <ul>
      <li><a href="https://github.com/rack/rack/security/advisories/GHSA-gjh7-p2fx-99vx">CVE-2025-46727</a> Unbounded parameter parsing in <code>Rack::QueryParser</code> can lead to memory exhaustion.</li>
      </ul>
      <h2>[2.2.13] - 2025-03-11</h2>
      <h3>Security</h3>
      <ul>
      <li><a href="https://github.com/rack/rack/security/advisories/GHSA-7wqh-767x-r66v">CVE-2025-27610</a> Local file inclusion in <code>Rack::Static</code>.</li>
      </ul>
      </blockquote>
      </details>
    BODY
    
    # Test the mentions_advisory? method
    mock_issue = OpenStruct.new(body: issue_body)
    
    assert Advisory.mentions_advisory?(mock_issue, advisory1), 
           "Should detect CVE-2025-46727 in markdown links"
    assert Advisory.mentions_advisory?(mock_issue, advisory2), 
           "Should detect CVE-2025-27610 in markdown links"
  end
end