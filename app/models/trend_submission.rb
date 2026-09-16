# frozen_string_literal: true

# == Schema Information
#
# Table name: trend_submissions
#
#  id                 :bigint           not null, primary key
#  content             :text
#  date                :date             not null
#  day_unknown         :boolean          default(FALSE), not null
#  email               :string
#  is_related_person   :boolean          default(FALSE), not null
#  month_unknown       :boolean          default(FALSE), not null
#  phenomenon          :integer          not null
#  submission_status   :integer          default(0), not null
#  submitter_ip        :string
#  target_id           :bigint
#  target_name         :string           not null
#  target_type         :integer          not null
#  title               :string
#  via_url             :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  converted_trend_id  :bigint
#
# Indexes
#
#  index_trend_submissions_on_converted_trend_id  (converted_trend_id)
#  index_trend_submissions_on_submission_status   (submission_status)
#
# Foreign Keys
#
#  fk_rails_...  (converted_trend_id => trends.id)
#

# ログイン不要の公開フォームから投稿される、Trend新規登録の下書き。
# UnitSubmission（issue #1545）と同様に一時受け皿として保存し、admin が内容を
# 確認したうえで Admin::TrendsController#new へ内容を引き継いで正式な Trend を
# 作成する（この時点では変換済みには自動でならない）。
# TrendはUnit/Personと異なり既存レコードへの参照(units/people jsonb)と動向種別
# (unit_phenomenon/person_phenomenon)を持つため、投稿対象の種別(target_type)と
# 動向種別(phenomenon)を投稿者自身に指定してもらう。詳細: https://github.com/kuwavkdb/vkdby/issues/1553
class TrendSubmission < ApplicationRecord
  belongs_to :converted_trend, class_name: 'Trend', optional: true

  enum :target_type, { unit: 0, person: 1 }
  enum :submission_status, { pending: 0, rejected: 1, converted: 2 }

  validates :target_type, presence: true
  validates :target_name, presence: true
  validates :date, presence: true
  validates :via_url, presence: true
  validates :phenomenon, presence: true

  scope :recent, -> { order(created_at: :desc) }

  # target_typeに応じた動向種別の選択肢（Trendのenumキーの配列）。
  # etc_phenomenonはunknown/otherしか値を持たず投稿者向けには意味がないため出さない
  def self.phenomenon_options_for(target_type)
    case target_type.to_s
    when 'unit' then Trend.unit_phenomenons.keys
    when 'person' then Trend.person_phenomenons.keys
    else []
    end
  end

  # target_type・phenomenon(整数値)から対応するTrend enumのキー文字列を引く
  def self.phenomenon_key_for(target_type, phenomenon_value)
    return nil if phenomenon_value.blank?

    case target_type.to_s
    when 'unit' then Trend.unit_phenomenons.key(phenomenon_value.to_i)
    when 'person' then Trend.person_phenomenons.key(phenomenon_value.to_i)
    end
  end

  def phenomenon_options
    self.class.phenomenon_options_for(target_type)
  end

  def phenomenon_key
    self.class.phenomenon_key_for(target_type, phenomenon)
  end

  def phenomenon_label
    key = phenomenon_key
    return nil unless key

    I18n.t("activerecord.attributes.trend.#{target_type}_phenomenon.#{key}")
  end
end
