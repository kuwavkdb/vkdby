# frozen_string_literal: true

module Middleware
  class IpBlocker
    CUSTOM_PAGE_KEY = 'blocking_ip_address'
    CACHE_KEY = 'middleware/blocked_ips'
    CACHE_TTL = 5.minutes

    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)
      return [403, { 'Content-Type' => 'text/plain' }, ['Forbidden']] if blocked?(request.ip)

      @app.call(env)
    end

    private

    def blocked?(ip)
      return false if ip.blank?

      load_blocked_ips.include?(ip)
    end

    def load_blocked_ips
      Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) { fetch_blocked_ips }
    end

    def fetch_blocked_ips
      page = CustomPage.kept.find_by(key: CUSTOM_PAGE_KEY)
      return [] unless page&.body.present?

      parse_blocked_ips(page.body)
    rescue StandardError
      [] # DB unavailable などの場合はブロックしない
    end

    def parse_blocked_ips(body)
      body.lines.filter_map do |line|
        line = line.strip
        next if line.empty?
        next if line.match?(/\A~~.+~~\z/) # 取り消し線付きはブロック対象外

        line
      end
    end
  end
end
