json.extract! issue, :uuid, :node_id, :number, :state, :title, :user, :labels, :assignees, :locked, :comments_count, :pull_request, :closed_at, :author_association, :state_reason, :created_at, :updated_at, :time_to_close, :merged_at, :merged_by, :closed_by, :dependency_metadata, :body
json.html_url issue.html_url
json.url api_v1_host_repository_issue_url(issue.repository.host, issue.repository, issue)
json.packages_url api_v1_issue_packages_url(issue)