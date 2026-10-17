# frozen_string_literal: true

# == Schema Information
#
# Table name: units
#
#  id            :bigint           not null, primary key
#  key           :string
#  name          :string
#  name_kana     :string
#  name_log      :jsonb
#  note          :text
#  old_key       :string
#  old_wiki_text :text
#  provisional   :boolean          default(FALSE), not null
#  status        :integer          default("active"), not null
#  unit_type     :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  old_wiki_id   :integer
#
# Indexes
#
#  index_units_on_key        (key) UNIQUE
#  index_units_on_name       (name)
#  index_units_on_name_kana  (name_kana)
#  index_units_on_old_key    (old_key) UNIQUE
#
require 'cgi'
require 'ostruct'
require 'discard'

class Unit < ApplicationRecord # rubocop:disable Metrics/ClassLength
  include Discard::Model
  include KeyChangeable
  include Unpublishable
  include OgpImageAttachable
  has_many :links, as: :linkable, dependent: :destroy
  accepts_nested_attributes_for :links, allow_destroy: true, reject_if: proc { |attrs| attrs['url'].blank? }
  has_many :wiki_page_imports, as: :import_target
  # 公開フォームから送られた情報の訂正（issue #1902）
  has_many :profile_corrections, as: :target, dependent: :delete_all
  has_many :unit_people
  has_many :people, through: :unit_people
  has_many :unit_logs, dependent: :destroy
  has_many :tag_index_items, as: :indexable, dependent: :destroy
  has_many :tag_indices, through: :tag_index_items
  has_many :sections, as: :sectionable, dependent: :destroy
  has_many :unit_snapshots, dependent: :destroy
  has_many :temporary_snapshot_people, foreign_key: :hint_unit_id, inverse_of: :hint_unit, dependent: :nullify
  enum :unit_type, { band: 0, unit: 1, session: 2, solo: 3, limited: 4, moved: 5, other: 99 }
  enum :status, { pre: 0, active: 1, freeze: 2, disbanded: 3, unknown: 99 }

  # 仮登録（provisional: true）のユニットは admin 以外には表示しない（issue #1764）。
  # 公開側でユニットを取得するときは kept ではなくこのスコープを使う。
  scope :publicly_visible, -> { kept.where(provisional: false) }

  # 公開側の一覧（/units）と検索（/search）の対象。名前・keyが空のユニットは
  # カードのリンク（profile_path(key)）を作れないため除く（issue #1277, #1841）。
  scope :for_index, -> { publicly_visible.where.not(name: [nil, '']).where.not(key: [nil, '']) }

  # 一覧ページ（/units?q=）の検索条件。名前系の列（名前・ヨミガナ・名前の履歴・別名）だけを探す。
  # セクション名・メンバー名まで探す matching_keyword は重く、クローラーによる q と tag_ids の組み合わせ
  # アクセスでレスポンスタイムが悪化したため（issue #1855）、一覧ページでは使わない。
  # pattern は like_pattern でエスケープ済みの ILIKE パターンを渡す。
  scope :matching_name_keyword, lambda { |pattern|
    where('units.name ILIKE :q OR units.name_kana ILIKE :q OR units.name_log::text ILIKE :q OR units.aliases::text ILIKE :q',
          q: pattern)
  }

  # サイト内検索（/search）の検索条件。名前系の列に加えて、セクション名・メンバー名でも探す（issue #1841）。
  # 一覧ページ（/units?q=）は軽い matching_name_keyword を使うため、範囲は意図して分けている（issue #1855）。
  # pattern は like_pattern でエスケープ済みの ILIKE パターンを渡す。
  # 紐づくSection（discard済み・非公開を除く）の名前もマッチ対象にする。
  # スナップショットのメンバー名（person_name / name_alias）もマッチ対象にし、
  # 個人ページのないメンバー名からも所属ユニットを辿れるようにする（issue #1768）。
  # discard済みのメンバーと非表示（active = false）のスナップショットは除く。
  # メンバー情報は廃止予定の unit_people ではなく snapshot_people を参照する。
  # OR EXISTS (...) で書くと units の名前系の列のtrigram indexを組み合わせて使えず全件走査になるため、
  # 条件ごとに units.id を集めて UNION する形にしている。
  scope :matching_keyword, lambda { |pattern|
    where(<<~SQL.squish, q: pattern, section_type: 'Unit')
      units.id IN (
        SELECT id FROM units
        WHERE name ILIKE :q OR name_kana ILIKE :q OR name_log::text ILIKE :q OR aliases::text ILIKE :q
        UNION
        SELECT sectionable_id FROM sections
        WHERE sectionable_type = :section_type
          AND discarded_at IS NULL
          AND active = TRUE
          AND name ILIKE :q
        UNION
        SELECT unit_snapshots.unit_id FROM unit_snapshots
        INNER JOIN snapshot_people ON snapshot_people.unit_snapshot_id = unit_snapshots.id
        WHERE unit_snapshots.active = TRUE
          AND snapshot_people.discarded_at IS NULL
          AND (snapshot_people.person_name ILIKE :q OR snapshot_people.name_alias ILIKE :q)
      )
    SQL
  }

  validates :status, presence: true
  # keyが空だと一覧ページのprofile_path(key)がUrlGenerationErrorで落ちるため必須（issue #1277）
  validates :key, presence: true, uniqueness: { case_sensitive: false }
  # old_keyはDB(index_units_on_old_key)にunique制約があるが、管理画面から直接編集可能なため、
  # Rails側の検証がないと重複入力時にRecordNotUnique(PG::UniqueViolation)が未捕捉の例外として
  # そのまま500エラーになる（issue #1244でCustomPageに見つかった同種の不具合）
  validates :old_key, uniqueness: true, allow_blank: true
  validate :key_immutable, on: :update

  STATUS_TRANSLATIONS = {
    'pre' => '準備中',
    'active' => '活動中',
    'freeze' => '活動休止',
    'disbanded' => '解散',
    'unknown' => '不明'
  }.freeze

  def name
    CGI.unescapeHTML(super.to_s).presence
  end

  def status_text
    STATUS_TRANSLATIONS[status] || status.humanize
  end

  def vkdb_url
    return nil if old_key.blank?

    "#{Rails.application.config.old_key_url_base}/#{old_key}.html"
  end

  def name_logs
    (name_log || []).map { |h| OpenStruct.new(h) }
  end

  def activity_periods
    (activity_period || []).map { |h| OpenStruct.new(h) }
  end

  def activity_periods_attributes=(attributes)
    self.activity_period = attributes.values.reject { |a| a['from'].blank? && a['to'].blank? }.map do |a|
      { 'from' => a['from'].presence, 'to' => a['to'].presence, 'label' => a['label'].presence }
    end
  end

  def name_logs_attributes=(attributes)
    self.name_log = attributes.values.map do |attrs|
      next if attrs['name'].blank?

      {
        name: attrs['name'],
        name_kana: attrs['name_kana'],
        date: attrs['date']
      }
    end.compact
  end

  def aliases
    (self[:aliases] || []).map { |a| OpenStruct.new(a) }
  end

  def aliases_attributes=(attributes)
    self[:aliases] = attributes.values.reject { |a| a['name'].blank? }.map do |a|
      {
        name: CGI.unescapeHTML(a['name'].to_s),
        kana: a['kana'].to_s,
        old_key: a['old_key'].to_s.presence,
        hidden: ActiveModel::Type::Boolean.new.cast(a['hidden']).presence
      }.compact
    end
  end

  private

  def key_immutable
    return if key_change_in_progress
    return unless key_changed? && key_was.present?

    errors.add(:key, 'cannot be changed once set')
  end

  after_commit :expire_timeline_cache
  after_commit :expire_sidebar_cache

  def expire_timeline_cache
    Rails.cache.delete(TimelineController::CACHE_KEY)
  end

  def expire_sidebar_cache
    Rails.cache.delete(SidebarLoadable::RECENTLY_UPDATED_CACHE_KEY)
  end
end
