# frozen_string_literal: true

# ページごとの meta description（検索結果のスニペット）を登録データから組み立てる（issue #1937, #1938）。
# 出力は layout の content_for(:description) 経由。長さの上限は ApplicationHelper::META_DESCRIPTION_MAX_LENGTH。
# ジャンル（ヴィジュアル系）はサイトの方向性であってユニット自体の分類ではないため書かない。
module MetaDescriptionHelper
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
  # 引退した人は今の所属が無いものとし、所属していたユニットはすべて「過去の在籍バンド」に並べる
  # （Person#current_units が空を返す）。死去した人は、最後に在籍したバンドのメンバーとして書く。
  # 状態・誕生日・出身地は書かない。current_units は Person#current_units の結果。
  # 今の所属・過去の在籍バンドとも、上限の字数に収まる件数だけ並べ、残りは「他」とする
  def person_meta_description(person, current_units: [])
    tail = '経歴や在籍バンド、音源等を掲載。'
    head = person_meta_description_head(person, current_units, tail)
    room = ApplicationHelper::META_DESCRIPTION_MAX_LENGTH - head.length - tail.length
    past_names = person.past_units(excluding: current_units).map(&:name).compact_blank
    "#{head}#{meta_description_list('過去の在籍バンド', past_names, room)}#{tail}"
  end

  private

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
  def person_meta_description_head(person, units, tail)
    name = name_with_kana(person.name, person.name_kana)
    role = Array(person.parts).filter_map { |part| PART_NAMES[part] }.join('・').presence
    return "#{name}は#{role || 'アーティスト'}。" if units.empty?

    suffix = "の#{role || 'メンバー'}。"
    room = ApplicationHelper::META_DESCRIPTION_MAX_LENGTH - "#{name}は#{suffix}#{tail}".length
    unit_names = meta_description_names(units.map(&:name), room) || "#{units.first.name}#{'他' if units.size > 1}"
    "#{name}は#{unit_names}#{suffix}"
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
