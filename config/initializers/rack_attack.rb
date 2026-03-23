# frozen_string_literal: true

Rack::Attack.throttle("search/ip", limit: 30, period: 60) do |req|
  req.ip if req.path.start_with?("/people/search", "/units/search")
end
