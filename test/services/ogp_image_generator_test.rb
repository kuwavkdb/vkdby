# frozen_string_literal: true

require 'test_helper'

class OgpImageGeneratorTest < ActiveSupport::TestCase
  test 'returns nil when libvips is not available' do
    result = stub_class_method(OgpImageGenerator, :vips_available?, false) { OgpImageGenerator.call('テストユニット') }

    assert_nil result
  end

  test 'returns PNG binary data when libvips is available' do
    skip 'libvips is not installed in this environment' unless ActiveStorage::VIPS_AVAILABLE

    result = OgpImageGenerator.call('テストユニット')

    assert_not_nil result
    image = Vips::Image.new_from_buffer(result, '')
    assert_equal 1500, image.width
    assert_equal 500, image.height
  end

  test 'returns nil instead of raising when text rendering fails' do
    skip 'libvips is not installed in this environment' unless ActiveStorage::VIPS_AVAILABLE

    stub_class_method(Vips::Image, :text, ->(*) { raise Vips::Error, 'boom' }) do
      result = OgpImageGenerator.call('テストユニット')

      assert_nil result
    end
  end
end
