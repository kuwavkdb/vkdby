# frozen_string_literal: true

# ユニット投稿（UnitSubmission）の画像を、承認して作ったUnitのページで使えるようにする（issue #1719）。
#
# - 使う画像は、Unitの「画像」Section（SECTION_NAME）へ移し、本文の末尾にMarkdownで追記する。
#   「画像」Sectionが無ければ作る。移すときはblobを複製せず、投稿側の添付レコードを
#   Sectionへ付け替える（ストレージを余分に使わず、投稿側を消してもUnit側の画像は残る）。
# - 使わなかった画像は投稿に残すが、長辺 SHRINK_DIMENSION px まで縮小して作り直す。
#   縮小できなかった場合（libvipsが無い等）は元の画像のまま残し、ログに記録する
#   （Unitの作成自体は失敗させない）。
#
# 本人・関係者の投稿で、サイト上での利用を了承しているもの（usable?）だけを対象にする。
# 呼び出し側（Admin::UnitsController / Admin::UnitSubmissionsController）でadminに限っている。
class UnitSubmissionImageTransfer
  SECTION_NAME = '画像'
  SHRINK_DIMENSION = 800
  SHRINK_QUALITY = 80

  def self.usable?(unit_submission)
    unit_submission.is_related_person? && unit_submission.image_usage_consented?
  end

  def initialize(unit_submission, unit)
    @unit_submission = unit_submission
    @unit = unit
  end

  # attachment_ids の画像（投稿に属するものに限る）を「画像」Sectionへ移し、そのSectionを返す。
  # 移す画像が無ければnilを返す。Sectionを作ったかどうかは previously_new_record? で分かる
  def move(attachment_ids)
    return nil unless self.class.usable?(@unit_submission)

    attachments = image_attachments.where(id: Array(attachment_ids)).to_a
    return nil if attachments.empty?

    section = image_section
    Section.transaction do
      section.markdown = [section.markdown.presence, *attachments.map { |attachment| markdown_for(attachment.blob) }]
                         .compact.join("\n\n")
      section.save!
      # record: section で付け替えると、添付のtouchで section の saved_changes が変わってしまい、
      # 呼び出し側でUpdateLogに本文の変更を記録できなくなるため、IDで付け替える
      attachments.each { |attachment| attachment.update!(record_type: 'Section', record_id: section.id) }
    end
    section
  end

  # 投稿に残っている画像を縮小する。作り直した画像を添付してから、元の画像を消す
  def shrink_remaining
    return unless self.class.usable?(@unit_submission)

    # 作り直した画像も同じ投稿に添付するため、先に対象を読み込んでおく
    image_attachments.to_a.each { |attachment| shrink(attachment) }
  end

  private

  # 関連のキャッシュを使わず、その時点の添付を読む（移した画像が残って見えないように）
  def image_attachments
    ActiveStorage::Attachment.where(record: @unit_submission, name: 'images').order(:id).includes(:blob)
  end

  def image_section
    @unit.sections.kept.find_by(name: SECTION_NAME) ||
      @unit.sections.build(name: SECTION_NAME, active: true, sort_order: next_sort_order)
  end

  def next_sort_order
    (@unit.sections.kept.maximum(:sort_order) || 0) + 1
  end

  # 既存のコピーボタンと同じく、altにはUnit名からMarkdownのリンク記号を除いたものを使う
  def markdown_for(blob)
    url = Rails.application.routes.url_helpers.rails_blob_path(blob, disposition: :inline, only_path: true)
    "![#{@unit.name.delete('[]')}](#{url})"
  end

  # 縮小は後始末なので、ストレージの通信エラー等も含めて呼び出し元には伝えない
  def shrink(attachment)
    blob = attachment.blob
    result = blob.open do |file|
      SubmissionImageSanitizer.call(file, max_dimension: SHRINK_DIMENSION, quality: SHRINK_QUALITY,
                                          filename: blob.filename.to_s)
    end
    @unit_submission.images.attach(result.to_h)
    attachment.purge_later
  rescue StandardError => e
    Rails.logger.warn(
      "UnitSubmissionImageTransfer: 画像を縮小できませんでした (UnitSubmission##{@unit_submission.id}, " \
      "attachment##{attachment.id}): #{e.class}: #{e.message}"
    )
  end
end
