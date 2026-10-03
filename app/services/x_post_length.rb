# frozen_string_literal: true

# X（Twitter）の投稿文字数（重み付き）を数える（issue #1742）。
# twitter-text v3 の設定に合わせ、Latin・一部の記号は1、それ以外（日本語の全角文字など）は2、
# URL は長さによらず23として数える。上限は280。
# 絵文字のZWJシーケンス等はX側では1つ（2）と数えるが、ここでは構成文字ごとに数えるため多めに出る。
# 多めに出る分には上限を超えないので、投稿文の組み立てでは問題にならない
module XPostLength
  MAX = 280
  URL_LENGTH = 23
  URL_PATTERN = %r{https?://\S+}
  # 重み1として数えるコードポイントの範囲（それ以外は重み2）
  LIGHT_RANGES = [0..4351, 8192..8205, 8208..8223, 8242..8247].freeze

  module_function

  def count(text)
    normalized = text.to_s.unicode_normalize(:nfc)
    url_count = normalized.scan(URL_PATTERN).size
    rest = normalized.gsub(URL_PATTERN, '')
    (url_count * URL_LENGTH) + rest.each_codepoint.sum { |cp| weight(cp) }
  end

  def fits?(text)
    count(text) <= MAX
  end

  def weight(codepoint)
    LIGHT_RANGES.any? { |range| range.cover?(codepoint) } ? 1 : 2
  end
end
