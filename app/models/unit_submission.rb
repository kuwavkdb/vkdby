# frozen_string_literal: true

# == Schema Information
#
# Table name: unit_submissions
#
#  id                :bigint           not null, primary key
#  email             :string
#  is_related_person :boolean          default(FALSE), not null
#  name              :string           not null
#  name_kana         :string
#  note              :text
#  status            :integer
#  submission_status :integer          default(0), not null
#  unit_type         :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  converted_unit_id :bigint
#
# Indexes
#
#  index_unit_submissions_on_converted_unit_id  (converted_unit_id)
#  index_unit_submissions_on_submission_status  (submission_status)
#
# Foreign Keys
#
#  fk_rails_...  (converted_unit_id => units.id)
#

# ログイン不要の公開フォームから投稿される、Unit新規登録の下書き。
# TemporarySnapshotPerson / WikiPageImport と同様、一時受け皿として保存し、
# admin が内容を確認したうえで Admin::UnitsController#new へ内容を引き継いで
# 正式な Unit を作成する（この時点では変換済みには自動でならない）。
# 詳細: https://github.com/kuwavkdb/vkdby/issues/1545
class UnitSubmission < ApplicationRecord
  belongs_to :converted_unit, class_name: 'Unit', optional: true
  has_many :links, as: :linkable, dependent: :destroy
  accepts_nested_attributes_for :links, allow_destroy: true, reject_if: proc { |attrs| attrs['url'].blank? }

  enum :unit_type, { band: 0, unit: 1, session: 2, solo: 3, limited: 4, moved: 5, other: 99 }
  enum :status, { pre: 0, active: 1, freeze: 2, disbanded: 3, unknown: 99 }
  enum :submission_status, { pending: 0, rejected: 1, converted: 2 }

  UNIT_TYPE_TRANSLATIONS = {
    'band' => 'バンド',
    'unit' => 'ユニット',
    'session' => 'セッション',
    'solo' => 'ソロ',
    'other' => 'その他'
  }.freeze

  validates :name, presence: true
  validates :unit_type, presence: true
  validates :status, presence: true
  validate :at_least_one_link

  scope :recent, -> { order(created_at: :desc) }

  private

  def at_least_one_link
    return if links.reject(&:marked_for_destruction?).any? { |link| link.url.present? }

    errors.add(:base, 'リンクを1件以上入力してください')
  end
end
