json.login @owner

json.maintainers @maintainers do |maintainer, count|
  json.maintainer maintainer
  json.count count
end
json.active_maintainers @active_maintainers do |maintainer, count|
  json.maintainer maintainer
  json.count count
end