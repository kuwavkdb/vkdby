# frozen_string_literal: true

# == Schema Information
#
# Table name: links
#
#  id            :bigint           not null, primary key
#  active        :boolean          default(TRUE)
#  linkable_type :string           not null
#  sort_order    :integer
#  text          :string
#  url           :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  linkable_id   :bigint           not null
#
# Indexes
#
#  index_links_on_linkable  (linkable_type,linkable_id)
#
require 'test_helper'

class LinkTest < ActiveSupport::TestCase
  test 'url は http:// / https:// で始まるものだけ受け付ける' do
    %w[https://example.com http://example.com HTTPS://EXAMPLE.COM].each do |url|
      link = Link.new(url:)
      link.validate

      assert_empty link.errors[:url], url
    end
  end

  test 'url に javascript: などのスキームやスキームのないURLは保存できない' do
    ['javascript:alert(1)', ' javascript:alert(1)', 'data:text/html,<script>alert(1)</script>', 'example.com'].each do |url|
      link = Link.new(url:)
      link.validate

      assert_includes link.errors[:url], 'は http:// または https:// で始まるURLを入力してください', url
    end
  end

  test 'twitter_status_url? is true for a twitter.com status URL' do
    link = Link.new(url: 'https://twitter.com/nonameactorsjp/status/892008297930268674')

    assert link.twitter_status_url?
  end

  test 'twitter_status_url? is true for an x.com status URL' do
    link = Link.new(url: 'https://x.com/nonameactorsjp/status/892008297930268674')

    assert link.twitter_status_url?
  end

  test 'twitter_status_url? is false for a plain twitter.com profile URL' do
    link = Link.new(url: 'https://twitter.com/nonameactorsjp')

    refute link.twitter_status_url?
  end

  test 'twitter_status_url? is false for a blank URL' do
    link = Link.new(url: nil)

    refute link.twitter_status_url?
  end

  test 'sns_info detects a Twitter profile URL' do
    link = Link.new(url: 'https://twitter.com/nonameactorsjp')

    assert_equal({ platform: 'Twitter', account: '@nonameactorsjp' }, link.sns_info)
  end

  test 'sns_info detects an x.com profile URL' do
    link = Link.new(url: 'https://x.com/nonameactorsjp')

    assert_equal({ platform: 'Twitter', account: '@nonameactorsjp' }, link.sns_info)
  end

  test 'sns_info detects an Instagram profile URL' do
    link = Link.new(url: 'https://instagram.com/nonameactorsjp')

    assert_equal({ platform: 'Instagram', account: 'nonameactorsjp' }, link.sns_info)
  end

  test 'sns_info detects a YouTube channel URL with @handle' do
    link = Link.new(url: 'https://youtube.com/@nonameactorsjp')

    assert_equal({ platform: 'YouTube', account: 'nonameactorsjp' }, link.sns_info)
  end

  # issue #2141: 日本語のチャンネル名は符号化されたまま保存されているので、表示用に元の文字へ戻す
  test 'sns_info decodes a percent-encoded YouTube handle' do
    link = Link.new(url: 'https://www.youtube.com/@%E3%83%8D%E3%82%AA%E5%AF%86%E5%AE%A4%E7%B3%BB%E3%83%90%E3%83%B3%E3%83%89%E3%81%AE%E3%82%AB%E3%83%AA%E3%82%BD%E3%83%A1%E3%81%A7%E3%81%99')

    assert_equal({ platform: 'YouTube', account: 'ネオ密室系バンドのカリソメです' }, link.sns_info)
    assert_equal 'YouTube (ネオ密室系バンドのカリソメです)', link.display_text
  end

  test 'sns_info keeps a plus sign in the account name' do
    link = Link.new(url: 'https://www.youtube.com/@a+b')

    assert_equal 'a+b', link.sns_info[:account]
  end

  test 'sns_info keeps the raw account name when it does not decode to valid UTF-8' do
    link = Link.new(url: 'https://www.youtube.com/@%FF%FE')

    assert_equal '%FF%FE', link.sns_info[:account]
  end

  test 'sns_info detects a YouTube channel URL with /c/ path' do
    link = Link.new(url: 'https://youtube.com/c/nonameactorsjp')

    assert_equal({ platform: 'YouTube', account: 'nonameactorsjp' }, link.sns_info)
  end

  test 'sns_info detects a TikTok profile URL' do
    link = Link.new(url: 'https://tiktok.com/@nonameactorsjp')

    assert_equal({ platform: 'TikTok', account: '@nonameactorsjp' }, link.sns_info)
  end

  test 'sns_info detects a Spotify artist URL' do
    link = Link.new(url: 'https://open.spotify.com/artist/1sXDlFi6YNLaPGdCf9oMZR')

    assert_equal({ platform: 'Spotify', account: '1sXDlFi6YNLaPGdCf9oMZR' }, link.sns_info)
  end

  test 'sns_info detects a Spotify artist URL with locale prefix' do
    link = Link.new(url: 'https://open.spotify.com/intl-ja/artist/1sXDlFi6YNLaPGdCf9oMZR')

    assert_equal({ platform: 'Spotify', account: '1sXDlFi6YNLaPGdCf9oMZR' }, link.sns_info)
  end

  test 'sns_info is nil for a non-SNS URL' do
    link = Link.new(url: 'https://example.com')

    assert_nil link.sns_info
  end

  # issue #1654: SNSのマージ時の重複判定
  test 'comparable_url treats scheme, www, trailing slash, case and twitter.com as the same' do
    expected = Link.comparable_url('https://x.com/foo')

    assert_equal expected, Link.comparable_url('http://twitter.com/Foo/')
    assert_equal expected, Link.comparable_url('https://www.x.com/foo')
    assert_equal expected, Link.comparable_url('https://mobile.twitter.com/foo#top')
    assert_equal Link.comparable_url('https://instagram.com/bar'),
                 Link.comparable_url('https://www.instagram.com/bar/')
  end

  test 'comparable_url distinguishes different accounts and hosts' do
    assert_not_equal Link.comparable_url('https://x.com/foo'), Link.comparable_url('https://x.com/foo2')
    assert_not_equal Link.comparable_url('https://twitter.community/foo'), Link.comparable_url('https://x.com/foo')
  end
end
