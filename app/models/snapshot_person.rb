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

  # Person未紐付けのこのメンバーを、Personとして独立させる（issue #1596で追加されたcreate_person
  # アクションが呼ぶ）。name / key / parts / old_history に加え、extra_profile_person_attributes を
  # 通じて誕生日等の下書き情報も引き継ぐ（issue #1619）。
  def build_person_for_independence
    Person.new({ name: person_name, key: person_key,
                 parts: part == 'unknown' ? [] : [part],
                 old_history: inline_history }
                .merge(extra_profile_person_attributes))
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
