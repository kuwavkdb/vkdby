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
#  old_key      :string
#  title        :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_custom_pages_on_discarded_at  (discarded_at)
#  index_custom_pages_on_key           (key) UNIQUE
#  index_custom_pages_on_old_key       (old_key) UNIQUE
#

class CustomPage < ApplicationRecord
  include Discard::Model
  include OgpImageAttachable

  has_many_attached :images
  has_many :sections, as: :sectionable, dependent: :destroy
  has_many :custom_page_includes, foreign_key: :source_custom_page_id, dependent: :destroy, inverse_of: :source_custom_page
  has_many :included_by, class_name: 'CustomPageInclude', foreign_key: :target_custom_page_id, dependent: :destroy, inverse_of: :target_custom_page

  # 削除不可のページkey一覧（ルートとして使用されるなど、システム上必須のページ）
  PROTECTED_KEYS = %w[index].freeze

  # サイトの仕組み（トップページ本体・グローバルフッター・トップメッセージ・IPブロックリスト）として
  # 参照される「システム用ページ」のkey一覧。今後増える場合はここに追加する。
  SYSTEM_KEYS = (%w[index footer top_message] + [Middleware::IpBlocker::CUSTOM_PAGE_KEY]).freeze

  # old_keyを未入力で保存すると空文字列(nilではなく'')になり、DBのunique索引は
  # NULL同士の重複は許容する一方 '' 同士は許容しないため、old_key未設定のページが
  # 複数あると更新のたびにPG::UniqueViolationが未捕捉のまま500エラーになっていた
  # （システムページ等、old_keyを設定しない運用のページで発生。issue #1305）。
  # 空文字列をnilに正規化しておくことで、DB側もNULL同士として扱われ衝突しない。
  before_validation { self.old_key = old_key.presence }

  validates :key, presence: true, uniqueness: true,
                  format: { with: /\A[a-z0-9_-]+\z/, message: '半角英数字・アンダースコア・ハイフンのみ使用可' }
  validates :title, presence: true
  # old_keyはDB(index_custom_pages_on_old_key)にunique制約があるが、管理画面から直接編集可能な
  # ため、Rails側の検証がないと重複入力時にRecordNotUnique(PG::UniqueViolation)が未捕捉の例外
  # としてそのまま500エラーになっていた（issue #1244）
  validates :old_key, uniqueness: true, allow_blank: true
  validate :no_circular_includes, if: :body_changed?

  scope :published, -> { kept.where(active: true) }
  scope :system_pages, -> { where(key: SYSTEM_KEYS) }
  scope :non_system_pages, -> { where.not(key: SYSTEM_KEYS) }

  after_commit :expire_sidebar_cache
  after_commit :expire_blocked_ips_cache, if: -> { key == Middleware::IpBlocker::CUSTOM_PAGE_KEY }
  after_save :rebuild_include_relations, if: :saved_change_to_body?

  def protected?
    PROTECTED_KEYS.include?(key)
  end

  def system?
    SYSTEM_KEYS.include?(key)
  end

  def vkdb_url
    return nil if old_key.blank?

    "#{Rails.application.config.old_key_url_base}/#{old_key}.html"
  end

  def expire_cache
    # 現時点ではページ固有のキャッシュはないが、将来的な拡張に備えたフック
    # サイドバーキャッシュも念のため削除
    Rails.cache.delete('sidebar/recently_updated')
  end

  def rebuild_include_relations
    custom_page_includes.delete_all
    body.to_s.scan(/\{\{include\s+([a-z0-9_-]+),(.+?)\}\}/) do |page_key, section_name|
      target = CustomPage.find_by(key: page_key.strip)
      next unless target

      custom_page_includes.create!(
        target_custom_page: target,
        section_name: section_name.strip
      )
    end
  end

  private

  # OgpImageAttachable用: CustomPageには`name`カラムがなく`title`を使う（issue #1263）。
  def ogp_image_attachable_text
    title
  end

  def ogp_image_attachable_text_changed?
    saved_change_to_title?
  end

  def no_circular_includes
    return if body.blank?

    keys_in_body = body.scan(/\{\{include\s+([a-z0-9_-]+),/).flatten.map(&:strip).uniq
    return if keys_in_body.empty?

    # このページの key が、インクルード先のページから（直接・間接を問わず）参照されていないか確認
    keys_in_body.each do |target_key|
      target_page = CustomPage.find_by(key: target_key)
      next unless target_page

      errors.add(:body, "循環インクルードが検出されました（#{target_key} → #{key} のパスが存在します）") if reachable_from?(target_page, self, visited: Set.new)
    end
  end

  # target_page から辿ってベースページ（base）に到達できるか確認（循環参照検出）
  def reachable_from?(current_page, base, visited:)
    return false if visited.include?(current_page.id)

    visited.add(current_page.id)
    current_page.custom_page_includes.includes(:target_custom_page).each do |rel|
      return true if rel.target_custom_page_id == base.id
      return true if reachable_from?(rel.target_custom_page, base, visited:)
    end
    false
  end

  def expire_sidebar_cache
    Rails.cache.delete('sidebar/recently_updated')
  end

  def expire_blocked_ips_cache
    Rails.cache.delete(Middleware::IpBlocker::CACHE_KEY)
  end
end
