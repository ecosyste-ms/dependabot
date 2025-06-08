json.extract! package, :id, :name, :ecosystem, :repository_url, :issues_count, :created_at, :updated_at
json.purl package.purl
json.metadata package.metadata if package.metadata.present?
json.unique_repositories_count package.unique_repositories_count
json.unique_repositories_count_past_30_days package.unique_repositories_count_past_30_days