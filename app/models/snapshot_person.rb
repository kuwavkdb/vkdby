# frozen_string_literal: true

# == Schema Information
#
# Table name: snapshot_people
#
#  id               :bigint           not null, primary key
#  extra_profile    :jsonb
#  inline_history   :text
#  name_alias       :string
#  old_person_key   :string
#  part             :integer          default("vocal"), not null
#  part_alias       :string
#  person_key       :string
#  person_name      :string
#  sns              :json
#  sort_order       :integer          default(0), not null
#  status           :integer          default("active"), not null
#  support          :boolean          default(FALSE), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  person_id        :bigint
#  unit_snapshot_id :bigint           not null
#
# Indexes
#
#  index_snapshot_people_on_old_person_key               (old_person_key)
#  index_snapshot_people_on_person_id                    (person_id)
#  index_snapshot_people_on_person_key                   (person_key)
#  index_snapshot_people_on_unit_snapshot_id             (unit_snapshot_id)
#  index_snapshot_people_on_unit_snapshot_id_and_sort_order  (unit_snapshot_id,sort_order)
#
# Foreign Keys
#
#  fk_rails_...  (person_id => people.id)
#  fk_rails_...  (unit_snapshot_id => unit_snapshots.id)
#
class SnapshotPerson < ApplicationRecord
  include Discard::Model
  include WikiParser

  # sns_link_attributes で Link として取り込む値（空白を含まない http(s) URL）
  SNS_LINK_URL_PATTERN = %r{\Ahttps?://\S+\z}i

  default_scope { kept }

  # touch: true は {{snapshot}}プラグイン（application_helper.rb）のキャッシュキーが
  # UnitSnapshot#updated_at を参照しているための対応。SnapshotPerson単体の
  # 作成・更新・削除・discard/undiscardのたびに親UnitSnapshotのupdated_atも更新され、
  # キャッシュが自動的に無効化される。
  belongs_to :unit_snapshot, touch: true
  belongs_to :person, optional: true

  enum :status, { undefined: 0, active: 1, pending: 2, left: 3, concerned: 4, pre: 5 }
  enum :part, { vocal: 0, guitar: 1, bass: 2, drums: 3, keyboard: 4, dj: 5, unknown: 99 }

  validates :status, presence: true
  validates :part, presence: true
  validate :person_or_name_presence

  before_validation :find_person_by_key, if: -> { person_id.blank? && person_key.present? }
  # 紐付け先のPersonが変わったら、sns を Person#links にマージする（issue #1654）。
  # update_all で person_id を書き換える経路（Person#auto_link_snapshot_people、
  # PersonImporter#link_existing_snapshot_people）ではコールバックが走らないため、各経路で明示的に呼ぶ。
  after_save :merge_sns_into_person, if: -> { saved_change_to_person_id? && person_id.present? && !skip_sns_merge }

  # 既に紐付け済みのメンバーを複製するとき（スナップショットのコピー・移動）は、紐付けの変更ではないため
  # マージしない。Person側で意図的に削除したLinkが復活するのを防ぐ。
  attr_accessor :skip_sns_merge

  # 直近の merge_sns_into_person で追加したLink（管理画面で UpdateLog を記録するために参照する）
  attr_reader :merged_links

  def name
    person_name.presence || person&.name
  end

  def key
    person&.key || person_key
  end

  def parse_inline_history
    parse_history_string(inline_history)
  end

  # extra_profile（Person未紐付けメンバーの下書きプロフィール）から、Personの新規作成に渡せる
  # 属性へ変換する（issue #1619）。birthday は "07/12" のような月日のみの文字列を想定し、
  # Person#birthday（date型、保存時に年はダミー年へ正規化される: Person#normalize_birthday_year）
  # にそのまま渡せる形にする。パースできない値は安全にスキップし、他の項目には影響させない。
  def extra_profile_person_attributes
    profile = extra_profile || {}
    attrs = {}

    if profile['birthday'].present?
      parsed = parse_extra_profile_birthday(profile['birthday'])
      attrs[:birthday] = parsed if parsed
    end
    attrs[:birth_year] = profile['birth_year'] if profile['birth_year'].present?
    attrs[:blood] = profile['blood'] if profile['blood'].present?
    attrs[:hometown] = profile['hometown'] if profile['hometown'].present?

    attrs
  end

  # sns（"@handle"形式、またはURLの配列）から、Person#links に作成する Link の属性へ変換する（issue #1653）。
  # "@handle" は X(Twitter) のURLへ変換し、URLはそのまま使う。どちらでもない値（"@"のみ、
  # スキーム無しの文字列等）はリンク先を特定できないためスキップする。空要素・重複URLは除く。
  # text は空のままにし、表示名・アイコンは Link#sns_info のURL判定に任せる。
  def sns_link_attributes
    urls = Array(sns).filter_map do |account|
      account = account.to_s.strip
      next if account.blank? || account == '@'

      url = SnsInfoIcon.url_for_account(account)
      url if url.match?(SNS_LINK_URL_PATTERN)
    end

    urls.uniq.each_with_index.map { |url, index| { url: url, sort_order: index + 1 } }
  end

  # sns のうち、Person#links にまだ無いURL（Link.comparable_url で比較）を返す（issue #1654）。
  # known_urls には、Personにはまだ保存されていないが追加予定のURLを渡せる（rakeのdry-run用）。
  def sns_urls_missing_from(person, known_urls: [])
    return [] if sns.blank?

    existing = (person.links.pluck(:url) + known_urls).to_set { |url| Link.comparable_url(url) }

    sns_link_attributes.map { |attrs| attrs[:url] }
                       .reject { |url| existing.include?(Link.comparable_url(url)) }
                       .uniq { |url| Link.comparable_url(url) }
  end

  # sns のうち Person#links にまだ無いものを、既存Linkの末尾に追加する（issue #1654）。
  # 追加したLinkの配列を返し、merged_links からも参照できる。
  def merge_sns_into_person
    @merged_links = []
    return @merged_links if person.nil?

    base_sort_order = person.links.maximum(:sort_order).to_i
    @merged_links = sns_urls_missing_from(person).each_with_index.map do |url, index|
      person.links.create!(url: url, sort_order: base_sort_order + index + 1)
    end
  end

  # Person未紐付けのこのメンバーを、Personとして独立させる（issue #1596で追加されたcreate_person
  # アクションが呼ぶ）。name / key / parts / old_history に加え、extra_profile_person_attributes を
  # 通じて誕生日等の下書き情報も引き継ぐ（issue #1619）。sns は Person#links として引き継ぎ、
  # Person の保存と同時に作成される（issue #1653）。
  def build_person_for_independence
    person = Person.new({ name: person_name, key: person_key,
                          parts: part == 'unknown' ? [] : [part],
                          old_history: inline_history }
                         .merge(extra_profile_person_attributes))
    sns_link_attributes.each { |attrs| person.links.build(attrs) }
    person
  end

  private

  def parse_extra_profile_birthday(value)
    month, day = value.to_s.split(%r{[/.\-月]}).map(&:to_i)
    return nil unless month&.between?(1, 12) && day&.between?(1, 31)

    Date.new(Person::DUMMY_BIRTH_YEAR, month, day)
  rescue ArgumentError
    nil
  end

  def person_or_name_presence
    return unless person_id.blank? && person_name.blank?

    errors.add(:base, 'Person or Person Name must be present')
  end

  def find_person_by_key
    found_person = Person.find_by(key: person_key)
    return unless found_person

    self.person = found_person
  end
end
