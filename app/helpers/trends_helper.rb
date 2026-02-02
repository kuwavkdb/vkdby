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
end
