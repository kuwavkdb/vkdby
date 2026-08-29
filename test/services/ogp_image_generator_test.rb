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
    assert_equal 1200, image.width
    assert_equal 628, image.height
  end

  test 'returns nil instead of raising when text rendering fails' do
    skip 'libvips is not installed in this environment' unless ActiveStorage::VIPS_AVAILABLE

    stub_class_method(Vips::Image, :text, ->(*) { raise Vips::Error, 'boom' }) do
      result = OgpImageGenerator.call('テストユニット')

      assert_nil result
    end
  end

  # text_optionsの結果だけを見る純粋なRubyのロジックテスト。実際にVips::Image.textを
  # 呼ぶ（compose_image経由の）テストにすると、存在しないフォント名解決やfontfileの
  # 組み合わせによってlibvips内部がクラッシュすることがあり（並列テスト実行時に確認）、
  # 不安定になるため避けている。
  test 'text_options uses fontfile/font instead of the generic font name when a CJK font file is found' do
    fake_font_file = '/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc'
    options = stub_class_method(OgpImageGenerator, :cjk_font_file, fake_font_file) do
      OgpImageGenerator.new('テストユニット').send(:text_options)
    end

    assert_equal fake_font_file, options[:fontfile]
    assert_equal OgpImageGenerator::CJK_FONT_FAMILY, options[:font]
  end

  test 'text_options falls back to the generic font name when no CJK font file is found' do
    options = stub_class_method(OgpImageGenerator, :cjk_font_file, nil) do
      OgpImageGenerator.new('テストユニット').send(:text_options)
    end

    assert_nil options[:fontfile]
    assert_equal OgpImageGenerator::FONT, options[:font]
  end
end
