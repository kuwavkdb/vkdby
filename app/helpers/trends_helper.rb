# frozen_string_literal: true

module TrendsHelper
  # Trend#units / Trend#people の jsonb に保存されたスナップショット時点の名前を優先し、
  # 無ければ現在の Unit / Person の名前にフォールバックする
  def trend_unit_display_name(unit_data, unit)
    unit_data['name'].presence || unit&.name
  end

  def trend_person_display_name(person_data, person)
    person_data['name'].presence || person&.name
  end

  def twitter_url?(url)
    return false if url.blank?

    url.match?(%r{^https?://(?:www\.)?(?:twitter\.com|x\.com)/[^/]+/status/\d+})
  end

  def twitter_embed(_url, quote)
    html = <<~HTML
      #{quote}
      <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>
    HTML
    html.html_safe
  end

  # Sanitize URL to prevent XSS attacks
  # Only allow http:// and https:// schemes
  def safe_url(url)
    return nil if url.blank?

    url_string = url.to_s
    url_string.start_with?('http://', 'https://') ? url_string : nil
  end
end
