# frozen_string_literal: true

require 'test_helper'

# issue #2088: 縮小版を作るとき、JPEG を読み込む段階で縮小させる（-define jpeg:size）
class JpegSizeHintTest < ActiveSupport::TestCase
  def image_magick_available?
    %w[magick convert].any? { |command| system("#{command} -version", out: File::NULL, err: File::NULL) }
  end

  def hint_for(transformations)
    ActiveStorage::Transformers::ImageMagick.new(transformations).send(:jpeg_size_hint)
  end

  test '縮小の指定の2倍を、幅・高さの大きいほうにそろえて読み込みの大きさにする' do
    assert_equal '2400x2400', hint_for(resize_to_limit: [1200, nil])
    assert_equal '600x600', hint_for(resize_to_limit: [300, 300])
    assert_equal '1600x1600', hint_for(resize_to_fill: [800, 400])
  end

  test '縮小の指定が無ければ読み込みの大きさを指定しない' do
    assert_nil hint_for(format: 'png')
    assert_nil hint_for(rotate: 90)
  end

  test 'JPEG の縮小版を、読み込みの指定を付けて目標の大きさで作れる' do
    skip 'ImageMagick がない環境' unless image_magick_available?

    Tempfile.create(['source', '.jpg']) do |source|
      MiniMagick::Tool::Convert.new do |convert|
        convert.size('2000x1000')
        convert << 'xc:white'
        convert << source.path
      end

      ActiveStorage::Transformers::ImageMagick.new(resize_to_limit: [400, nil]).transform(source, format: 'jpg') do |output|
        assert_equal [400, 200], MiniMagick::Image.open(output.path).dimensions
      end
    end
  end
end
