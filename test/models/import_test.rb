require "test_helper"

class ImportTest < ActiveSupport::TestCase
  setup do
    @host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
  end

  test "sanitize_string removes null bytes" do
    # Test the private method through a helper
    assert_equal "helloworld", Import.send(:sanitize_string, "hello\0world")
    assert_equal "teststring", Import.send(:sanitize_string, "test\0\0string")
    assert_nil Import.send(:sanitize_string, nil)
    assert_equal "", Import.send(:sanitize_string, "")
    assert_equal "normal", Import.send(:sanitize_string, "normal")
  end

  test "only processes dependabot PRs and ignores regular user PRs" do
    # Create test data with both dependabot and regular user PRs
    test_data = [
      {
        "type" => "PullRequestEvent",
        "repo" => { "name" => "test/repo" },
        "payload" => {
          "action" => "opened",
          "pull_request" => {
            "id" => 123456,
            "number" => 1,
            "title" => "Bump package from 1.0 to 2.0",
            "body" => "Updates package",
            "state" => "open",
            "user" => { "login" => "dependabot[bot]" },
            "created_at" => "2023-01-01T00:00:00Z",
            "updated_at" => "2023-01-01T00:00:00Z",
            "closed_at" => nil,
            "merged_at" => nil,
            "labels" => [],
            "assignees" => [],
            "author_association" => "CONTRIBUTOR",
            "locked" => false,
            "comments" => 0,
            "review_comments" => 0,
            "commits" => 1,
            "additions" => 10,
            "deletions" => 5,
            "changed_files" => 1
          }
        }
      },
      {
        "type" => "PullRequestEvent",
        "repo" => { "name" => "test/repo" },
        "payload" => {
          "action" => "opened",
          "pull_request" => {
            "id" => 123457,
            "number" => 2,
            "title" => "Fix bug in component",
            "body" => "This fixes a bug",
            "state" => "open",
            "user" => { "login" => "regular-user" },
            "created_at" => "2023-01-01T00:00:00Z",
            "updated_at" => "2023-01-01T00:00:00Z",
            "closed_at" => nil,
            "merged_at" => nil,
            "labels" => [],
            "assignees" => [],
            "author_association" => "CONTRIBUTOR",
            "locked" => false,
            "comments" => 0,
            "review_comments" => 0,
            "commits" => 1,
            "additions" => 5,
            "deletions" => 2,
            "changed_files" => 1
          }
        }
      }
    ].map(&:to_json).join("\n")

    initial_issue_count = Issue.count
    stats = Import.send(:process_gharchive_data, test_data)
    
    # Should only count the dependabot PR
    assert_equal 1, stats[:dependabot_count]
    assert_equal 1, stats[:pr_count]
    assert_equal 1, stats[:created_count]
    
    # Should only create one issue (the dependabot one)
    assert_equal initial_issue_count + 1, Issue.count
    created_issue = Issue.where(uuid: 123456).first
    assert_not_nil created_issue
    assert_equal "dependabot[bot]", created_issue.user
    assert_equal "Bump package from 1.0 to 2.0", created_issue.title
    
    # Should not create the regular user issue
    regular_issue = Issue.where(uuid: 123457).first
    assert_nil regular_issue
  end

  test "processes different dependabot user variations" do
    # Test different dependabot user formats
    test_data = [
      {
        "type" => "PullRequestEvent",
        "repo" => { "name" => "test/repo" },
        "payload" => {
          "action" => "opened",
          "pull_request" => {
            "id" => 123458,
            "number" => 3,
            "title" => "Bump package1",
            "body" => "Updates package1",
            "state" => "open",
            "user" => { "login" => "dependabot[bot]" },
            "created_at" => "2023-01-01T00:00:00Z",
            "updated_at" => "2023-01-01T00:00:00Z",
            "closed_at" => nil,
            "merged_at" => nil,
            "labels" => [],
            "assignees" => [],
            "author_association" => "CONTRIBUTOR",
            "locked" => false,
            "comments" => 0,
            "review_comments" => 0,
            "commits" => 1,
            "additions" => 1,
            "deletions" => 1,
            "changed_files" => 1
          }
        }
      },
      {
        "type" => "PullRequestEvent",
        "repo" => { "name" => "test/repo" },
        "payload" => {
          "action" => "opened",
          "pull_request" => {
            "id" => 123459,
            "number" => 4,
            "title" => "Bump package2",
            "body" => "Updates package2",
            "state" => "open",
            "user" => { "login" => "dependabot-preview[bot]" },
            "created_at" => "2023-01-01T00:00:00Z",
            "updated_at" => "2023-01-01T00:00:00Z",
            "closed_at" => nil,
            "merged_at" => nil,
            "labels" => [],
            "assignees" => [],
            "author_association" => "CONTRIBUTOR",
            "locked" => false,
            "comments" => 0,
            "review_comments" => 0,
            "commits" => 1,
            "additions" => 1,
            "deletions" => 1,
            "changed_files" => 1
          }
        }
      }
    ].map(&:to_json).join("\n")

    initial_issue_count = Issue.count
    stats = Import.send(:process_gharchive_data, test_data)
    
    # Should count both dependabot PRs
    assert_equal 2, stats[:dependabot_count]
    assert_equal 2, stats[:pr_count]
    assert_equal 2, stats[:created_count]
    
    # Should create both issues
    assert_equal initial_issue_count + 2, Issue.count
  end
end
