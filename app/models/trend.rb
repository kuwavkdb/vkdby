# frozen_string_literal: true

# == Schema Information
#
# Table name: trends
#
#  id                :bigint           not null, primary key
#  active            :boolean          default(TRUE), not null
#  content           :text
#  date              :date             not null
#  day_unknown       :boolean          default(FALSE), not null
#  etc_phenomenon    :integer
#  month_unknown     :boolean          default(FALSE), not null
#  people            :jsonb
#  person_phenomenon :integer
#  publish_start_at  :datetime         not null
#  quote             :text
#  quote_title       :string
#  quote_url         :string
#  title             :string
#  unit_phenomenon   :integer
#  units             :jsonb
#  via_name          :string
#  via_url           :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  old_trend_id      :integer
#  old_wiki_id       :integer
#
# Indexes
#
#  index_trends_on_date    (date)
#  index_trends_on_people  (people) USING gin
#  index_trends_on_units   (units) USING gin
#
class Trend < ApplicationRecord
  include OgpImageAttachable

  # Enums
  enum :unit_phenomenon, {
    announcement: 1,
    formation: 2,
    first_live: 3,
    finish: 4,
    pending: 5,
    rename: 6,
    suspend: 7,
    restart: 8,
    limited: 9,
    major_debut: 10,
    live: 11,
    media: 12,
    #    etc: 98,
    unknown: 99,
    other: 100
  }, prefix: true

  enum :person_phenomenon, {
    original_member: 0,
    join_member: 1,
    leave_member: 2,
    suspend_member: 3,
    rename_member: 4,
    convert: 5,
    stay: 6,
    dismissal: 7,
    rejoin: 8,
    retirement: 90,
    passed_away: 98,
    unknown: 99,
    other: 100
  }, prefix: true

  enum :etc_phenomenon, {
    unknown: 99,
    other: 100
  }, prefix: true

  # Scopes
  scope :on_date, ->(date) { where(date: date) }
  scope :on_month_day, lambda { |month, day|
    where('EXTRACT(MONTH FROM date) = ? AND EXTRACT(DAY FROM date) = ?', month, day)
  }

  # Validations
  validates :date, presence: true
  validates :active, inclusion: { in: [true, false] }
  validates :publish_start_at, presence: true
  validate :must_have_at_least_one_phenomenon

  # タイトル末尾の半角括弧書き（会場名等の補足）にマッチする正規表現。
  # ページ<title>/og:title/twitter:title（trends_helper#trend_title_without_trailing_parenthetical）と
  # OGP画像合成テキスト（下記ogp_image_attachable_text）の両方から参照する（issue #1319）
  TITLE_TRAILING_PARENTHETICAL_PATTERN = /\s*\([^()]*\)\z/

  # タイトルに含まれるWiki記法のブラケットをプレーンテキストに置き換える（[表示], [表示|URL]）。
  # WikiLinkHelper#parse_wiki_linksのうちリンク化しないケース（link: false）と同じ変換だが、
  # ActionViewに依存せずModel単体で完結させるため簡略な正規表現で再実装している（issue #1319）
  WIKI_BRACKET_PATTERNS = [
    [/\[\[([^\[\]|]+)\|([^\[\]]+)\]\]/, '\1'], # [[表示|リンク先]] -> 表示
    [/\[\[([^\[\]|]+)\]\]/, '\1'],             # [[リンク先]] -> リンク先
    [%r{\[(.*?)\|(https?://.*?)\]}, '\1']      # [表示|URL] -> 表示
  ].freeze

  # タイトルからWiki記法のブラケットを取り除いたプレーンテキスト
  def title_as_plain_text
    WIKI_BRACKET_PATTERNS.reduce(title.to_s) { |text, (pattern, replacement)| text.gsub(pattern, replacement) }
  end

  # 上記からさらに末尾の半角括弧書きを取り除いたもの
  def title_without_trailing_parenthetical
    title_as_plain_text.sub(TITLE_TRAILING_PARENTHETICAL_PATTERN, '')
  end

  # Trend詳細ページのヘッダ・ページ<title>・OGP画像で共通して使う日付ラベル。
  # month_unknown/day_unknownに応じて年 → 年月 → 年月日の粒度で表示する（issue #1313, #1319）
  def date_label
    if month_unknown?
      date.strftime('%Y')
    elsif day_unknown?
      date.strftime('%Y/%m')
    else
      date.strftime('%Y/%m/%d')
    end
  end

  private

  def must_have_at_least_one_phenomenon
    return if unit_phenomenon.present? || person_phenomenon.present? || etc_phenomenon.present?

    errors.add(:base, 'At least one phenomenon (unit, person, or etc) must be present')
  end

  # OgpImageAttachable用: `name`カラムを持たないため、unitsのスナップショット名（jsonb）＋
  # タイトル＋日付を合成してバナーテキストにする（issue #1319）。related Unitへの問い合わせは
  # 発生させず、trend自身が保持しているスナップショット名のみを使う。個人名は含めない。
  # ユニット名 → タイトル → 日付の3行構成にする
  def ogp_image_attachable_text
    unit_names = (units || []).filter_map { |u| u['name'].presence }.join(' ').presence

    [unit_names, title_without_trailing_parenthetical.presence, date_label].compact_blank.join("\n")
  end

  # ogp_image_attachable_textが依存する属性（ユニット名/タイトル/日付）の変更のみを対象にする。
  # ActiveStorage::Attachmentはattach/purgeのたびにrecord（Trend）をtouchする仕様のため、
  # ここを無条件trueにするとattach→touch→after_update_commit→purge→touch→…の無限再帰で
  # SystemStackErrorになる（実際に発生させて確認済み）。依存属性を追加した際はここも合わせて
  # 追従させること
  def ogp_image_attachable_text_changed?
    saved_change_to_title? || saved_change_to_units? ||
      saved_change_to_date? || saved_change_to_month_unknown? || saved_change_to_day_unknown?
  end
end
