# frozen_string_literal: true

# == Schema Information
#
# Table name: sections
#
#  id               :bigint           not null, primary key
#  active           :boolean          default(TRUE), not null
#  discarded_at     :datetime
#  markdown         :text
#  name             :string
#  sectionable_type :string           not null
#  sort_order       :integer
#  wiki_text        :text
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  sectionable_id   :bigint           not null
#
# Indexes
#
#  index_sections_on_discarded_at  (discarded_at)
#  index_sections_on_sectionable   (sectionable_type,sectionable_id)
#
class Section < ApplicationRecord
  include Discard::Model

  belongs_to :sectionable, polymorphic: true
  has_many_attached :images

  validates :name, presence: true

  # 公開ビューに表示してよいセクション（discardとは独立。削除はせず一時的に非公開にしたい場合に使う）
  scope :publicly_visible, -> { where(active: true) }

  after_commit :expire_including_pages_cache, on: %i[create update destroy]

  private

  def expire_including_pages_cache
    return unless sectionable.is_a?(CustomPage)

    CustomPageInclude
      .where(target_custom_page: sectionable, section_name: name)
      .includes(:source_custom_page)
      .each { |rel| rel.source_custom_page.expire_cache }
  end
end
