# frozen_string_literal: true

require 'test_helper'

class SubmissionImageSanitizerTest < ActiveSupport::TestCase
  def upload(name, content_type)
    Rack::Test::UploadedFile.new(file_fixture(name), content_type)
  end

  test 'raises Unavailable when libvips is not available' do
    stub_class_method(SubmissionImageSanitizer, :vips_available?, false) do
      assert_raises(SubmissionImageSanitizer::Unavailable) do
        SubmissionImageSanitizer.call(upload('submission_image.png', 'image/png'))
      end
    end
  end

  test 're-encodes a PNG without metadata' do
    skip 'libvips is not installed in this environment' unless ActiveStorage::VIPS_AVAILABLE

    result = SubmissionImageSanitizer.call(upload('submission_image.png', 'image/png'))

    assert_equal 'image/png', result.content_type
    assert_equal 'submission_image.png', result.filename
    image = Vips::Image.new_from_buffer(result.io.read, '')
    assert_equal 1, image.width
    assert_not_includes image.get_fields, 'exif-data'
  end

  test 'strips EXIF from a JPEG after applying its orientation' do
    skip 'libvips is not installed in this environment' unless ActiveStorage::VIPS_AVAILABLE

    # 横8×縦4の画像に、右に90度回して表示する向き（6）と撮影者のEXIFを付ける
    source = Vips::Image.black(8, 4).mutate do |image|
      image.set_type!(GObject::GINT_TYPE, 'orientation', 6)
      image.set_type!(GObject::GSTR_TYPE, 'exif-ifd0-Artist', 'secret')
    end
    Tempfile.create(['with_exif', '.jpg']) do |file|
      source.write_to_file(file.path)
      assert_includes Vips::Image.new_from_file(file.path).get_fields, 'exif-data'

      result = SubmissionImageSanitizer.call(Rack::Test::UploadedFile.new(file.path, 'image/jpeg'))

      assert_equal 'image/jpeg', result.content_type
      assert_match(/\Awith_exif.*\.jpg\z/, result.filename)
      image = Vips::Image.new_from_buffer(result.io.read, '')
      assert_not_includes image.get_fields, 'exif-data'
      assert_equal [4, 8], [image.width, image.height]
    end
  end

  test 'rejects GIF even when the content type claims to be PNG' do
    skip 'libvips is not installed in this environment' unless ActiveStorage::VIPS_AVAILABLE

    assert_raises(SubmissionImageSanitizer::UnsupportedImage) do
      SubmissionImageSanitizer.call(upload('submission_image.gif', 'image/png'))
    end
  end

  test 'rejects files that are not images' do
    skip 'libvips is not installed in this environment' unless ActiveStorage::VIPS_AVAILABLE

    Tempfile.create(['not_image', '.png']) do |file|
      file.write('<svg xmlns="http://www.w3.org/2000/svg"></svg>')
      file.flush

      assert_raises(SubmissionImageSanitizer::UnsupportedImage) do
        SubmissionImageSanitizer.call(Rack::Test::UploadedFile.new(file.path, 'image/png'))
      end
    end
  end

  test 'shrinks to the given dimension and names the file after the given filename' do
    skip 'libvips is not installed in this environment' unless ActiveStorage::VIPS_AVAILABLE

    Tempfile.create(['blob', '.jpg']) do |file|
      Vips::Image.black(1200, 600).write_to_file(file.path)

      result = SubmissionImageSanitizer.call(File.open(file.path), max_dimension: 800, quality: 80,
                                                                   filename: 'original.jpeg')

      assert_equal 'original.jpg', result.filename
      image = Vips::Image.new_from_buffer(result.io.read, '')
      assert_equal [800, 400], [image.width, image.height]
    end
  end
end
