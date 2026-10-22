# frozen_string_literal: true

# == Schema Information
#
# Table name: external_sites
#
#  id          :bigint           not null, primary key
#  name        :string
#  site_key    :string           not null
#  url_pattern :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_external_sites_on_site_key  (site_key) UNIQUE
#
class ExternalSite < ApplicationRecord
  # 外部サイトに登録しなくてもリンク欄でタイトルを補完できるサービスの対応表。
  # link_title_suggest_controller.js に渡して照合に使い、外部サイトの一覧画面にも表示する。
  # rules は上から順に照合し、path（Ruby・JavaScript の両方で使える正規表現の文字列）があれば URL のパスにも一致したときだけ使う。
  # 外部サイトに登録した表示名のほうを先に照合する
  BUILTIN_LINK_TITLES = [
    { service: 'X', rules: [
      { hosts: %w[x.com twitter.com], path: '^/[^/]+/status/\d+', title: 'X Post' },
      { hosts: %w[x.com twitter.com], title: 'X' }
    ] },
    { service: 'Spotify', rules: [{ hosts: %w[open.spotify.com], title: 'Spotify' }] },
    { service: 'YouTube', rules: [
      { hosts: %w[youtube.com m.youtube.com], path: '^/(?:watch|shorts/)', title: 'YouTube Movie' },
      { hosts: %w[youtube.com m.youtube.com], path: '^/(?:@|channel/|c/|user/)', title: 'YouTube Channel' },
      { hosts: %w[youtube.com m.youtube.com], title: 'YouTube' },
      { hosts: %w[youtu.be], title: 'YouTube Movie' }
    ] },
    { service: 'Instagram', rules: [{ hosts: %w[instagram.com], title: 'Instagram' }] },
    { service: 'TikTok', rules: [{ hosts: %w[tiktok.com], title: 'TikTok' }] },
    { service: 'Facebook', rules: [{ hosts: %w[facebook.com fb.com], title: 'Facebook' }] },
    { service: 'niconico', rules: [{ hosts: %w[nicovideo.jp], title: 'niconico' }] }
  ].freeze

  validates :site_key, presence: true, uniqueness: true
  validates :url_pattern, presence: true
  validates :url_pattern, format: { with: /\A.*\{account\}.*\z/, message: 'must contain {account} placeholder' }

  # リンク欄のタイトル補完（link_title_suggest_controller.js）に渡す、表示名と URL パターンの一覧
  def self.link_title_suggestions
    where.not(name: [nil, '']).order(:site_key).map { |site| { name: site.name, url_pattern: site.url_pattern } }
  end
end
