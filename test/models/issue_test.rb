require "test_helper"

class IssueTest < ActiveSupport::TestCase
  setup do
    @host = Host.create!(
      name: "github.com",
      url: "https://github.com",
      kind: "github"
    )
    @repository = Repository.create!(
      host: @host,
      full_name: "owner/repo",
      owner: "owner"
    )
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

  test "returns nil for non-dependabot users" do
    issue = Issue.new(
      repository: @repository,
      host: @host,
      user: "human-user",
      title: "Bump rack from 2.2.16 to 2.2.17",
      number: 1,
      state: "open"
    )
    
    metadata = issue.parse_dependabot_metadata
    assert_nil metadata
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
end
