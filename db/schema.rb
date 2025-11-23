# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_06_11_145948) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_stat_statements"
  enable_extension "pgcrypto"

  create_table "advisories", force: :cascade do |t|
    t.float "blast_radius"
    t.string "classification"
    t.datetime "created_at", null: false
    t.float "cvss_score"
    t.string "cvss_vector"
    t.text "description"
    t.float "epss_percentage"
    t.float "epss_percentile"
    t.jsonb "identifiers", default: []
    t.integer "issues_count", default: 0, null: false
    t.decimal "merge_rate", precision: 5, scale: 2, default: "0.0"
    t.string "origin"
    t.jsonb "packages", default: []
    t.datetime "published_at"
    t.jsonb "references", default: []
    t.string "repository_url"
    t.string "severity"
    t.string "source_kind"
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url"
    t.string "uuid", null: false
    t.datetime "withdrawn_at"
    t.index ["identifiers"], name: "index_advisories_on_identifiers", using: :gin
    t.index ["issues_count"], name: "index_advisories_on_issues_count"
    t.index ["merge_rate"], name: "index_advisories_on_merge_rate"
    t.index ["published_at"], name: "index_advisories_on_published_at"
    t.index ["repository_url"], name: "index_advisories_on_repository_url"
    t.index ["severity"], name: "index_advisories_on_severity"
    t.index ["uuid"], name: "index_advisories_on_uuid", unique: true
  end

  create_table "exports", force: :cascade do |t|
    t.string "bucket_name"
    t.datetime "created_at", null: false
    t.string "date"
    t.integer "issues_count"
    t.datetime "updated_at", null: false
  end

  create_table "hosts", force: :cascade do |t|
    t.integer "authors_count"
    t.datetime "created_at", null: false
    t.string "icon_url"
    t.integer "issues_count"
    t.string "kind"
    t.datetime "last_synced_at"
    t.string "name"
    t.integer "pull_requests_count"
    t.integer "repositories_count"
    t.datetime "updated_at", null: false
    t.string "url"
  end

  create_table "imports", force: :cascade do |t|
    t.integer "comment_count"
    t.datetime "created_at", null: false
    t.integer "created_count"
    t.integer "dependabot_count"
    t.text "error_message"
    t.string "filename"
    t.datetime "imported_at"
    t.integer "pr_count"
    t.integer "review_comment_count"
    t.integer "review_count"
    t.integer "review_thread_count"
    t.boolean "success"
    t.datetime "updated_at", null: false
    t.integer "updated_count"
  end

  create_table "issue_advisories", force: :cascade do |t|
    t.bigint "advisory_id", null: false
    t.datetime "created_at", null: false
    t.bigint "issue_id", null: false
    t.datetime "updated_at", null: false
    t.index ["advisory_id"], name: "index_issue_advisories_on_advisory_id"
    t.index ["created_at"], name: "index_issue_advisories_on_created_at"
    t.index ["issue_id", "advisory_id"], name: "index_issue_advisories_on_issue_id_and_advisory_id", unique: true
  end

  create_table "issue_packages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "issue_id", null: false
    t.string "new_version"
    t.string "old_version"
    t.bigint "package_id", null: false
    t.string "path"
    t.datetime "pr_created_at"
    t.string "update_type"
    t.datetime "updated_at", null: false
    t.index ["issue_id", "package_id"], name: "index_issue_packages_on_issue_id_and_package_id", unique: true
    t.index ["package_id"], name: "index_issue_packages_on_package_id"
    t.index ["pr_created_at"], name: "index_issue_packages_on_pr_created_at"
  end

  create_table "issues", force: :cascade do |t|
    t.integer "additions"
    t.string "assignees", default: [], array: true
    t.string "author_association"
    t.text "body"
    t.integer "changed_files"
    t.datetime "closed_at"
    t.string "closed_by"
    t.integer "comments_count"
    t.integer "commits_count"
    t.datetime "created_at", null: false
    t.integer "deletions"
    t.json "dependency_metadata"
    t.boolean "draft"
    t.integer "host_id"
    t.string "labels", default: [], array: true
    t.boolean "locked"
    t.boolean "mergeable"
    t.string "mergeable_state"
    t.datetime "merged_at"
    t.string "merged_by"
    t.string "node_id"
    t.integer "number"
    t.boolean "pull_request"
    t.boolean "rebaseable"
    t.integer "repository_id"
    t.integer "review_comments_count"
    t.string "state"
    t.string "state_reason"
    t.integer "time_to_close"
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "user"
    t.string "uuid"
    t.index ["created_at"], name: "index_issues_on_created_at"
    t.index ["host_id", "user"], name: "index_issues_on_host_id_and_user"
    t.index ["repository_id", "number"], name: "index_issues_on_repository_id_and_number_unique", unique: true
    t.index ["uuid"], name: "index_issues_on_uuid", unique: true
  end

  create_table "jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip"
    t.json "results"
    t.string "sidekiq_id"
    t.string "status"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["status"], name: "index_jobs_on_status"
  end

  create_table "packages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ecosystem", null: false
    t.integer "issues_count", default: 0, null: false
    t.json "metadata", default: {}
    t.string "name", null: false
    t.string "repository_url"
    t.integer "unique_repositories_count", default: 0
    t.integer "unique_repositories_count_past_30_days", default: 0
    t.datetime "updated_at", null: false
    t.index "lower((repository_url)::text)", name: "index_packages_on_lower_repository_url"
    t.index ["ecosystem", "name"], name: "index_packages_on_ecosystem_and_name", unique: true
    t.index ["issues_count"], name: "index_packages_on_issues_count"
    t.index ["unique_repositories_count"], name: "index_packages_on_unique_repositories_count"
    t.index ["unique_repositories_count_past_30_days"], name: "index_packages_on_unique_repositories_count_past_30_days"
  end

  create_table "repositories", force: :cascade do |t|
    t.boolean "archived", default: false, null: false
    t.float "avg_comments_per_issue"
    t.float "avg_comments_per_pull_request"
    t.float "avg_time_to_close_issue"
    t.float "avg_time_to_close_pull_request"
    t.integer "bot_issues_count"
    t.integer "bot_pull_requests_count"
    t.datetime "created_at", null: false
    t.string "default_branch"
    t.boolean "fork", default: false, null: false
    t.string "full_name"
    t.integer "host_id"
    t.integer "issue_authors_count"
    t.integer "issues_closed_count"
    t.integer "issues_count"
    t.datetime "last_synced_at"
    t.integer "merged_pull_requests_count"
    t.json "metadata", default: {}
    t.string "owner"
    t.float "past_year_avg_comments_per_issue"
    t.float "past_year_avg_comments_per_pull_request"
    t.float "past_year_avg_time_to_close_issue"
    t.float "past_year_avg_time_to_close_pull_request"
    t.integer "past_year_bot_issues_count"
    t.integer "past_year_bot_pull_requests_count"
    t.integer "past_year_issue_authors_count"
    t.integer "past_year_issues_closed_count"
    t.integer "past_year_issues_count"
    t.integer "past_year_merged_pull_requests_count"
    t.integer "past_year_pull_request_authors_count"
    t.integer "past_year_pull_requests_closed_count"
    t.integer "past_year_pull_requests_count"
    t.integer "pull_request_authors_count"
    t.integer "pull_requests_closed_count"
    t.integer "pull_requests_count"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index "host_id, lower((full_name)::text)", name: "index_repositories_on_host_id_lower_full_name", unique: true
    t.index ["archived"], name: "index_repositories_on_archived"
    t.index ["fork"], name: "index_repositories_on_fork"
    t.index ["owner"], name: "index_repositories_on_owner"
  end

  add_foreign_key "issue_advisories", "advisories"
  add_foreign_key "issue_advisories", "issues"
  add_foreign_key "issue_packages", "issues"
  add_foreign_key "issue_packages", "packages"
end
