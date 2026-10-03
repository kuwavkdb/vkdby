# frozen_string_literal: true

require 'test_helper'

# 投稿画像をUnitの「画像」セクションへ移し、残りを縮小する（issue #1719）
class UnitSubmissionImageTransferTest < ActiveSupport::TestCase
  setup do
    @unit = Unit.create!(name: 'Transfer [Unit]', key: 'unit-submission-image-transfer-test', status: :active)
    @submission = UnitSubmission.create!(name: 'Transfer Unit', unit_type: :band, status: :active,
                                         is_related_person: true, image_usage_consented: true,
                                         links_attributes: { '0' => { url: 'https://example.com' } })
  end

  def attach(io: file_fixture('submission_image.png').open, filename: 'image.png')
    @submission.images.attach(io:, filename:, content_type: 'image/png')
    @submission.images_attachments.reload.last
  end

  test 'move appends the images to an existing image section' do
    section = @unit.sections.create!(name: UnitSubmissionImageTransfer::SECTION_NAME, markdown: '既存の本文')
    attachment = attach

    moved_to = UnitSubmissionImageTransfer.new(@submission, @unit).move([attachment.id])

    assert_equal section, moved_to
    assert_not moved_to.previously_new_record?
    assert_match %r{\A既存の本文\n\n!\[Transfer Unit\]\(/rails/active_storage/blobs/}, section.reload.markdown
    assert_equal [attachment.blob_id], section.images.map(&:blob_id)
  end

  test 'move creates the image section after the existing sections' do
    @unit.sections.create!(name: 'プロフィール', sort_order: 3)
    attachment = attach

    section = UnitSubmissionImageTransfer.new(@submission, @unit).move([attachment.id])

    assert_predicate section, :previously_new_record?
    assert_equal 4, section.sort_order
    assert_predicate section, :active?
  end

  test 'move does nothing without image usage consent' do
    attachment = attach
    @submission.update_columns(image_usage_consented: false)

    assert_nil UnitSubmissionImageTransfer.new(@submission, @unit).move([attachment.id])
    assert_empty @unit.sections
    assert_equal [attachment.id], @submission.images_attachments.reload.pluck(:id)
  end

  test 'shrink_remaining re-encodes the remaining images down to SHRINK_DIMENSION' do
    skip 'libvips is not installed in this environment' unless ActiveStorage::VIPS_AVAILABLE

    buffer = Vips::Image.black(1600, 400).write_to_buffer('.png')
    original = attach(io: StringIO.new(buffer), filename: 'large.png')

    UnitSubmissionImageTransfer.new(@submission, @unit).shrink_remaining

    images = @submission.reload.images
    assert_equal 1, images.count
    assert_not_equal original.blob_id, images.first.blob_id
    assert_equal 'large.png', images.first.filename.to_s
    image = Vips::Image.new_from_buffer(images.first.download, '')
    assert_equal [800, 200], [image.width, image.height]
    assert_not ActiveStorage::Attachment.exists?(original.id)
  end

  test 'shrink_remaining keeps the images without image usage consent untouched' do
    attachment = attach
    @submission.update_columns(image_usage_consented: false)

    UnitSubmissionImageTransfer.new(@submission, @unit).shrink_remaining

    assert_equal [attachment.id], @submission.images_attachments.reload.pluck(:id)
  end
end
