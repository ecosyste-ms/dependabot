require "test_helper"

class IssueTest < ActiveSupport::TestCase
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
  
  context 'associations' do
    should have_many(:issue_advisories).dependent(:destroy)
    should have_many(:advisories).through(:issue_advisories)
  end

  context 'scopes' do
    setup do
      @issue_with_body = Issue.create!(
        repository: @repository,
        host: @host,
        user: "dependabot[bot]",
        title: "Test issue with body",
        body: "This is a regular update",
        number: 200,
        state: "open",
        pull_request: true,
        uuid: "test-uuid-with-body"
      )
      
      @issue_without_body = Issue.create!(
        repository: @repository,
        host: @host,
        user: "dependabot[bot]",
        title: "Test issue without body",
        body: nil,
        number: 201,
        state: "open",
        pull_request: true,
        uuid: "test-uuid-without-body"
      )
      
      @issue_empty_body = Issue.create!(
        repository: @repository,
        host: @host,
        user: "dependabot[bot]",
        title: "Test issue with empty body",
        body: "",
        number: 202,
        state: "open",
        pull_request: true,
        uuid: "test-uuid-empty-body"
      )
      
      @security_issue = Issue.create!(
        repository: @repository,
        host: @host,
        user: "dependabot[bot]",
        title: "Security fix",
        body: "This fixes CVE-2023-1234 vulnerability",
        number: 203,
        state: "open",
        pull_request: true,
        uuid: "test-uuid-security"
      )
      
      @ghsa_issue = Issue.create!(
        repository: @repository,
        host: @host,
        user: "dependabot[bot]",
        title: "Another security fix",
        body: "Addresses GHSA-abcd-efgh-ijkl security issue",
        number: 204,
        state: "open",
        pull_request: true,
        uuid: "test-uuid-ghsa"
      )
      
      @rustsec_issue = Issue.create!(
        repository: @repository,
        host: @host,
        user: "dependabot[bot]",
        title: "Rust security fix",
        body: "Fixes RUSTSEC-2023-0001",
        number: 205,
        state: "open",
        pull_request: true,
        uuid: "test-uuid-rustsec"
      )
    end
    
    should "has_body scope filters issues with non-empty body" do
      issues_with_body = Issue.has_body
      
      assert_includes issues_with_body, @issue_with_body
      assert_includes issues_with_body, @security_issue
      assert_includes issues_with_body, @ghsa_issue
      assert_includes issues_with_body, @rustsec_issue
      
      assert_not_includes issues_with_body, @issue_without_body
      assert_not_includes issues_with_body, @issue_empty_body
    end
    
    should "security_prs scope filters issues with security identifiers" do
      security_prs = Issue.security_prs
      
      assert_includes security_prs, @security_issue
      assert_includes security_prs, @ghsa_issue
      assert_includes security_prs, @rustsec_issue
      
      assert_not_includes security_prs, @issue_with_body
      assert_not_includes security_prs, @issue_without_body
      assert_not_includes security_prs, @issue_empty_body
    end
    
    should "security_prs scope works with other scopes" do
      # Test chaining with other scopes
      open_security_prs = Issue.security_prs.open
      
      assert_includes open_security_prs, @security_issue
      assert_includes open_security_prs, @ghsa_issue
      assert_includes open_security_prs, @rustsec_issue
      
      # Close one issue and test again
      @security_issue.update!(state: "closed")
      open_security_prs = Issue.security_prs.open
      
      assert_not_includes open_security_prs, @security_issue
      assert_includes open_security_prs, @ghsa_issue
      assert_includes open_security_prs, @rustsec_issue
    end
    
    should "security_prs scope is case insensitive" do
      lowercase_cve_issue = Issue.create!(
        repository: @repository,
        host: @host,
        user: "dependabot[bot]",
        title: "Lowercase CVE",
        body: "Fixes cve-2023-5678",
        number: 206,
        state: "open",
        pull_request: true,
        uuid: "test-uuid-lowercase-cve"
      )
      
      security_prs = Issue.security_prs
      assert_includes security_prs, lowercase_cve_issue
    end
  end

  test "parses standard bump format" do
    issue = create_dependabot_issue("Bump rack from 2.2.16 to 2.2.17")
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "Bump", metadata[:prefix]
    assert_equal 1, metadata[:packages].length
    assert_equal "rack", metadata[:packages][0][:name]
    assert_equal "2.2.16", metadata[:packages][0][:old_version]
    assert_equal "2.2.17", metadata[:packages][0][:new_version]
    assert_nil metadata[:path]
  end

  test "parses bump with path" do
    issue = create_dependabot_issue("Bump rack from 2.2.16 to 2.2.17 in /server/src/main/webapp/WEB-INF/rails")
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "Bump", metadata[:prefix]
    assert_equal 1, metadata[:packages].length
    assert_equal "rack", metadata[:packages][0][:name]
    assert_equal "2.2.16", metadata[:packages][0][:old_version]
    assert_equal "2.2.17", metadata[:packages][0][:new_version]
    assert_equal "/server/src/main/webapp/WEB-INF/rails", metadata[:path]
  end

  test "parses chore(deps) format" do
    issue = create_dependabot_issue("chore(deps): bump ruff from 0.9.10 to 0.11.12")
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "chore(deps)", metadata[:prefix]
    assert_equal 1, metadata[:packages].length
    assert_equal "ruff", metadata[:packages][0][:name]
    assert_equal "0.9.10", metadata[:packages][0][:old_version]
    assert_equal "0.11.12", metadata[:packages][0][:new_version]
    assert_nil metadata[:path]
  end

  test "parses multiple packages" do
    issue = create_dependabot_issue("Bump webpack-dev-server and @angular-devkit/build-angular")
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "Bump", metadata[:prefix]
    assert_equal 2, metadata[:packages].length
    assert_equal "webpack-dev-server", metadata[:packages][0][:name]
    assert_equal "@angular-devkit/build-angular", metadata[:packages][1][:name]
    assert_nil metadata[:path]
  end

  test "parses multiple packages with version info from body" do
    body = "Updates `eventsource` from 0.1.6 to 2.0.2\nUpdates `webpack-dev-server` from 3.1.4 to 3.11.3"
    issue = create_dependabot_issue_with_body("Bump eventsource and webpack-dev-server", body)
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "Bump", metadata[:prefix]
    assert_equal 2, metadata[:packages].length
    
    # First package
    assert_equal "eventsource", metadata[:packages][0][:name]
    assert_equal "0.1.6", metadata[:packages][0][:old_version]
    assert_equal "2.0.2", metadata[:packages][0][:new_version]
    
    # Second package
    assert_equal "webpack-dev-server", metadata[:packages][1][:name]
    assert_equal "3.1.4", metadata[:packages][1][:old_version]
    assert_equal "3.11.3", metadata[:packages][1][:new_version]
  end

  test "parses chore(deps-dev) format" do
    issue = create_dependabot_issue("chore(deps-dev): bump ruff from 0.9.10 to 0.11.12")
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "chore(deps-dev)", metadata[:prefix]
    assert_equal 1, metadata[:packages].length
    assert_equal "ruff", metadata[:packages][0][:name]
    assert_equal "0.9.10", metadata[:packages][0][:old_version]
    assert_equal "0.11.12", metadata[:packages][0][:new_version]
    assert_nil metadata[:path]
  end

  test "parses build(deps) format with path" do
    issue = create_dependabot_issue("build(deps): bump body-parser from 1.20.2 to 1.20.3 in /node")
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "build(deps)", metadata[:prefix]
    assert_equal 1, metadata[:packages].length
    assert_equal "body-parser", metadata[:packages][0][:name]
    assert_equal "1.20.2", metadata[:packages][0][:old_version]
    assert_equal "1.20.3", metadata[:packages][0][:new_version]
    assert_equal "/node", metadata[:path]
  end

  test "parses package with special characters" do
    issue = create_dependabot_issue("Bump @types/react from 18.0.0 to 18.2.0")
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "Bump", metadata[:prefix]
    assert_equal 1, metadata[:packages].length
    assert_equal "@types/react", metadata[:packages][0][:name]
    assert_equal "18.0.0", metadata[:packages][0][:old_version]
    assert_equal "18.2.0", metadata[:packages][0][:new_version]
  end

  test "parses package with dots" do
    issue = create_dependabot_issue("Bump lodash.merge from 4.6.0 to 4.6.2")
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "Bump", metadata[:prefix]
    assert_equal 1, metadata[:packages].length
    assert_equal "lodash.merge", metadata[:packages][0][:name]
    assert_equal "4.6.0", metadata[:packages][0][:old_version]
    assert_equal "4.6.2", metadata[:packages][0][:new_version]
  end

  test "parses package with slashes" do
    issue = create_dependabot_issue("Bump elm/json from 1.1.0 to 1.2.0")
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "Bump", metadata[:prefix]
    assert_equal 1, metadata[:packages].length
    assert_equal "elm/json", metadata[:packages][0][:name]
    assert_equal "1.1.0", metadata[:packages][0][:old_version]
    assert_equal "1.2.0", metadata[:packages][0][:new_version]
  end

  test "parses complex package name with organization" do
    issue = create_dependabot_issue("Bump org.springframework.boot:spring-boot-starter-parent from 3.4.5 to 3.5.0")
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "Bump", metadata[:prefix]
    assert_equal 1, metadata[:packages].length
    assert_equal "org.springframework.boot:spring-boot-starter-parent", metadata[:packages][0][:name]
    assert_equal "3.4.5", metadata[:packages][0][:old_version]
    assert_equal "3.5.0", metadata[:packages][0][:new_version]
  end

  test "parses group updates with table" do
    title = "Bumps the minor-patch-dependencies group with 5 updates in the / directory"
    body = <<~BODY
      Bumps the minor-patch-dependencies group with 5 updates in the / directory:

      | Package | From | To |
      | --- | --- | --- |
      | [com.google.cloud.opentelemetry:exporter-trace](https://github.com/GoogleCloudPlatform/opentelemetry-operations-java) | `0.34.0` | `0.35.0` |
      | [com.google.cloud.opentelemetry:exporter-metrics](https://github.com/GoogleCloudPlatform/opentelemetry-operations-java) | `0.34.0` | `0.35.0` |
      | bio.terra:terra-resource-janitor-client | `0.113.49-SNAPSHOT` | `0.113.50-SNAPSHOT` |
      | [com.google.cloud:google-cloud-pubsub](https://github.com/googleapis/java-pubsub) | `1.139.4` | `1.140.0` |
      | com.google.auth:google-auth-library-oauth2-http | `1.36.0` | `1.37.0` |
    BODY
    
    issue = create_dependabot_issue_with_body(title, body)
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "Bumps", metadata[:prefix]
    assert_equal "minor-patch-dependencies", metadata[:group_name]
    assert_equal 5, metadata[:update_count]
    assert_equal "the / directory", metadata[:path]
    assert_equal 5, metadata[:packages].length
    
    # Check first package
    assert_equal "com.google.cloud.opentelemetry:exporter-trace", metadata[:packages][0][:name]
    assert_equal "0.34.0", metadata[:packages][0][:old_version]
    assert_equal "0.35.0", metadata[:packages][0][:new_version]
    
    # Check package without markdown link
    assert_equal "bio.terra:terra-resource-janitor-client", metadata[:packages][2][:name]
    assert_equal "0.113.49-SNAPSHOT", metadata[:packages][2][:old_version]
    assert_equal "0.113.50-SNAPSHOT", metadata[:packages][2][:new_version]
  end

  test "parses group updates with across directory format" do
    title = "[CORE-69]: Bump the minor-patch-dependencies group across 1 directory with 5 updates"
    body = <<~BODY
      Bumps the minor-patch-dependencies group with 5 updates in the / directory:

      | Package | From | To |
      | --- | --- | --- |
      | [com.google.cloud.opentelemetry:exporter-trace](https://github.com/GoogleCloudPlatform/opentelemetry-operations-java) | `0.34.0` | `0.35.0` |
      | bio.terra:terra-resource-janitor-client | `0.113.49-SNAPSHOT` | `0.113.50-SNAPSHOT` |
    BODY
    
    issue = create_dependabot_issue_with_body(title, body)
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "[CORE-69]: Bump", metadata[:prefix]
    assert_equal "minor-patch-dependencies", metadata[:group_name]
    assert_equal 5, metadata[:update_count]
    assert_equal 2, metadata[:packages].length
    
    # Check first package
    assert_equal "com.google.cloud.opentelemetry:exporter-trace", metadata[:packages][0][:name]
    assert_equal "0.34.0", metadata[:packages][0][:old_version]
    assert_equal "0.35.0", metadata[:packages][0][:new_version]
  end

  test "parses group updates with individual update lines" do
    title = "fix(deps): bump the production-dependencies group across 1 directory with 2 updates"
    body = <<~BODY
      Bumps the production-dependencies group with 2 updates in the / directory: [commander](https://github.com/tj/commander.js) and [form-data](https://github.com/form-data/form-data).

      Updates `commander` from 12.1.0 to 14.0.0
      Updates `form-data` from 4.0.2 to 4.0.3
    BODY
    
    issue = create_dependabot_issue_with_body(title, body)
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "fix(deps): bump", metadata[:prefix]
    assert_equal "production-dependencies", metadata[:group_name]
    assert_equal 2, metadata[:update_count]
    assert_equal 2, metadata[:packages].length
    
    # Check packages
    assert_equal "commander", metadata[:packages][0][:name]
    assert_equal "12.1.0", metadata[:packages][0][:old_version]
    assert_equal "14.0.0", metadata[:packages][0][:new_version]
    
    assert_equal "form-data", metadata[:packages][1][:name]
    assert_equal "4.0.2", metadata[:packages][1][:old_version]
    assert_equal "4.0.3", metadata[:packages][1][:new_version]
  end

  test "parses various group update title formats" do
    test_cases = [
      "fix(deps): bump the production-dependencies group across 1 directory with 2 updates",
      "chore(deps): Bump the dependencies group with 2 updates", 
      "build(deps-dev): bump the regular group with 2 updates",
      "Bump the npm_and_yarn group across 1 directory with 17 updates",
      "Bump the go_modules group across 1 directory with 2 updates",
      "Build(deps): bump the vuetify group across 3 directories with 1 update",
      "Bump the docusaurus group with 7 updates",
      "build(deps): Bump the npm_and_yarn group across 2 directories with 1 update",
      "Bump the dev-dependencies group with 2 updates",
      "build(deps): bump the github-actions group with 2 updates"
    ]
    
    body_with_table = <<~BODY
      Updates with packages:

      | Package | From | To |
      | --- | --- | --- |
      | test-package | `1.0.0` | `1.1.0` |
    BODY
    
    test_cases.each do |title|
      issue = create_dependabot_issue_with_body(title, body_with_table)
      metadata = issue.parse_dependabot_metadata
      
      assert_not_nil metadata, "Failed to parse: #{title}"
      assert metadata[:group_name].present?, "No group name for: #{title}"
      assert metadata[:update_count] > 0, "No update count for: #{title}"
      assert metadata[:packages].any?, "No packages parsed for: #{title}"
    end
  end

  test "returns nil for group updates without table" do
    issue = create_dependabot_issue("Bump the ruby-dependencies group with 2 updates")
    metadata = issue.parse_dependabot_metadata
    
    assert_nil metadata
  end

  test "parses terraform requirement format" do
    issue = Issue.new(
      repository: @repository,
      host: @host,
      user: "dependabot[bot]",
      title: "Update hashicorp/azurerm requirement from ~> 4.31.0 to ~> 4.32.0 in /terraform",
      number: 1,
      state: "open",
      labels: ["terraform"]
    )
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "Update", metadata[:prefix]
    assert_equal 1, metadata[:packages].length
    assert_equal "hashicorp/azurerm", metadata[:packages][0][:name]
    assert_equal "~> 4.31.0", metadata[:packages][0][:old_version]
    assert_equal "~> 4.32.0", metadata[:packages][0][:new_version]
    assert_equal "/terraform", metadata[:path]
  end

  test "parses version range format" do
    issue = create_dependabot_issue("Bump Velopack to 0.0.1251, 0.0.1297")
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "Bump", metadata[:prefix]
    assert_equal 1, metadata[:packages].length
    assert_equal "Velopack", metadata[:packages][0][:name]
    assert_equal "0.0.1297", metadata[:packages][0][:new_version] # Should use last version
    assert_nil metadata[:packages][0][:old_version]
  end

  test "parses deps prefix format" do
    issue = create_dependabot_issue("(deps)Update Cake.Http to 5.0.0")
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "(deps)Update", metadata[:prefix]
    assert_equal 1, metadata[:packages].length
    assert_equal "Cake.Http", metadata[:packages][0][:name]
    assert_equal "5.0.0", metadata[:packages][0][:new_version]
  end

  test "parses single package without version in title" do
    body = "Updates `cross-spawn` from 7.0.3 to 7.0.6\n<details>...</details>"
    issue = create_dependabot_issue_with_body("Bump cross-spawn", body)
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "Bump", metadata[:prefix]
    assert_equal 1, metadata[:packages].length
    assert_equal "cross-spawn", metadata[:packages][0][:name]
    assert_equal "7.0.3", metadata[:packages][0][:old_version]
    assert_equal "7.0.6", metadata[:packages][0][:new_version]
  end

  test "parses requirement update format" do
    issue = create_dependabot_issue("[main] (deps): Update dotnet/arcade requirement to fdcda9b4919dd16bd2388b5421cc5d55afac0e88")
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "[main] (deps): ", metadata[:prefix]
    assert_equal 1, metadata[:packages].length
    assert_equal "dotnet/arcade", metadata[:packages][0][:name]
    assert_equal "fdcda9b4919dd16bd2388b5421cc5d55afac0e88", metadata[:packages][0][:new_version]
    assert_nil metadata[:packages][0][:old_version]
  end

  test "parses group updates with performed updates format" do
    title = "Bump the microsoftentityframework group with 1 update"
    body = <<~BODY
      Performed the following updates:
      - Updated Microsoft.NET.Test.Sdk from 17.13.0 to 17.14.1 in /net/QACoverTest/QACoverTest.csproj
      - Updated Microsoft.NET.Test.Sdk from 17.13.0 to 17.14.1 in /net/QACoverTestEf/QACoverTestEf.csproj
    BODY
    
    issue = create_dependabot_issue_with_body(title, body)
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "Bump", metadata[:prefix]
    assert_equal "microsoftentityframework", metadata[:group_name]
    assert_equal 1, metadata[:update_count]
    assert_equal 2, metadata[:packages].length
    
    assert_equal "Microsoft.NET.Test.Sdk", metadata[:packages][0][:name]
    assert_equal "17.13.0", metadata[:packages][0][:old_version]
    assert_equal "17.14.1", metadata[:packages][0][:new_version]
    assert_equal "/net/QACoverTest/QACoverTest.csproj", metadata[:packages][0][:path]
  end

  test "parses group updates without package details" do
    body = "Dependabot will resolve any conflicts with this PR as long as you don't alter it yourself."
    issue = create_dependabot_issue_with_body("chore(deps): bump the minor-patch group across 1 directory with 13 updates", body)
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "chore(deps): bump", metadata[:prefix]
    assert_equal "minor-patch", metadata[:group_name]
    assert_equal 13, metadata[:update_count]
    assert_equal [], metadata[:packages]
  end

  test "parses complex group title with path" do
    body = "Dependabot will resolve any conflicts with this PR as long as you don't alter it yourself."
    issue = create_dependabot_issue_with_body("chore(deps)(deps-dev): bump the development-dependencies group in /acr-image-promotion-action with 17 updates", body)
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "chore(deps)(deps-dev): bump", metadata[:prefix]
    assert_equal "development-dependencies", metadata[:group_name]
    assert_equal 17, metadata[:update_count]
    assert_equal "/acr-image-promotion-action", metadata[:path]
    assert_equal [], metadata[:packages]
  end

  test "parses complex version ranges with emoji" do
    issue = create_dependabot_issue("🛠️(deps): Update hashicorp/azurerm requirement from >= 3.0.0, < 4.30.1 to >= 3.0.0, < 4.31.1 in /terraform")
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "🛠️(deps): Update", metadata[:prefix]
    assert_equal 1, metadata[:packages].length
    assert_equal "hashicorp/azurerm", metadata[:packages][0][:name]
    assert_equal ">= 3.0.0, < 4.30.1", metadata[:packages][0][:old_version]
    assert_equal ">= 3.0.0, < 4.31.1", metadata[:packages][0][:new_version]
    assert_equal "/terraform", metadata[:path]
  end

  test "parses lowercase update requirement format" do
    issue = create_dependabot_issue("chore(deps): update hashicorp/azurerm requirement from ~> 3.116.0 to ~> 4.31.0 in /terraform")
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "chore(deps): update", metadata[:prefix]
    assert_equal 1, metadata[:packages].length
    assert_equal "hashicorp/azurerm", metadata[:packages][0][:name]
    assert_equal "~> 3.116.0", metadata[:packages][0][:old_version]
    assert_equal "~> 4.31.0", metadata[:packages][0][:new_version]
    assert_equal "/terraform", metadata[:path]
  end

  test "parses simple bump format" do
    body = "Dependabot will resolve any conflicts with this PR as long as you don't alter it yourself."
    issue = create_dependabot_issue_with_body("bump semver", body)
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "bump", metadata[:prefix]
    assert_equal 1, metadata[:packages].length
    assert_equal "semver", metadata[:packages][0][:name]
    assert_nil metadata[:packages][0][:old_version]
    assert_nil metadata[:packages][0][:new_version]
  end

  test "parses criterion requirement format correctly" do
    issue = create_dependabot_issue("Update criterion requirement from 0.5 to 0.6")
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "Update", metadata[:prefix]
    assert_equal 1, metadata[:packages].length
    assert_equal "criterion", metadata[:packages][0][:name]
    assert_equal "0.5", metadata[:packages][0][:old_version]
    assert_equal "0.6", metadata[:packages][0][:new_version]
    assert_nil metadata[:path]
  end

  test "parses complex package name requirement format" do
    issue = create_dependabot_issue("Update some-complex_package.name requirement from 1.2.3 to 2.0.0")
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "Update", metadata[:prefix]
    assert_equal 1, metadata[:packages].length
    assert_equal "some-complex_package.name", metadata[:packages][0][:name]
    assert_equal "1.2.3", metadata[:packages][0][:old_version]
    assert_equal "2.0.0", metadata[:packages][0][:new_version]
    assert_nil metadata[:path]
  end

  test "parses pytest-cov requirement with complex version ranges" do
    issue = create_dependabot_issue("chore(deps): update pytest-cov requirement from <6.0.0,>=4.0.0 to >=4.0.0,<7.0.0")
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "chore(deps): update", metadata[:prefix]
    assert_equal 1, metadata[:packages].length
    assert_equal "pytest-cov", metadata[:packages][0][:name]
    assert_equal "<6.0.0,>=4.0.0", metadata[:packages][0][:old_version]
    assert_equal ">=4.0.0,<7.0.0", metadata[:packages][0][:new_version]
    assert_nil metadata[:path]
  end

  test "parses dj-database-url requirement with version ranges" do
    issue = create_dependabot_issue("Update dj-database-url requirement from <3,>=2 to >=2,<4")
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "Update", metadata[:prefix]
    assert_equal 1, metadata[:packages].length
    assert_equal "dj-database-url", metadata[:packages][0][:name]
    assert_equal "<3,>=2", metadata[:packages][0][:old_version]
    assert_equal ">=2,<4", metadata[:packages][0][:new_version]
    assert_nil metadata[:path]
  end

  test "parses @types/node requirement with path" do
    issue = create_dependabot_issue("Update @types/node requirement from ^22.15.3 to ^22.15.30 in /playwright")
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "Update", metadata[:prefix]
    assert_equal 1, metadata[:packages].length
    assert_equal "@types/node", metadata[:packages][0][:name]
    assert_equal "^22.15.3", metadata[:packages][0][:old_version]
    assert_equal "^22.15.30", metadata[:packages][0][:new_version]
    assert_equal "/playwright", metadata[:path]
  end

  test "infers github actions ecosystem from path" do
    issue = Issue.new(
      repository: @repository,
      host: @host,
      user: "dependabot[bot]",
      title: "Bump actions/setup-node from 3 to 4 in /.github/workflows",
      number: 1,
      state: "open",
      labels: [] # No ecosystem labels to test path-based inference
    )
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "Bump", metadata[:prefix]
    assert_equal 1, metadata[:packages].length
    assert_equal "actions/setup-node", metadata[:packages][0][:name]
    assert_equal "3", metadata[:packages][0][:old_version]
    assert_equal "4", metadata[:packages][0][:new_version]
    assert_equal "/.github/workflows", metadata[:path]
    assert_equal "actions", metadata[:ecosystem]
  end

  test "parses metadata for any user since all PRs are from dependabot" do
    issue = Issue.new(
      repository: @repository,
      host: @host,
      user: "human-user",
      title: "Bump rack from 2.2.16 to 2.2.17",
      number: 1,
      state: "open"
    )
    
    metadata = issue.parse_dependabot_metadata
    assert_not_nil metadata
    assert_equal "Bump", metadata[:prefix]
    assert_equal "rack", metadata[:packages].first[:name]
  end

  test "handles package creation errors gracefully" do
    issue = Issue.create!(
      repository: @repository,
      host: @host,
      user: "dependabot[bot]",
      title: "Test issue",
      number: 999,
      state: "open",
      pull_request: true,
      uuid: "test-uuid-graceful-error"
    )

    # Simulate metadata with invalid ecosystem
    invalid_metadata = {
      ecosystem: "invalid-ecosystem",
      packages: [
        { name: "test-package", old_version: "1.0.0", new_version: "2.0.0" }
      ]
    }

    initial_package_count = Package.count

    # This should not raise an exception
    assert_nothing_raised do
      issue.send(:create_package_associations, invalid_metadata)
    end

    # No packages should have been created
    assert_equal initial_package_count, Package.count

    # Valid ecosystem should still work
    valid_metadata = {
      ecosystem: "npm",
      packages: [
        { name: "test-valid-package", old_version: "1.0.0", new_version: "2.0.0" }
      ]
    }

    assert_nothing_raised do
      issue.send(:create_package_associations, valid_metadata)
    end

    # One package should have been created
    assert_equal initial_package_count + 1, Package.count

    # Clean up
    Package.find_by(name: "test-valid-package")&.destroy
  end

  test "handles race condition when creating packages" do
    issue = Issue.create!(
      repository: @repository,
      host: @host,
      user: "dependabot[bot]",
      title: "Test race condition",
      number: 998,
      state: "open",
      pull_request: true,
      uuid: "test-uuid-race-condition"
    )

    # Create a package first to simulate the race condition scenario
    existing_package = Package.create!(
      name: "@metrostar/comet-extras",
      ecosystem: "npm"
    )

    metadata = {
      ecosystem: "npm",
      packages: [
        { name: "@metrostar/comet-extras", old_version: "1.0.0", new_version: "2.0.0" }
      ]
    }

    initial_package_count = Package.count

    # Mock find_or_create_by! to raise RecordNotUnique to simulate race condition
    Package.stubs(:find_or_create_by!).raises(ActiveRecord::RecordNotUnique)
    
    # This should not raise an exception and should handle the race condition gracefully
    assert_nothing_raised do
      issue.send(:create_package_associations, metadata)
    end

    # Package count should remain the same (using existing package)
    assert_equal initial_package_count, Package.count

    # The issue should still be associated with the package
    assert_equal 1, issue.issue_packages.count
    assert_equal existing_package, issue.packages.first

    # Clean up
    existing_package.destroy
  end

  private

  def create_dependabot_issue(title)
    Issue.new(
      repository: @repository,
      host: @host,
      user: "dependabot[bot]",
      title: title,
      number: 1,
      state: "open",
      labels: ["ruby"] # This will map to 'rubygems' ecosystem
    )
  end

  test "parses Python packages with extras from table" do
    title = "Bump the python-deps group with 7 updates"
    body = <<~BODY
      Bump the python-deps group with 7 updates:

      | Package | From | To |
      | --- | --- | --- |
      | [pillow](https://github.com/python-pillow/Pillow) | `11.1.0` | `11.2.1` |
      | [hiredis](https://github.com/redis/hiredis-py) | `3.1.0` | `3.2.1` |
      | [celery](https://github.com/celery/celery) | `5.5.0` | `5.5.3` |
      | [django-celery-beat](https://github.com/celery/django-celery-beat) | `2.7.0` | `2.8.1` |
      | [uvicorn[standard]](https://github.com/encode/uvicorn) | `0.34.0` | `0.34.3` |
      | [django](https://github.com/django/django) | `5.1.8` | `5.2.2` |
      | [django-allauth[mfa]](https://github.com/sponsors/pennersr) | `65.7.0` | `65.9.0` |
    BODY
    
    issue = create_dependabot_issue_with_body(title, body)
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "Bump", metadata[:prefix]
    assert_equal 7, metadata[:packages].length
    
    # Check packages without extras work normally
    pillow_pkg = metadata[:packages].find { |p| p[:name] == "pillow" }
    assert_not_nil pillow_pkg
    assert_equal "pillow", pillow_pkg[:name]
    assert_equal "11.1.0", pillow_pkg[:old_version]
    assert_equal "11.2.1", pillow_pkg[:new_version]
    
    # Check packages with extras have extras stripped from name
    uvicorn_pkg = metadata[:packages].find { |p| p[:name] == "uvicorn" }
    assert_not_nil uvicorn_pkg
    assert_equal "uvicorn", uvicorn_pkg[:name]  # Should be "uvicorn", not "uvicorn[standard]"
    assert_equal "0.34.0", uvicorn_pkg[:old_version]
    assert_equal "0.34.3", uvicorn_pkg[:new_version]
    
    allauth_pkg = metadata[:packages].find { |p| p[:name] == "django-allauth" }
    assert_not_nil allauth_pkg
    assert_equal "django-allauth", allauth_pkg[:name]  # Should be "django-allauth", not "django-allauth[mfa]"
    assert_equal "65.7.0", allauth_pkg[:old_version]
    assert_equal "65.9.0", allauth_pkg[:new_version]
  end

  test "parses comma-separated packages" do
    issue = create_dependabot_issue("Bump cookie, express from 1.0.0 to 2.0.0")
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "Bump", metadata[:prefix]
    assert_equal 2, metadata[:packages].length
    
    # Check first package
    cookie_pkg = metadata[:packages].find { |p| p[:name] == "cookie" }
    assert_not_nil cookie_pkg
    assert_equal "cookie", cookie_pkg[:name]
    assert_equal "1.0.0", cookie_pkg[:old_version]
    assert_equal "2.0.0", cookie_pkg[:new_version]
    
    # Check second package
    express_pkg = metadata[:packages].find { |p| p[:name] == "express" }
    assert_not_nil express_pkg
    assert_equal "express", express_pkg[:name]
    assert_equal "1.0.0", express_pkg[:old_version]
    assert_equal "2.0.0", express_pkg[:new_version]
  end

  test "parses comma-separated packages with Python extras" do
    issue = create_dependabot_issue("Bump uvicorn[standard], django-allauth[mfa] from 1.0.0 to 2.0.0")
    metadata = issue.parse_dependabot_metadata
    
    assert_equal "Bump", metadata[:prefix]
    assert_equal 2, metadata[:packages].length
    
    # Check packages have extras stripped
    uvicorn_pkg = metadata[:packages].find { |p| p[:name] == "uvicorn" }
    assert_not_nil uvicorn_pkg
    assert_equal "uvicorn", uvicorn_pkg[:name]  # Should be "uvicorn", not "uvicorn[standard]"
    
    allauth_pkg = metadata[:packages].find { |p| p[:name] == "django-allauth" }
    assert_not_nil allauth_pkg
    assert_equal "django-allauth", allauth_pkg[:name]  # Should be "django-allauth", not "django-allauth[mfa]"
  end

  test "removes spaces from package names in tables" do
    title = "Bump the test-group group with 1 update"
    body = <<~BODY
      Bump the test-group group with 1 update:

      | Package | From | To |
      | --- | --- | --- |
      | [package with spaces](https://github.com/example/package-with-spaces) | `1.0.0` | `2.0.0` |
    BODY
    
    issue = create_dependabot_issue_with_body(title, body)
    metadata = issue.parse_dependabot_metadata
    
    # Package name should have spaces removed
    pkg = metadata[:packages].first
    assert_equal "packagewithspaces", pkg[:name]  # Spaces should be removed
    assert_equal "1.0.0", pkg[:old_version]
    assert_equal "2.0.0", pkg[:new_version]
  end

  def create_dependabot_issue_with_body(title, body)
    Issue.new(
      repository: @repository,
      host: @host,
      user: "dependabot[bot]",
      title: title,
      body: body,
      number: 1,
      state: "open",
      labels: ["javascript"] # This will map to 'npm' ecosystem
    )
  end
  
  context 'advisory methods' do
    setup do
      @issue = Issue.create!(
        repository: @repository,
        host: @host,
        user: "dependabot[bot]",
        title: "Bump package from 1.0.0 to 1.0.1",
        body: "This PR fixes CVE-2023-1234 and GHSA-abcd-efgh-ijkl. It's a security fix.",
        number: 123,
        state: "open",
        pull_request: true,
        uuid: "test-uuid-advisory"
      )
      
      @advisory1 = Advisory.create!(
        uuid: 'advisory-1',
        identifiers: ['CVE-2023-1234'],
        severity: 'HIGH',
        title: 'Test vulnerability 1'
      )
      
      @advisory2 = Advisory.create!(
        uuid: 'advisory-2',
        identifiers: ['GHSA-abcd-efgh-ijkl'],
        severity: 'CRITICAL',
        title: 'Test vulnerability 2'
      )
    end
    
    should "extract advisory identifiers from body" do
      identifiers = @issue.extract_advisory_identifiers(@issue.body)
      
      assert_includes identifiers, 'CVE-2023-1234'
      assert_includes identifiers, 'GHSA-abcd-efgh-ijkl'
      assert_equal 2, identifiers.uniq.size
    end
    
    should "extract various advisory identifier formats" do
      text = "Fixed CVE-2023-1234, CVE-2023-56789, GHSA-abcd-efgh-ijkl, RUSTSEC-2023-0001"
      identifiers = @issue.extract_advisory_identifiers(text)
      
      # Only identifiers that exist in the database should be returned
      assert_includes identifiers, 'CVE-2023-1234'
      assert_includes identifiers, 'GHSA-abcd-efgh-ijkl'
      # CVE-2023-56789 and RUSTSEC-2023-0001 don't exist in the database, so they shouldn't be included
      assert_not_includes identifiers, 'CVE-2023-56789'
      assert_not_includes identifiers, 'RUSTSEC-2023-0001'
      assert_equal 2, identifiers.uniq.size
    end
    
    should "cache advisory identifiers to avoid repeated database queries" do
      # Clear any existing cache
      Issue.clear_advisory_identifiers_cache
      
      # First call should hit the database
      identifiers1 = Issue.cached_advisory_identifiers
      assert_includes identifiers1, 'CVE-2023-1234'
      assert_includes identifiers1, 'GHSA-abcd-efgh-ijkl'
      
      # Mock Advisory.pluck to verify it's not called again
      Advisory.expects(:pluck).never
      
      # Second call should use cache
      identifiers2 = Issue.cached_advisory_identifiers
      assert_equal identifiers1.sort, identifiers2.sort
      
      # Cache should be cleared when advisory is updated
      @advisory1.update!(title: 'Updated title')
      Advisory.unstub(:pluck)
      
      # New identifiers should be loaded after cache clear
      identifiers3 = Issue.cached_advisory_identifiers
      assert_equal identifiers1.sort, identifiers3.sort # Same content, but freshly loaded
    end
    
    should "parse and link advisories" do
      assert_equal 0, @issue.advisories.count
      
      @issue.parse_and_link_advisories
      
      assert_equal 2, @issue.advisories.count
      assert_includes @issue.advisories, @advisory1
      assert_includes @issue.advisories, @advisory2
    end
    
    should "link advisories for any user since all PRs are from dependabot" do
      @issue.update!(user: 'regular-user')
      
      @issue.parse_and_link_advisories
      
      assert_equal 2, @issue.advisories.count
    end
    
    should "detect security-related PRs" do
      assert @issue.security_related?
      
      # Also security-related when has advisories
      @issue.advisories << @advisory1
      assert @issue.security_related?
      
      # Not security-related without keywords or advisories
      non_security_issue = Issue.create!(
        repository: @repository,
        host: @host,
        user: "dependabot[bot]",
        title: "Bump package from 1.0.0 to 1.0.1",
        body: "Regular dependency update",
        number: 124,
        state: "open",
        pull_request: true,
        uuid: "test-uuid-non-security"
      )
      
      assert_not non_security_issue.security_related?
    end
    
    should "return highest advisory severity" do
      @issue.advisories << @advisory1  # HIGH
      @issue.advisories << @advisory2  # CRITICAL
      
      assert_equal 'CRITICAL', @issue.advisory_severity
      
      # Test with single advisory
      issue2 = Issue.create!(
        repository: @repository,
        host: @host,
        user: "dependabot[bot]",
        title: "Another PR",
        number: 125,
        state: "open",
        pull_request: true,
        uuid: "test-uuid-severity"
      )
      issue2.advisories << @advisory1
      
      assert_equal 'HIGH', issue2.advisory_severity
      
      # Test with no advisories
      assert_nil Issue.new.advisory_severity
    end
    
    should "detect security identifiers without joins" do
      # Should detect CVE identifiers
      cve_issue = Issue.create!(
        repository: @repository,
        host: @host,
        user: "dependabot[bot]",
        title: "Security fix",
        body: "This fixes CVE-2023-1234",
        number: 126,
        state: "open",
        pull_request: true,
        uuid: "test-uuid-cve-fast"
      )
      assert cve_issue.has_security_identifier?
      
      # Should detect GHSA identifiers
      ghsa_issue = Issue.create!(
        repository: @repository,
        host: @host,
        user: "dependabot[bot]",
        title: "Security fix",
        body: "Addresses GHSA-abcd-efgh-ijkl",
        number: 127,
        state: "open",
        pull_request: true,
        uuid: "test-uuid-ghsa-fast"
      )
      assert ghsa_issue.has_security_identifier?
      
      # Should detect RUSTSEC identifiers
      rustsec_issue = Issue.create!(
        repository: @repository,
        host: @host,
        user: "dependabot[bot]",
        title: "Security fix",
        body: "Fixes RUSTSEC-2023-0001",
        number: 128,
        state: "open",
        pull_request: true,
        uuid: "test-uuid-rustsec-fast"
      )
      assert rustsec_issue.has_security_identifier?
      
      # Should be case insensitive
      case_issue = Issue.create!(
        repository: @repository,
        host: @host,
        user: "dependabot[bot]",
        title: "Security fix",
        body: "Fixes cve-2023-1234",
        number: 129,
        state: "open",
        pull_request: true,
        uuid: "test-uuid-case-fast"
      )
      assert case_issue.has_security_identifier?
      
      # Should return false for non-security PRs
      regular_issue = Issue.create!(
        repository: @repository,
        host: @host,
        user: "dependabot[bot]",
        title: "Regular update",
        body: "Updates package from 1.0 to 2.0",
        number: 130,
        state: "open",
        pull_request: true,
        uuid: "test-uuid-regular-fast"
      )
      assert_not regular_issue.has_security_identifier?
      
      # Should return false for empty body
      empty_body_issue = Issue.create!(
        repository: @repository,
        host: @host,
        user: "dependabot[bot]",
        title: "Update",
        body: nil,
        number: 131,
        state: "open",
        pull_request: true,
        uuid: "test-uuid-empty-fast"
      )
      assert_not empty_body_issue.has_security_identifier?
    end
  end

  context 'effective_state method' do
    should "return state when state is present" do
      issue = Issue.create!(
        repository: @repository,
        host: @host,
        user: "dependabot[bot]",
        title: "Test",
        number: 200,
        state: "open",
        pull_request: true,
        uuid: "test-state-open"
      )

      assert_equal "open", issue.effective_state
    end

    should "return 'merged' when PR is merged" do
      issue = Issue.create!(
        repository: @repository,
        host: @host,
        user: "dependabot[bot]",
        title: "Test",
        number: 201,
        state: "closed",
        pull_request: true,
        merged_at: Time.current,
        uuid: "test-state-merged"
      )

      assert_equal "merged", issue.effective_state
    end

    should "return 'open' when state is nil" do
      issue = Issue.create!(
        repository: @repository,
        host: @host,
        user: "dependabot[bot]",
        title: "Test",
        number: 202,
        state: nil,
        pull_request: true,
        uuid: "test-state-nil"
      )

      # Should default to 'open' instead of crashing
      assert_equal "open", issue.effective_state
    end

    should "allow capitalize when state is nil" do
      issue = Issue.create!(
        repository: @repository,
        host: @host,
        user: "dependabot[bot]",
        title: "Test",
        number: 203,
        state: nil,
        pull_request: true,
        uuid: "test-state-capitalize"
      )

      # This should not raise NoMethodError
      assert_nothing_raised do
        result = issue.effective_state.capitalize
        assert_equal "Open", result
      end
    end
  end

  context 'incomplete_prs scope' do
    should "find PRs with missing title" do
      incomplete_pr = Issue.create!(
        repository: @repository,
        host: @host,
        user: "dependabot[bot]",
        title: nil,
        body: "Test body",
        node_id: "test-node-id",
        number: 300,
        state: "open",
        pull_request: true,
        uuid: "test-uuid-no-title"
      )

      assert_includes Issue.incomplete_prs, incomplete_pr
    end

    should "find PRs with missing body" do
      incomplete_pr = Issue.create!(
        repository: @repository,
        host: @host,
        user: "dependabot[bot]",
        title: "Test title",
        body: nil,
        node_id: "test-node-id",
        number: 301,
        state: "open",
        pull_request: true,
        uuid: "test-uuid-no-body"
      )

      assert_includes Issue.incomplete_prs, incomplete_pr
    end

    should "find PRs with missing node_id" do
      incomplete_pr = Issue.create!(
        repository: @repository,
        host: @host,
        user: "dependabot[bot]",
        title: "Test title",
        body: "Test body",
        node_id: nil,
        number: 302,
        state: "open",
        pull_request: true,
        uuid: "test-uuid-no-node-id"
      )

      assert_includes Issue.incomplete_prs, incomplete_pr
    end

    should "not include complete PRs" do
      complete_pr = Issue.create!(
        repository: @repository,
        host: @host,
        user: "dependabot[bot]",
        title: "Test title",
        body: "Test body",
        node_id: "test-node-id",
        number: 303,
        state: "open",
        pull_request: true,
        uuid: "test-uuid-complete"
      )

      assert_not_includes Issue.incomplete_prs, complete_pr
    end

    should "only include dependabot PRs" do
      incomplete_pr = Issue.create!(
        repository: @repository,
        host: @host,
        user: "regular-user",
        title: nil,
        number: 304,
        state: "open",
        pull_request: true,
        uuid: "test-uuid-regular-user"
      )

      assert_not_includes Issue.incomplete_prs, incomplete_pr
    end

    should "only include pull requests" do
      incomplete_issue = Issue.create!(
        repository: @repository,
        host: @host,
        user: "dependabot[bot]",
        title: nil,
        number: 305,
        state: "open",
        pull_request: false,
        uuid: "test-uuid-issue"
      )

      assert_not_includes Issue.incomplete_prs, incomplete_issue
    end
  end

  context 'enrich_from_github_api' do
    should "enrich incomplete PR with API data" do
      incomplete_pr = Issue.create!(
        repository: @repository,
        host: @host,
        user: "dependabot[bot]",
        title: nil,
        body: nil,
        node_id: nil,
        number: 400,
        state: "open",
        pull_request: true,
        uuid: "test-uuid-enrich"
      )

      # Mock the Octokit client
      mock_pr_data = OpenStruct.new(
        node_id: "PR_node_id_123",
        title: "Bump rack from 2.2.16 to 2.2.17",
        body: "Updates rack to fix security vulnerability",
        state: "open",
        locked: false,
        comments: 5,
        labels: [OpenStruct.new(name: "dependencies")],
        assignees: [],
        author_association: "CONTRIBUTOR",
        state_reason: nil,
        merged_at: nil,
        merged_by: nil,
        closed_by: nil,
        draft: false,
        mergeable: true,
        mergeable_state: "clean",
        rebaseable: true,
        review_comments: 0,
        commits: 1,
        additions: 2,
        deletions: 1,
        changed_files: 1
      )

      mock_client = mock('octokit_client')
      mock_client.expects(:pull_request).with(@repository.full_name, 400).returns(mock_pr_data)

      mock_github_instance = mock('github_host_instance')
      mock_github_instance.stubs(:send).with(:api_client).returns(mock_client)

      incomplete_pr.host.stubs(:host_instance).returns(mock_github_instance)

      assert incomplete_pr.enrich_from_github_api

      incomplete_pr.reload
      assert_equal "PR_node_id_123", incomplete_pr.node_id
      assert_equal "Bump rack from 2.2.16 to 2.2.17", incomplete_pr.title
      assert_equal "Updates rack to fix security vulnerability", incomplete_pr.body
      assert_equal 5, incomplete_pr.comments_count
    end

    should "handle API errors gracefully" do
      incomplete_pr = Issue.create!(
        repository: @repository,
        host: @host,
        user: "dependabot[bot]",
        title: nil,
        number: 401,
        state: "open",
        pull_request: true,
        uuid: "test-uuid-enrich-error"
      )

      mock_client = mock('octokit_client')
      mock_client.expects(:pull_request).raises(Octokit::NotFound)

      mock_github_instance = mock('github_host_instance')
      mock_github_instance.stubs(:send).with(:api_client).returns(mock_client)

      incomplete_pr.host.stubs(:host_instance).returns(mock_github_instance)

      assert_equal false, incomplete_pr.enrich_from_github_api
    end

    should "handle unauthorized errors gracefully" do
      incomplete_pr = Issue.create!(
        repository: @repository,
        host: @host,
        user: "dependabot[bot]",
        title: nil,
        number: 402,
        state: "open",
        pull_request: true,
        uuid: "test-uuid-enrich-unauthorized"
      )

      mock_client = mock('octokit_client')
      mock_client.expects(:pull_request).raises(Octokit::Unauthorized)

      mock_github_instance = mock('github_host_instance')
      mock_github_instance.stubs(:send).with(:api_client).returns(mock_client)

      incomplete_pr.host.stubs(:host_instance).returns(mock_github_instance)

      assert_equal false, incomplete_pr.enrich_from_github_api
    end
  end
end
