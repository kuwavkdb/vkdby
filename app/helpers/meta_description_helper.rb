# frozen_string_literal: true

# ページごとの meta description（検索結果のスニペット）を登録データから組み立てる（issue #1937, #1938）。
# 出力は layout の content_for(:description) 経由。長さの上限は ApplicationHelper::META_DESCRIPTION_MAX_LENGTH。
# ユニット・個人のページでは、ジャンル（ヴィジュアル系）はサイトの方向性であってユニット自体の分類ではないため書かない
# （一覧ページはサイトの説明なので書く。issue #1957）。
module MetaDescriptionHelper
  # バンド索引の説明文に入れる検索語の長さの上限（利用者の入力なので切る）
  UNITS_INDEX_QUERY_MAX_LENGTH = 30

  # Person#parts（Person::AVAILABLE_PARTS）の表記。パートを足したら、ここにも足す
  PART_NAMES = {
    'vocal' => 'ボーカル', 'guitar' => 'ギター', 'bass' => 'ベース', 'drums' => 'ドラム', 'keyboard' => 'キーボード',
    'dj' => 'DJ', 'dancer' => 'ダンサー', 'manipulator' => 'マニピュレーター'
  }.freeze

  # ユニットのページ。例:
  #   「UnsraW（アンスロウ）は2012年結成、2018年解散のバンド。最終メンバーは〇〇、〇〇。バンドの歴史やメンバーの経歴、音源等を掲載。」
  # ソロは「アーティスト」とし、結成・解散を活動開始・活動終了に言い換え、メンバーは書かない。
  # 結成年・解散年やメンバーが無ければその部分を省く。
  # members は Unit#current_public_members の結果。上限の字数に収まる人数だけ並べ、残りは「他」とする
  # （締めの文が切れないようにするため）。
  def unit_meta_description(unit, members: [])
    solo = unit.solo?
    head = "#{name_with_kana(unit.name, unit.name_kana)}は#{unit_meta_description_period(unit, solo:)}" \
           "#{solo ? 'アーティスト' : 'バンド'}#{'（活動休止中）' if unit.hiatus?}。"
    tail = solo ? 'アーティストの歴史や経歴、音源等を掲載。' : 'バンドの歴史やメンバーの経歴、音源等を掲載。'
    names = solo ? [] : members.map(&:name).compact_blank
    room = ApplicationHelper::META_DESCRIPTION_MAX_LENGTH - head.length - tail.length
    # 「最終」は解散年が確かなとき（Unit#dissolution_date があるとき）だけ付ける
    label = unit.dissolution_date ? '最終メンバー' : 'メンバー'
    "#{head}#{meta_description_list(label, names, room)}#{tail}"
  end

  # 個人のページ（issue #1938）。例:
  #   「〇〇（読み）は△△のボーカル・ギター。過去の在籍バンドは□□、××。経歴や在籍バンド、音源等を掲載。」
  # 今の所属が無ければ「〇〇はボーカル。」、パートも無ければ「〇〇はアーティスト。」とする。
  # 今の所属・過去の在籍バンドとも個人の経歴（old_history）だけから組み立て、スナップショットは使わない
  # （issue #1945, #1951。person_meta_description_memberships）。状態・誕生日・出身地は書かない。
  # 今の所属・過去の在籍バンドとも、上限の字数に収まる件数だけ並べ、残りは「他」とする。
  # history_items は解析済みの経歴（Person#parse_old_history の結果）。ページの表示用に解析した結果を渡し、
  # 1回の表示で解析を2回しないようにする（issue #1955）。省略したときはここで解析する
  def person_meta_description(person, history_items: person.parse_old_history)
    tail = '経歴や在籍バンド、音源等を掲載。'
    current_names, past_names = person_meta_description_memberships(person, history_items)
    head = person_meta_description_head(person, current_names, tail)
    room = ApplicationHelper::META_DESCRIPTION_MAX_LENGTH - head.length - tail.length
    "#{head}#{meta_description_list('過去の在籍バンド', past_names, room)}#{tail}"
  end

  # バンド索引（/units。issue #1957）。一覧ページはサイトの方向性の説明なので「ヴィジュアル系」と書く。
  # 索引に載るのはバンド（ユニット）だけで個人は載らないため「アーティスト」とは書かない。
  # ページの見出しの下にも同じ文を表示する。
  # 例:
  #   絞り込みなし「ヴィジュアル系バンドの索引。登録数は3,456組。…」
  #   絞り込みあり「「活動中」「2000年代」のヴィジュアル系バンドのうち、「〇〇」で探した一覧（3/3,456件）。…」
  # filtered_count は絞り込み後の件数（絞り込んでいなければ nil）。検索語とタグは、タグを先に書き検索語を加える。
  # 検索語は利用者の入力なので UNITS_INDEX_QUERY_MAX_LENGTH 字で切る。2ページ目以降はページ番号を添える
  def units_index_meta_description(total:, filtered_count: nil, query: nil, tag_names: [], page: 1)
    tail = '各バンドの歴史やメンバーの経歴、音源等を掲載。'
    page_note = "#{page}ページ目" if page > 1
    if filtered_count.nil?
      return "ヴィジュアル系バンドの索引。登録数は#{number_with_delimiter(total)}組" \
             "#{"（#{page_note}）" if page_note}。名前やよみがなで探せるほか、タグで絞り込めます。#{tail}"
    end

    counts = ["#{number_with_delimiter(filtered_count)}/#{number_with_delimiter(total)}件", page_note].compact.join('・')
    "#{units_index_meta_description_lead(query, tag_names)}（#{counts}）。#{tail}"
  end

  private

  # 「「活動中」のヴィジュアル系バンドのうち、「〇〇」で探した一覧」など
  def units_index_meta_description_lead(query, tag_names)
    subject = 'ヴィジュアル系バンド'
    tags = tag_names.map { |name| "「#{name}」" }.join.presence
    keyword = "「#{query.to_s.strip.truncate(UNITS_INDEX_QUERY_MAX_LENGTH)}」" if query.to_s.strip.present?
    if tags && keyword
      "#{tags}の#{subject}のうち、#{keyword}で探した一覧"
    elsif tags
      "#{tags}の#{subject}の一覧"
    elsif keyword
      "#{keyword}で探した#{subject}の一覧"
    else
      "#{subject}の一覧"
    end
  end

  # 「2012年結成、2018年解散の」。準備中・不明のユニットと、結成年・解散年がどちらも読めないユニットは何も書かない
  def unit_meta_description_period(unit, solo:)
    return '' unless unit.active? || unit.hiatus? || unit.disbanded?

    parts = []
    parts << "#{unit.founding_date.first(4)}年#{solo ? '活動開始' : '結成'}" if unit.founding_date
    parts << "#{unit.dissolution_date.first(4)}年#{solo ? '活動終了' : '解散'}" if unit.dissolution_date
    parts.any? ? "#{parts.join('、')}の" : ''
  end

  # 「〇〇（読み）は△△、□□他のボーカル・ギター。」「〇〇はボーカル。」。
  # 今の所属は、締めの文（tail）まで含めて上限の字数に収まる件数だけ並べる。名前が長く1件も収まらないときは
  # 先頭の1件だけ書く（はみ出した分は meta_description_text で切れる）
  def person_meta_description_head(person, current_names, tail)
    name = name_with_kana(person.name, person.name_kana)
    role = Array(person.parts).filter_map { |part| PART_NAMES[part] }.join('・').presence
    return "#{name}は#{role || 'アーティスト'}。" if current_names.empty?

    suffix = "の#{role || 'メンバー'}。"
    room = ApplicationHelper::META_DESCRIPTION_MAX_LENGTH - "#{name}は#{suffix}#{tail}".length
    unit_names = meta_description_names(current_names, room) || "#{current_names.first}#{'他' if current_names.size > 1}"
    "#{name}は#{unit_names}#{suffix}"
  end

  # 個人の経歴から求めた [今の所属, 過去の在籍バンド] の名前（issue #1945, #1951）。
  # - 今の所属は、経歴の最後の期間の項目。経歴が「→」で終わる人（その後どこにも在籍していない運用）と、
  #   引退した人は今の所属なしとし、最後の期間も過去の在籍バンドに含める
  # - 過去の在籍バンドは、それより前の期間を新しい順（末尾から）に並べる。今の所属と同じ名前は除き、
  #   同じ名前は新しい位置で1回だけ書く。名前は大文字・小文字を区別せずに比べる（"Sads" と "SADS" など）
  # - どちらも history_band_name で書く項目だけを対象にする。最後の期間に書く項目が無ければ今の所属なし
  #   （最後が {{category 個人/状況不明}} だけの場合など）。ただし死去した人は、最後に在籍したバンドのメンバーとして
  #   書くため、書く項目がある最後の期間を今の所属とする（最後が {{category 死去}} だけの場合など）
  def person_meta_description_memberships(person, history_items)
    timeline = history_items.map { |items| items.filter_map { |item| history_band_name(item) } }
    timeline = timeline.reject(&:empty?) if person.passed_away?
    ended = person.retirement? || person.history_ends_with_arrow?(person.old_history)
    current_names = ended ? [] : timeline.pop.to_a.uniq(&:downcase)
    current_keys = current_names.map(&:downcase)
    past_names = timeline.reverse.flatten.reject { |name| current_keys.include?(name.downcase) }.uniq(&:downcase)
    [current_names, past_names]
  end

  # 経歴の項目を今の所属・過去の在籍バンドとして書くときの名前。書かない項目は nil。
  # リンクのある項目（[[ユニット名]]・リンク）だけを対象にし、括弧で囲んだ項目（セッション・企画など）、
  # ソロ活動（[[ソロ|本人]]）、サポートとしての在籍は除く
  def history_band_name(item)
    return unless item[:old_key] || item[:internal_url] || item[:external_url]
    return if item[:unit_name].to_s.start_with?('(')
    return if [item[:unit_name], item[:part_and_name]].any? { |text| text.to_s.include?('サポート') }

    # 表示名に含まれる {{rb}} のルビ（<rt>）とタグを除く
    name = CGI.unescapeHTML(strip_tags(item[:unit_name].to_s.gsub(%r{<rt>.*?</rt>}m, '')).strip)
    name.presence unless name == 'ソロ'
  end

  # 「最終メンバーは〇〇、〇〇他。」。room 字に収まるところまで並べ、1つも収まらなければ書かない
  def meta_description_list(label, names, room)
    text = meta_description_names(names, room - "#{label}は。".length)
    text ? "#{label}は#{text}。" : ''
  end

  # 「〇〇、〇〇他」。room 字に収まるところまで並べる。1つも収まらなければ nil
  def meta_description_names(names, room)
    names.size.downto(1).each do |count|
      text = "#{names.first(count).join('、')}#{'他' if count < names.size}"
      return text if text.length <= room
    end
    nil
  end
end
