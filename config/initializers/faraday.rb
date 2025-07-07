require 'faraday'

Faraday.default_adapter = :net_http

Faraday.default_connection_options = {
  headers: {
    'User-Agent' => 'dependabot.ecosyste.ms'
  }
}