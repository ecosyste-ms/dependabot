json.issue_packages do
  json.array! @issue_packages do |issue_package|
    json.extract! issue_package, :old_version, :new_version, :update_type, :path, :pr_created_at
    json.version_change issue_package.version_change
    json.package do
      json.partial! 'api/v1/packages/package', package: issue_package.package
    end
  end
end