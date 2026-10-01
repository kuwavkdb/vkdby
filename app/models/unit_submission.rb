# frozen_string_literal: true

# == Schema Information
#
# Table name: unit_submissions
#
#  id                    :bigint           not null, primary key
#  email                 :string
#  image_usage_consented :boolean          default(FALSE), not null
#  is_related_person     :boolean          default(FALSE), not null
#  name                  :string           not null
#  name_kana             :string
#  note                  :text
#  status                :integer
#  submission_status     :integer          default(0), not null
#  submitter_ip          :string
#  unit_type             :integer
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  converted_unit_id     :bigint
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
#
# 本人・関係者（is_related_person）の投稿に限り、画像を添付できる（issue #1718）。
# 画像は image_files で受け取り、検証とメタデータの除去（SubmissionImageSanitizer）を
# 済ませてから images に添付する。関係者でない投稿の画像は、エラーにせず黙って捨てる
# （関係者チェックと画像欄が連動していることを投稿者に知らせないため）。
class UnitSubmission < ApplicationRecord
  MAX_IMAGES = 3
  MAX_IMAGE_SIZE = 3.megabytes

  belongs_to :converted_unit, class_name: 'Unit', optional: true
  has_many :links, as: :linkable, dependent: :destroy
  has_many_attached :images
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
  validate :validate_image_files

  before_validation :discard_images_unless_related_person
  before_create :attach_sanitized_images

  scope :recent, -> { order(created_at: :desc) }

  attr_reader :image_files

  # フォームから送られた画像ファイル。アップロードされたファイル以外（空文字や、
  # 既存blobを指すsigned_id等の文字列）は受け付けない
  def image_files=(files)
    @image_files = Array(files).select { |file| file.respond_to?(:path) && file.respond_to?(:original_filename) }
  end

  private

  def at_least_one_link
    return if links.reject(&:marked_for_destruction?).any? { |link| link.url.present? }

    errors.add(:base, 'リンクを1件以上入力してください')
  end

  def discard_images_unless_related_person
    return if is_related_person?

    @image_files = []
    self.image_usage_consented = false
  end

  def validate_image_files
    @sanitized_images = []
    return if image_files.blank?

    if image_files.size > MAX_IMAGES
      errors.add(:base, "画像は#{MAX_IMAGES}枚まで添付できます")
    elsif image_files.any? { |file| file.size > MAX_IMAGE_SIZE }
      errors.add(:base, "画像は1枚#{MAX_IMAGE_SIZE / 1.megabyte}MBまでです")
    end
    errors.add(:base, '画像を添付する場合は、サイト上での利用を了承してください') unless image_usage_consented?
    # 画像の作り直しは重いため、ほかにエラーがあるときは行わない
    return if errors.any?

    @sanitized_images = image_files.map { |file| SubmissionImageSanitizer.call(file) }
  rescue SubmissionImageSanitizer::UnsupportedImage
    errors.add(:base, '画像はJPEG・PNG・WebP形式のファイルを添付してください')
  rescue SubmissionImageSanitizer::Unavailable
    errors.add(:base, '画像を処理できませんでした。時間をおいて再度お試しください')
  end

  # 投稿は作成後に内容を編集しないため、画像の添付も作成時だけ行う
  # （保存済みのレコードに対するattachはレコード自体を保存し直すため、コールバック内では避ける）
  def attach_sanitized_images
    return if @sanitized_images.blank?

    images.attach(@sanitized_images.map(&:to_h))
  end
end
