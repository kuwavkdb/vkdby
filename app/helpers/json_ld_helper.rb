# frozen_string_literal: true

# 構造化データ（schema.org の JSON-LD）を出力する（issue #1254）。
# 検索エンジンにページの内容（作品・会場・ユニット・個人・サイト名）を正しく理解させるためのもの。
# 値が空の項目は出力しない（compact_json_ld）。確認は Rich Results Test（https://search.google.com/test/rich-results）で行う。
module JsonLdHelper # rubocop:disable Metrics/ModuleLength
  SCHEMA_CONTEXT = 'https://schema.org'
  GENRE = 'ヴィジュアル系'
  # 活動期間などの日付（"2010/01/**" のように、不明な部分を ** で書く）
  PARTIAL_DATE_PATTERN = %r{\A(\d{4})(?:[/.-](\d{1,2}|\*\*))?(?:[/.-](\d{1,2}|\*\*))?}

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
      'alternateName' => json_ld_alternate_names(venue),
      'address' => venue_json_ld_address(venue),
      'geo' => venue_json_ld_geo(venue),
      'maximumAttendeeCapacity' => venue.capacity,
      'sameAs' => links.map(&:url).compact_blank.uniq
    }
  end

  # ユニットのページ: MusicGroup。メンバーは「現在」のスナップショットの在籍メンバーだけ
  # （元メンバー・サポート・関係者は含めない）。snapshots にはページで表示するスナップショットを渡す
  def unit_json_ld(unit, links: [], snapshots: [])
    {
      '@context' => SCHEMA_CONTEXT,
      '@type' => 'MusicGroup',
      'name' => unit.name,
      'url' => profile_url(unit.key),
      'alternateName' => json_ld_alternate_names(unit),
      'genre' => GENRE,
      'foundingDate' => json_ld_partial_date(unit.activity_periods.first&.from),
      'dissolutionDate' => (json_ld_partial_date(unit.activity_periods.last&.to) if unit.disbanded?),
      'member' => unit_json_ld_members(snapshots),
      'sameAs' => links.map(&:url).compact_blank.uniq
    }
  end

  # 個人のページ: Person。所属は今在籍しているユニットだけ。
  # 誕生日は生年があれば年月日、なければ月日だけ（--MM-DD）を出す。パート・血液型は出さない
  def person_json_ld(person, links: [])
    {
      '@context' => SCHEMA_CONTEXT,
      '@type' => 'Person',
      'name' => person.name,
      'url' => profile_url(person.key),
      'alternateName' => person.name_logs.map(&:name).compact_blank.uniq - [person.name],
      'birthDate' => person_json_ld_birth_date(person),
      'homeLocation' => (person.hometown.present? ? { '@type' => 'Place', 'name' => person.hometown } : nil),
      'memberOf' => person_json_ld_member_of(person),
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

  # 別名（非表示のものを除く）と旧名。会場・ユニットで共通
  def json_ld_alternate_names(record)
    alias_names = record.aliases.reject(&:hidden).map(&:name)
    former_names = record.name_logs.map(&:name)
    (alias_names + former_names).compact_blank.uniq - [record.name]
  end

  # "2010/01/**" → "2010-01"、"2003/**/**" → "2003"、"2010/1/5" → "2010-01-05"。読めなければ nil
  def json_ld_partial_date(value)
    match = PARTIAL_DATE_PATTERN.match(value.to_s.strip)
    return unless match

    year = match[1]
    month, day = match.captures.drop(1).map { |part| part == '**' ? nil : part&.to_i }
    return year unless month&.between?(1, 12)
    return "#{year}-#{month.to_s.rjust(2, '0')}" unless day && Date.valid_date?(year.to_i, month, day)

    "#{year}-#{month.to_s.rjust(2, '0')}-#{day.to_s.rjust(2, '0')}"
  end

  def unit_json_ld_members(snapshots)
    snapshot = snapshots.find { |s| s.current? && !s.past? }
    return [] unless snapshot

    snapshot.snapshot_people.select { |sp| sp.active? && !sp.support? }.sort_by(&:sort_order).map do |member|
      person = member.person
      {
        '@type' => 'Person',
        'name' => member.name,
        'url' => (profile_url(person.key) if person&.key.present? && !person.discarded?)
      }
    end
  end

  def person_json_ld_birth_date(person)
    return if person.birthday.blank?

    month_day = person.birthday.strftime('%m-%d')
    person.birth_year.to_i.positive? ? "#{person.birth_year}-#{month_day}" : "--#{month_day}"
  end

  # 今在籍しているユニット（「現在」のスナップショットの在籍メンバー。サポート・関係者は除く）
  def person_json_ld_member_of(person)
    SnapshotPerson.where(person_id: person.id, status: :active, support: false)
                  .joins(:unit_snapshot)
                  .where(unit_snapshots: { current: true, past: false, active: true, unit_id: Unit.for_index.select(:id) })
                  .includes(unit_snapshot: :unit)
                  .map { |member| member.unit_snapshot.unit }
                  .uniq
                  .map { |unit| { '@type' => 'MusicGroup', 'name' => unit.name, 'url' => profile_url(unit.key) } }
  end

  # 住所は画面と同じく、旧サイトの「MAP:」を取り除いた display_address を使う
  def venue_json_ld_address(venue)
    return if venue.display_address.blank? && venue.prefecture.blank?

    {
      '@type' => 'PostalAddress',
      'streetAddress' => venue.display_address,
      'addressRegion' => venue.prefecture,
      'addressCountry' => 'JP'
    }
  end

  def venue_json_ld_geo(venue)
    return if venue.latitude.blank? || venue.longitude.blank?

    { '@type' => 'GeoCoordinates', 'latitude' => venue.latitude.to_f, 'longitude' => venue.longitude.to_f }
  end
end
