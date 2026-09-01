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

  # タイトルから末尾の半角括弧書きを取り除いたもの
  def title_without_trailing_parenthetical
    title.to_s.sub(TITLE_TRAILING_PARENTHETICAL_PATTERN, '')
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

  # OgpImageAttachable用: `name`カラムを持たないため、units/peopleのスナップショット名（jsonb）＋
  # タイトル＋日付を合成してバナーテキストにする（issue #1319）。related Unit/Personへの問い合わせは
  # 発生させず、trend自身が保持しているスナップショット名のみを使う。
  # ユニット名はunit_phenomenonが、個人名はperson_phenomenonが設定されている場合のみ含める
  # （両方設定されている場合のみ併記する）。アーティスト名 → タイトル → 日付の3行構成にする
  def ogp_image_attachable_text
    unit_names = unit_phenomenon.present? ? (units || []).filter_map { |u| u['name'].presence } : []
    person_names = person_phenomenon.present? ? (people || []).filter_map { |p| p['name'].presence } : []
    artist_names = (unit_names + person_names).join(' ').presence

    [artist_names, title_without_trailing_parenthetical.presence, date_label].compact_blank.join("\n")
  end

  def ogp_image_attachable_text_changed?
    saved_change_to_title? || saved_change_to_units? || saved_change_to_people? ||
      saved_change_to_unit_phenomenon? || saved_change_to_person_phenomenon? ||
      saved_change_to_date? || saved_change_to_month_unknown? || saved_change_to_day_unknown?
  end
end
