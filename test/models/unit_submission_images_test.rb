# frozen_string_literal: true

require 'test_helper'

# UnitSubmission の画像添付（issue #1718）
class UnitSubmissionImagesTest < ActiveSupport::TestCase
  def valid_attributes
    {
      name: 'Test Unit', unit_type: :band, status: :active,
      links_attributes: { '0' => { url: 'https://example.com' } }
    }
  end

  def png_upload
    Rack::Test::UploadedFile.new(file_fixture('submission_image.png'), 'image/png')
  end

  # libvipsが無い環境（CI等）でも添付までの流れを確認できるよう、作り直しの結果を差し替える
  def with_stubbed_sanitizer(&)
    result = lambda do |file|
      SubmissionImageSanitizer::Result.new(io: StringIO.new(File.binread(file.path)), filename: 'sanitized.png',
                                           content_type: 'image/png')
    end
    stub_class_method(SubmissionImageSanitizer, :call, result, &)
  end

  def related_attributes(**overrides)
    valid_attributes.merge(is_related_person: true, image_usage_consented: true, image_files: [png_upload], **overrides)
  end

  test 'attaches sanitized images when submitted by a related person with consent' do
    with_stubbed_sanitizer do
      submission = UnitSubmission.create!(related_attributes)

      assert_equal 1, submission.images.count
      assert_equal 'sanitized.png', submission.images.first.filename.to_s
      assert_predicate submission, :image_usage_consented?
    end
  end

  test 'silently discards images when the submitter is not a related person' do
    with_stubbed_sanitizer do
      submission = UnitSubmission.new(related_attributes(is_related_person: false))

      assert submission.save
      assert_not submission.images.attached?
      assert_not submission.image_usage_consented?
    end
  end

  test 'requires consent to attach images' do
    with_stubbed_sanitizer do
      submission = UnitSubmission.new(related_attributes(image_usage_consented: false))

      assert_not submission.valid?
      assert_includes submission.errors[:base], '画像を添付する場合は、サイト上での利用を了承してください'
    end
  end

  test 'accepts at most MAX_IMAGES images' do
    with_stubbed_sanitizer do
      submission = UnitSubmission.new(related_attributes(image_files: Array.new(UnitSubmission::MAX_IMAGES + 1) { png_upload }))

      assert_not submission.valid?
      assert_includes submission.errors[:base], "画像は#{UnitSubmission::MAX_IMAGES}枚まで添付できます"
    end
  end

  test 'rejects images larger than MAX_IMAGE_SIZE' do
    large = png_upload
    large.define_singleton_method(:size) { UnitSubmission::MAX_IMAGE_SIZE + 1 }

    with_stubbed_sanitizer do
      submission = UnitSubmission.new(related_attributes(image_files: [large]))

      assert_not submission.valid?
      assert_includes submission.errors[:base], '画像は1枚5MBまでです'
    end
  end

  test 'rejects images that the sanitizer cannot read' do
    unsupported = ->(_file) { raise SubmissionImageSanitizer::UnsupportedImage, 'gif' }

    stub_class_method(SubmissionImageSanitizer, :call, unsupported) do
      submission = UnitSubmission.new(related_attributes)

      assert_not submission.valid?
      assert_includes submission.errors[:base], '画像はJPEG・PNG・WebP形式のファイルを添付してください'
    end
  end

  test 'does not save images with metadata when libvips is unavailable' do
    stub_class_method(SubmissionImageSanitizer, :vips_available?, false) do
      submission = UnitSubmission.new(related_attributes)

      assert_not submission.valid?
      assert_includes submission.errors[:base], '画像を処理できませんでした。時間をおいて再度お試しください'
    end
  end

  test 'ignores non-file values such as signed blob ids' do
    submission = UnitSubmission.new(related_attributes(image_files: ['', 'some-signed-id']))

    assert submission.save
    assert_not submission.images.attached?
  end
end
