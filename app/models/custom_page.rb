# frozen_string_literal: true

# == Schema Information
#
# Table name: custom_pages
#
#  id           :bigint           not null, primary key
#  active       :boolean          default(FALSE), not null
#  body         :text
#  discarded_at :datetime
#  key          :string           not null
#  title        :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_custom_pages_on_discarded_at  (discarded_at)
#  index_custom_pages_on_key          (key) UNIQUE
#

class CustomPage < ApplicationRecord
  include Discard::Model

  # 削除不可のページkey一覧（ルートとして使用されるなど、システム上必須のページ）
  PROTECTED_KEYS = %w[index].freeze

  validates :key, presence: true, uniqueness: true,
                  format: { with: /\A[a-z0-9_-]+\z/, message: '半角英数字・アンダースコア・ハイフンのみ使用可' }
  validates :title, presence: true

  scope :published, -> { kept.where(active: true) }

  def protected?
    PROTECTED_KEYS.include?(key)
  end
end
