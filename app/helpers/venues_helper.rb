# frozen_string_literal: true

# 会場ページの地図表示（issue #1781）。APIキー不要のGoogleマップ埋め込みURLを組み立てる
module VenuesHelper
  def google_maps_embed_url(query)
    "https://www.google.com/maps?#{URI.encode_www_form(q: query, output: 'embed')}"
  end
end
