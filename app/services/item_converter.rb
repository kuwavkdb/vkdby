# frozen_string_literal: true

# ReleaseSchedule を Item に変換するサービス
class ItemConverter
  def self.convert(release_schedule)
    new(release_schedule).convert
  end

  def initialize(release_schedule)
    @rs = release_schedule
  end

  def convert
    return nil unless valid_type?

    case @rs.type
    when 'aitem'
      convert_aitem
    when 'a2s'
      convert_a2s
    end
  end

  private

  def valid_type?
    %w[aitem a2s].include?(@rs.type)
  end

  def convert_aitem
    asin = @rs.asin
    return nil if asin.blank?

    link_url = build_amazon_url(asin)
    return nil if link_url.blank?

    release_date = @rs.release_date&.to_date
    return nil if release_date.blank?

    title = @rs.title
    return nil if title.blank?

    artists = parse_artists_for_aitem(@rs.artist)

    {
      artists: artists,
      asin: asin,
      title: title,
      release_date: release_date,
      image_url: @rs.l_img_url.presence || @rs.img_url,
      link_url: link_url,
      old_item_id: @rs.id
    }
  end

  def convert_a2s
    asin = extract_asin_from_plugin_text(@rs.plugin_text)
    return nil if asin.blank?

    link_url = build_amazon_url(asin)
    return nil if link_url.blank?

    release_date = @rs.release_date&.to_date
    return nil if release_date.blank?

    title = @rs.title
    return nil if title.blank?

    artists = parse_artists_for_a2s(@rs.artist, @rs.wiki)

    {
      artists: artists,
      asin: asin,
      title: title,
      release_date: release_date,
      image_url: @rs.l_img_url.presence || @rs.img_url,
      link_url: link_url,
      old_item_id: @rs.id
    }
  end

  # type=aitem の artist フィールドをパース
  # 単なるテキストまたは wiki リンク [[名前]] を処理
  def parse_artists_for_aitem(artist_text)
    return [] if artist_text.blank?

    # wiki リンクが含まれているかチェック
    if artist_text.include?('[[')
      extract_wiki_links(artist_text)
    else
      # 単なるテキストの場合
      [{
        'name' => artist_text,
        'old_key' => encode_euc_jp(artist_text)
      }]
    end
  end

  # type=a2s の artist フィールドをパース
  # artist を name、wiki を old_key として使用
  def parse_artists_for_a2s(artist_text, wiki_text)
    return [] if artist_text.blank?

    [{
      'name' => artist_text,
      'old_key' => encode_euc_jp(wiki_text.presence || artist_text)
    }]
  end

  # wiki テキストから [[名前]] または [[表示名|名前]] を抽出
  def extract_wiki_links(text)
    artists = []
    
    # [[表示名|名前]] または [[名前]] の形式を抽出
    text.scan(/\[\[(?:([^\]|]+)\|)?([^\]]+)\]\]/) do |display_name, actual_name|
      name = display_name.presence || actual_name
      # (アーティスト) などの接尾辞を削除
      name = name.gsub(/\(.*?\)/, '').strip
      
      artists << {
        'name' => name,
        'old_key' => encode_euc_jp(actual_name)
      }
    end

    artists
  end

  # EUC-JP エンコード処理
  def encode_euc_jp(text)
    return '' if text.blank?

    text.encode('EUC-JP', invalid: :replace, undef: :replace)
        .bytes
        .map { |b| format('%%%02X', b) }
        .join
  end

  # ASIN から Amazon URL を生成
  def build_amazon_url(asin)
    return nil if asin.blank?

    "https://www.amazon.co.jp/exec/obidos/ASIN/#{asin}/vkdb-22/"
  end

  # plugin_text から ASIN を抽出
  # フォーマット: "artist,asin1,asin2" または "artist,asin"
  # 最後の要素を ASIN として使用
  def extract_asin_from_plugin_text(plugin_text)
    return nil if plugin_text.blank?

    parts = plugin_text.split(',')
    parts.last&.strip
  end
end
