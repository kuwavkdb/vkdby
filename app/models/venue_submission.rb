# frozen_string_literal: true

# == Schema Information
#
# Table name: venue_submissions
#
#  id                 :bigint           not null, primary key
#  address            :string
#  area               :string
#  capacity           :integer
#  correction         :text
#  email              :string
#  name               :string
#  name_kana          :string
#  note               :text
#  prefecture         :string
#  source_url         :string
#  submission_kind    :integer          default("new_venue"), not null
#  submission_status  :integer          default("pending"), not null
#  submitter_ip       :string
#  venue_type         :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  converted_venue_id :bigint
#  venue_id           :bigint
#
# Indexes
#
#  index_venue_submissions_on_converted_venue_id  (converted_venue_id)
#  index_venue_submissions_on_submission_status   (submission_status)
#  index_venue_submissions_on_venue_id            (venue_id)
#
# Foreign Keys
#
#  fk_rails_...  (converted_venue_id => venues.id)
#  fk_rails_...  (venue_id => venues.id)
#

# ログイン不要の公開フォームから投稿される会場の情報（issue #1814）。
# UnitSubmission・TrendSubmissionと同じく一時的な受け皿として保存し、admin が内容を確認してから反映する。
# - 新しい会場（new_venue）: 会場名・都道府県が必須。承認時に Admin::VenuesController#new へ内容を引き継いで会場を作る
# - 既存の会場の訂正（correction）: 対象の会場（venue）と訂正内容が必須。admin が会場を編集して反映し、対応済みにする
class VenueSubmission < ApplicationRecord
  belongs_to :venue, optional: true
  belongs_to :converted_venue, class_name: 'Venue', optional: true

  enum :submission_kind, { new_venue: 0, correction: 1 }
  enum :submission_status, { pending: 0, rejected: 1, converted: 2 }

  STRIPPED_ATTRIBUTES = %w[name name_kana venue_type prefecture area address correction source_url note email].freeze

  before_validation :strip_attributes

  with_options if: :new_venue? do
    validates :name, presence: true
    validates :prefecture, presence: true
  end
  validates :prefecture, inclusion: { in: Venue::PREFECTURES }, allow_blank: true
  validates :venue_type, inclusion: { in: Venue.venue_types.keys }, allow_blank: true
  validates :capacity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  with_options if: :correction? do
    validates :venue, presence: true
    validates :correction, presence: true
  end

  # 管理画面の投稿一覧でhrefにそのまま入るため、javascript: などのスキームを保存させない（TrendSubmissionと同じ）
  validates :source_url, format: { with: Link::HTTP_URL_PATTERN, message: 'は http:// または https:// で始まるURLを入力してください' },
                         allow_blank: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, message: 'の形式が正しくありません' }, allow_blank: true

  scope :recent, -> { order(created_at: :desc) }

  # 訂正の対象にできる会場。キー変更・統合の転送元は転送先の会場に読み替え、論理削除済み・転送先がない会場はnil
  def self.correctable_venue(venue_id)
    venue = Venue.with_discarded.find_by(id: venue_id)
    return nil unless venue

    resolved = Venue.resolve_by_key(venue.key)
    resolved if resolved&.kept?
  end

  # 会場の新規作成画面（Admin::VenuesController#new）の初期値。情報源のURLは公式サイトのリンクとして引き継ぐ
  def venue_attributes
    attrs = { name: name, name_kana: name_kana, venue_type: venue_type, prefecture: prefecture, area: area,
              address: address, capacity: capacity }.compact_blank
    attrs[:links_attributes] = { '0' => { text: '公式サイト', url: source_url } } if source_url.present?
    attrs
  end

  def venue_type_text
    Venue::VENUE_TYPE_TRANSLATIONS[venue_type]
  end

  def display_name
    correction? ? venue&.name : name
  end

  private

  def strip_attributes
    STRIPPED_ATTRIBUTES.each do |attribute|
      self[attribute] = self[attribute].to_s.strip.presence
    end
  end
end
