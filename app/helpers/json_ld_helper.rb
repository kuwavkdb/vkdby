# frozen_string_literal: true

# 構造化データ（schema.org の JSON-LD）を出力する（issue #1254）。
# 検索エンジンにページの内容（作品・会場・サイト名）を正しく理解させるためのもの。
# 値が空の項目は出力しない（compact_json_ld）。確認は Rich Results Test（https://search.google.com/test/rich-results）で行う。
module JsonLdHelper
  SCHEMA_CONTEXT = 'https://schema.org'

  # <script type="application/ld+json"> を返す。
  # json_escape で <・>・& をエスケープし、値に "</script>" が含まれていてもタグを閉じられないようにする
  def json_ld_tag(data)
    tag.script(ERB::Util.json_escape(compact_json_ld(data).to_json).html_safe, type: 'application/ld+json')
  end

  # トップページ: サイト名を正しく認識させるための WebSite。
  # サイト内検索ボックス（SearchAction）は Google が 2024 年に表示をやめたため出力しない
  def website_json_ld
    {
      '@context' => SCHEMA_CONTEXT,
      '@type' => 'WebSite',
      'name' => Rails.application.config.site_name,
      'url' => root_url
    }
  end

  # 作品詳細（/items/:id）: MusicAlbum
  def item_json_ld(item)
    {
      '@context' => SCHEMA_CONTEXT,
      '@type' => 'MusicAlbum',
      'name' => item.title,
      'url' => item_url(item),
      'datePublished' => item.release_date&.iso8601,
      'image' => item.image_url,
      'byArtist' => item_json_ld_artists(item)
    }
  end

  # 会場詳細（/venues/:key）: MusicVenue。links には公開中のリンク（公式サイト・SNS）を渡す
  def venue_json_ld(venue, links: [])
    {
      '@context' => SCHEMA_CONTEXT,
      '@type' => 'MusicVenue',
      'name' => venue.name,
      'url' => venue_url(venue.key),
      'alternateName' => venue_json_ld_alternate_names(venue),
      'address' => venue_json_ld_address(venue),
      'geo' => venue_json_ld_geo(venue),
      'maximumAttendeeCapacity' => venue.capacity,
      'sameAs' => links.map(&:url).compact_blank.uniq
    }
  end

  private

  # 空の値（nil・空文字・空配列・空ハッシュ）を、入れ子も含めて取り除く
  def compact_json_ld(value)
    case value
    when Hash
      value.transform_values { |v| compact_json_ld(v) }.compact_blank
    when Array
      value.map { |v| compact_json_ld(v) }.compact_blank
    else
      value
    end
  end

  # 作品のアーティスト。サイト内に個人ページがあるキーは Person、それ以外（ユニット・ページのない名前）は MusicGroup にする
  def item_json_ld_artists(item)
    artists = item.artists.select { |a| (a['alias'].presence || a['name']).present? }
    keys = artists.filter_map { |a| a['key'].presence }
    person_keys = keys.any? ? Person.for_index.where(key: keys).pluck(:key).to_set : Set.new

    artists.map do |artist|
      path = artist_profile_path(artist)
      {
        '@type' => person_keys.include?(artist['key']) ? 'Person' : 'MusicGroup',
        'name' => artist['alias'].presence || artist['name'],
        'url' => path && "#{request.base_url}#{path}"
      }
    end
  end

  # 別名（非表示のものを除く）と旧名
  def venue_json_ld_alternate_names(venue)
    alias_names = venue.aliases.reject(&:hidden).map(&:name)
    former_names = venue.name_logs.map(&:name)
    (alias_names + former_names).compact_blank.uniq - [venue.name]
  end

  def venue_json_ld_address(venue)
    return if venue.address.blank? && venue.prefecture.blank?

    {
      '@type' => 'PostalAddress',
      'streetAddress' => venue.address,
      'addressRegion' => venue.prefecture,
      'addressCountry' => 'JP'
    }
  end

  def venue_json_ld_geo(venue)
    return if venue.latitude.blank? || venue.longitude.blank?

    { '@type' => 'GeoCoordinates', 'latitude' => venue.latitude.to_f, 'longitude' => venue.longitude.to_f }
  end
end
