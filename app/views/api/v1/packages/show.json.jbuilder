json.partial! 'api/v1/packages/package', package: @package

json.recent_issues do
  json.array! @package.issues.includes(:repository, :host).order(created_at: :desc).limit(20) do |issue|
    json.partial! 'api/v1/issues/issue', issue: issue
  end
end

json.issue_packages do
  json.array! @package.issue_packages.includes(:issue).order(pr_created_at: :desc).limit(20) do |issue_package|
    json.extract! issue_package, :old_version, :new_version, :update_type, :path, :pr_created_at
    json.version_change issue_package.version_change
    json.issue do
      json.partial! 'api/v1/issues/issue', issue: issue_package.issue
    end
  end
end