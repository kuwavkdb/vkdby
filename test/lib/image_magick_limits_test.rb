# frozen_string_literal: true

require 'test_helper'

# issue #2082: 縮小版を作る ImageMagick がメモリを使い切って本番が落ちないよう、上限を入れておく
class ImageMagickLimitsTest < ActiveSupport::TestCase
  test 'ImageMagick のメモリの上限が環境変数に入っている' do
    assert_predicate ENV.fetch('MAGICK_MEMORY_LIMIT', nil), :present?
    assert_predicate ENV.fetch('MAGICK_MAP_LIMIT', nil), :present?
  end
end
