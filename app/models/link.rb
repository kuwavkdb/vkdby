# frozen_string_literal: true

# == Schema Information
#
# Table name: links
#
#  id            :bigint           not null, primary key
#  active        :boolean          default(TRUE)
#  linkable_type :string           not null
#  sort_order    :integer
#  text          :string
#  url           :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  linkable_id   :bigint           not null
#
# Indexes
#
#  index_links_on_linkable  (linkable_type,linkable_id)
#
class Link < ApplicationRecord
  # X(Twitter) の個別ツイートURL（twitter.com / x.com どちらも対象）
  TWITTER_STATUS_URL_PATTERN = %r{^https?://(?:www\.)?(?:twitter\.com|x\.com)/[^/]+/status/\d+}

  # hrefにそのまま入るため、javascript: などのスキームを保存させない（issue #1707）
  HTTP_URL_PATTERN = %r{\Ahttps?://.+\z}i

  belongs_to :linkable, polymorphic: true

  validates :url, presence: true
  validates :url, format: { with: HTTP_URL_PATTERN, message: 'は http:// または https:// で始まるURLを入力してください' },
                  allow_blank: true

  # 同じページを指すURLかを比べるための正規化（issue #1654）。スキーム・www/mobile/m・末尾スラッシュ・
  # フラグメント・大文字小文字の違いを無視し、twitter.com は x.com とみなす。
  def self.comparable_url(url)
    url.to_s.strip.downcase
       .sub(%r{\Ahttps?://}, '')
       .sub(/\A(?:www|mobile|m)\./, '')
       .sub(%r{\Atwitter\.com(?=[/?]|\z)}, 'x.com')
       .sub(/#.*\z/, '')
       .sub(%r{/+\z}, '')
  end

  def twitter_status_url?
    url.present? && url.match?(TWITTER_STATUS_URL_PATTERN)
  end

  def youtube_video_id
    return nil unless url.present?

    # Regular expression to extract YouTube video ID
    # Handles watch?v=, youtu.be/, embed/, etc.
    return unless url =~ %r{(?:youtube\.com/(?:[^/]+/.+/|(?:v|e(?:mbed)?)/|.*[?&]v=)|youtu\.be/)([^"&?/\s]{11})}

    ::Regexp.last_match(1)
  end

  def sns_info
    return nil unless url.present?

    case url
    when %r{twitter\.com/([^/?]+)}, %r{x\.com/([^/?]+)}
      { platform: 'Twitter', account: "@#{decode_account(::Regexp.last_match(1))}" }
    when %r{instagram\.com/([^/?]+)}
      { platform: 'Instagram', account: decode_account(::Regexp.last_match(1)) }
    when %r{youtube\.com/@([^/?]+)}, %r{youtube\.com/c/([^/?]+)}
      { platform: 'YouTube', account: decode_account(::Regexp.last_match(1)) }
    when %r{tiktok\.com/@([^/?]+)}
      { platform: 'TikTok', account: "@#{decode_account(::Regexp.last_match(1))}" }
    when %r{open\.spotify\.com/(?:intl-[a-zA-Z-]+/)?artist/([a-zA-Z0-9]+)}
      { platform: 'Spotify', account: ::Regexp.last_match(1) }
    end
  end

  def display_text
    base = text.presence || sns_info&.[](:platform) || url
    info = sns_info
    info ? "#{base} (#{info[:account]})" : base
  end

  def domain
    URI.parse(url).host || url
  rescue URI::InvalidURIError
    url
  end

  private

  # URL から取り出したアカウント名を、表示用に元の文字へ戻す（issue #2141）。
  # 日本語のチャンネル名などは %E3%83%8D... のように符号化されて保存されているため、そのままだと読めない。
  # URI.decode_uri_component は CGI.unescape と違い「+」を空白に変えない。戻した結果が正しい UTF-8 で
  # なければ（符号化の誤りなど）、元の文字のまま返す
  def decode_account(account)
    decoded = URI.decode_uri_component(account).force_encoding(Encoding::UTF_8)
    decoded.valid_encoding? ? decoded : account
  rescue ArgumentError
    account
  end
end
