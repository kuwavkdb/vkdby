# frozen_string_literal: true

module TrendsHelper
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
