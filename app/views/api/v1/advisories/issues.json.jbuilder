json.array! @issues do |issue|
  json.partial! 'api/v1/issues/issue', issue: issue
end