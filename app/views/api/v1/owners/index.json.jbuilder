json.array! @owners.reject { |owner, _| @hidden_owners.include?(owner) } do |owner, count|
  json.login owner
  json.repositories_count count
  json.owner_url api_v1_host_owner_url(@host, owner)
end