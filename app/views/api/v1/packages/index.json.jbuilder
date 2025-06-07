json.packages do
  json.array! @packages, partial: 'api/v1/packages/package', as: :package
end