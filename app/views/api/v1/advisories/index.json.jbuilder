json.array! @advisories do |advisory|
  json.partial! 'api/v1/advisories/advisory', advisory: advisory
end