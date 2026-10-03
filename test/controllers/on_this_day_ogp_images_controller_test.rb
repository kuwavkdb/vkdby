# frozen_string_literal: true

require 'test_helper'

class OnThisDayOgpImagesControllerTest < ActionDispatch::IntegrationTest
  test '「今日はなんの日？／M月D日」を合成したPNGを長期キャッシュ付きで返す（issue #1746）' do
    texts = []
    generator = lambda { |text|
      texts << text
      'PNGDATA'
    }

    stub_class_method(OgpImageGenerator, :call, generator) { get birthday_date_ogp_image_path(month: 5, day: 30) }

    assert_response :success
    assert_equal 'image/png', response.media_type
    assert_equal 'PNGDATA', response.body
    assert_equal ["今日はなんの日？\n5月30日"], texts
    assert_includes response.headers['Cache-Control'], 'public'
  end

  test '画像を生成できない環境ではデフォルト画像へリダイレクトする' do
    stub_class_method(OgpImageGenerator, :call, nil) { get birthday_date_ogp_image_path(month: 5, day: 30) }

    assert_redirected_to Rails.application.config.site_ogp_image_path
  end

  test '存在しない日付は404' do
    stub_class_method(OgpImageGenerator, :call, 'PNGDATA') { get birthday_date_ogp_image_path(month: 2, day: 30) }

    assert_response :not_found
  end
end
