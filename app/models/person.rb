# frozen_string_literal: true

# == Schema Information
#
# Table name: people
#
#  id            :bigint           not null, primary key
#  birth_year    :integer
#  birthday      :date
#  blood         :string
#  hometown      :string
#  key           :string
#  name          :string
#  name_kana     :string
#  name_log      :jsonb
#  note          :text
#  old_history   :text
#  old_key       :string
#  old_wiki_text :text
#  parts         :jsonb
#  search_text   :text
#  status        :integer          default("active"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  old_wiki_id   :integer
#
# Indexes
#
#  index_people_on_key        (key) UNIQUE
#  index_people_on_name       (name)
#  index_people_on_name_kana  (name_kana)
#  index_people_on_old_key    (old_key) UNIQUE
#  index_people_on_search_text_trgm  (search_text)
#
require 'cgi'
require 'discard'

class Person < ApplicationRecord
  include Discard::Model
  include WikiParser
  include KeyChangeable
  include Unpublishable
  include OgpImageAttachable
  include SearchTextable
  has_many :links, as: :linkable, dependent: :destroy
  has_many :wiki_page_imports, as: :import_target
  has_many :unit_people
  has_many :units, through: :unit_people
  has_many :tag_index_items, as: :indexable, dependent: :destroy
  has_many :tag_indices, through: :tag_index_items
  has_many :sections, as: :sectionable, dependent: :destroy
  has_many :snapshot_people

  accepts_nested_attributes_for :links, allow_destroy: true, reject_if: proc { |attrs| attrs['url'].blank? }

  enum :status, { pre: 0, active: 1, free: 2, hiatus: 3, retirement: 90, passed_away: 98, unknown: 99 }

  # Valid parts for a person
  AVAILABLE_PARTS = %w[vocal guitar bass drums keyboard dj dancer manipulator].freeze

  BLOOD_TYPES = %w[A B O AB Unknown].freeze

  # 都道府県（全国地方公共団体コード順: 北海道→東北→関東→中部→近畿→中国→四国→九州・沖縄）
  PREFECTURES = %w[
    北海道
    青森県 岩手県 宮城県 秋田県 山形県 福島県
    茨城県 栃木県 群馬県 埼玉県 千葉県 東京都 神奈川県
    新潟県 富山県 石川県 福井県 山梨県 長野県 岐阜県 静岡県 愛知県
    三重県 滋賀県 京都府 大阪府 兵庫県 奈良県 和歌山県
    鳥取県 島根県 岡山県 広島県 山口県
    徳島県 香川県 愛媛県 高知県
    福岡県 佐賀県 長崎県 熊本県 大分県 宮崎県 鹿児島県 沖縄県
  ].freeze

  # 出身地入力欄の候補（都道府県以外の値も指定できるようにするため、候補はあくまで補助的な選択肢）
  HOMETOWN_SUGGESTIONS = (PREFECTURES + %w[海外 非公表]).freeze

  # Scopes
  scope :birthday_on, lambda { |date|
    where('EXTRACT(MONTH FROM birthday) = ? AND EXTRACT(DAY FROM birthday) = ?',
          date.month, date.day)
  }
  # /peopleの索引ページ（一覧・フィルタ選択肢の件数集計）の対象となる人物
  scope :for_index, -> { kept.where.not(key: [nil, '']) }
  # 公開側のキーワード検索（/search と /people?q=）の検索条件。
  # 両者で探す範囲がずれて「View all People →」の先で件数が減らないよう、ここ1か所にまとめる（issue #1841）。
  # query は normalize_search_query 済みの検索語を渡す。空白で区切った語ごとの AND 検索にする（issue #1842）。
  # 名前系の列（名前・ヨミガナ・名前の履歴・別名）は表記ゆれを吸収した search_text で探す（SearchTextable）。
  # 紐づくSection（discard済み・非公開を除く）の名前もマッチ対象にする。
  # OR EXISTS (...) で書くと people の列のtrigram indexを組み合わせて使えず全件走査になるため、
  # 条件ごとに people.id を集めて UNION する形にしている。
  scope :matching_keyword, lambda { |query|
    SearchNormalizer.words(query).inject(all) do |relation, word|
      name_sql, name_binds = search_text_condition(word)
      relation.where(<<~SQL.squish, q: "%#{sanitize_sql_like(word)}%", section_type: 'Person', **name_binds)
        people.id IN (
          SELECT id FROM people WHERE #{name_sql} OR old_history ILIKE :q
          UNION
          SELECT sectionable_id FROM sections
          WHERE sectionable_type = :section_type
            AND discarded_at IS NULL
            AND active = TRUE
            AND name ILIKE :q
        )
      SQL
    end
  }

  STATUS_TRANSLATIONS = {
    'pre' => '準備中',
    'active' => '活動中',
    'free' => 'フリー',
    'hiatus' => '活動休止',
    'retirement' => '引退',
    'passed_away' => '死去',
    'unknown' => '不明'
  }.freeze

  DUMMY_BIRTH_YEAR = 1904 # Leap year for Feb 29 compatibility

  before_save :normalize_birthday_year

  # keyが空だと一覧ページのprofile_path(key)がUrlGenerationErrorで落ちるため必須（issue #1277）
  validates :key, presence: true, uniqueness: { case_sensitive: false }
  validate :key_immutable, on: :update
  after_create :auto_link_snapshot_people
  after_commit :expire_sidebar_cache
  after_commit :expire_filter_counts_cache

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

  def birthday_display
    return nil unless birthday

    if birth_year.present?
      # Show full date with year
      Date.new(birth_year, birthday.month, birthday.day).strftime('%Y年%-m月%-d日')
    else
      # Show only month and day
      birthday.strftime('%-m月%-d日')
    end
  end

  # old_historyをパースして履歴アイテムの配列を返す
  # 戻り値: [
  #   [
  #     { unit_name: "ユニット名", part_and_name: "Part" or "Part+PersonName" or "PersonName",
  #       old_key: "EUC-JPエンコードされたユニット名", external_url: "外部URL", internal_url: "サイト内相対パス" },
  #     ... (同時期の活動)
  #   ],
  #   ...
  # ]
  def parse_old_history
    parse_history_string(old_history)
  end

  # Person logs for form (virtual attribute)
  def name_logs
    require 'ostruct'
    (self[:name_log] || []).map { |entry| ::OpenStruct.new(entry) }
  end

  def name_logs_attributes=(attributes)
    # attributes is a hash like { "0" => { "name" => "...", "name_kana" => "..." }, ... }
    # specific structure depends on how fields_for sends data

    # Filter out empty entries
    new_logs = attributes.values.reject do |attrs|
      attrs['name'].blank?
    end

    # Convert to array of hashes for JSON storage
    self.name_log = new_logs.map do |attrs|
      {
        name: attrs['name'],
        name_kana: attrs['name_kana']
      }
    end
  end

  def aliases
    require 'ostruct'
    (self[:aliases] || []).map { |a| ::OpenStruct.new(a) }
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

  def normalize_birthday_year
    return unless birthday

    # Always set birthday year to DUMMY_BIRTH_YEAR (1904)
    self.birthday = birthday.change(year: DUMMY_BIRTH_YEAR)
  end

  def key_immutable
    return if key_change_in_progress
    return unless key_changed? && key_was.present?

    errors.add(:key, 'cannot be changed once set')
  end

  def after_key_change(prev_key, new_key)
    SnapshotPerson.where(person_key: prev_key).update_all(person_key: new_key)
    UnitPerson.where(person_key: prev_key).update_all(person_key: new_key)
  end

  def auto_link_snapshot_people
    return if key.blank?

    targets = SnapshotPerson.where(person_key: key, person_id: nil)
    target_ids = targets.ids
    targets.update_all(person_id: id)
    # update_all ではコールバックが走らないため、SNSのマージを明示的に行う（issue #1654）
    SnapshotPerson.where(id: target_ids).find_each(&:merge_sns_into_person)
  end

  def expire_sidebar_cache
    Rails.cache.delete(SidebarLoadable::RECENTLY_UPDATED_CACHE_KEY)
  end

  def expire_filter_counts_cache
    PersonFilterCounts.expire
  end
end
