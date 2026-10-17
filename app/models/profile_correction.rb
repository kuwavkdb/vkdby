# frozen_string_literal: true

# == Schema Information
#
# Table name: profile_corrections
#
#  id                :bigint           not null, primary key
#  correction        :text             not null
#  email             :string
#  note              :text
#  source_url        :string
#  submission_status :integer          default("pending"), not null
#  submitter_ip      :string
#  target_type       :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  target_id         :bigint           not null
#
# Indexes
#
#  index_profile_corrections_on_submission_status  (submission_status)
#  index_profile_corrections_on_target             (target_type,target_id)
#

# ログイン不要の公開フォームから送られる、既存のユニット・個人の情報の訂正（issue #1902）。
# 会場の訂正（VenueSubmission の correction）と同じく一時的な受け皿として保存し、
# admin が対象を編集して反映したら対応済み（resolved）にする
class ProfileCorrection < ApplicationRecord
  TARGET_TYPES = %w[Unit Person].freeze

  belongs_to :target, polymorphic: true

  enum :submission_status, { pending: 0, rejected: 1, resolved: 2 }

  STRIPPED_ATTRIBUTES = %w[correction source_url note email].freeze

  before_validation :strip_attributes

  validates :target_type, inclusion: { in: TARGET_TYPES }
  validates :correction, presence: true
  # 管理画面の投稿一覧でhrefにそのまま入るため、javascript: などのスキームを保存させない（VenueSubmissionと同じ）
  validates :source_url, format: { with: Link::HTTP_URL_PATTERN, message: 'は http:// または https:// で始まるURLを入力してください' },
                         allow_blank: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, message: 'の形式が正しくありません' }, allow_blank: true

  scope :recent, -> { order(created_at: :desc) }

  # 訂正の対象にできるユニット・個人。公開ページ（ProfilesController#show）で表示できるものに限る。
  # 論理削除済み・転送元・仮登録のユニットはnil
  def self.correctable_target(key)
    return nil if key.blank?

    target = Unit.kept.find_by(key: key) || Person.kept.find_by(key: key)
    return nil if target.nil? || target.destination_key.present?
    return nil if target.is_a?(Unit) && target.provisional?

    target
  end

  def target_label
    target_type == 'Unit' ? 'ユニット' : '個人'
  end

  private

  def strip_attributes
    STRIPPED_ATTRIBUTES.each do |attribute|
      self[attribute] = self[attribute].to_s.strip.presence
    end
  end
end
