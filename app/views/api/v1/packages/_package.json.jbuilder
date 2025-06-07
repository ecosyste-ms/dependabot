json.extract! package, :id, :name, :ecosystem, :repository_url, :issues_count, :created_at, :updated_at
json.purl package.purl
json.metadata package.metadata if package.metadata.present?