# frozen_string_literal: true

# ページごとの meta description（検索結果のスニペット）を登録データから組み立てる（issue #1937）。
# 出力は layout の content_for(:description) 経由。長さの上限は ApplicationHelper::META_DESCRIPTION_MAX_LENGTH。
# ジャンル（ヴィジュアル系）はサイトの方向性であってユニット自体の分類ではないため書かない。
module MetaDescriptionHelper
  # ユニットのページ。例:
  #   「UnsraW（アンスロウ）は2012年結成、2018年解散のバンド。最終メンバーは〇〇、〇〇。バンドの歴史やメンバーの経歴、音源等を掲載。」
  # ソロは「アーティスト」とし、結成・解散を活動開始・活動終了に言い換え、メンバーは書かない。
  # 結成年・解散年やメンバーが無ければその部分を省く。
  # members は Unit#current_public_members の結果。上限の字数に収まる人数だけ並べ、残りは「ほか」とする
  # （締めの文が切れないようにするため）。
  def unit_meta_description(unit, members: [])
    solo = unit.solo?
    head = "#{name_with_kana(unit.name, unit.name_kana)}は#{unit_meta_description_period(unit, solo:)}" \
           "#{solo ? 'アーティスト' : 'バンド'}#{'（活動休止中）' if unit.hiatus?}。"
    tail = solo ? 'アーティストの歴史や経歴、音源等を掲載。' : 'バンドの歴史やメンバーの経歴、音源等を掲載。'
    names = solo ? [] : members.map(&:name).compact_blank
    room = ApplicationHelper::META_DESCRIPTION_MAX_LENGTH - head.length - tail.length
    "#{head}#{unit_meta_description_members(unit, names, room)}#{tail}"
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

  # 「最終メンバーは〇〇、〇〇ほか。」。room 字に収まるところまで並べ、1人も収まらなければ書かない。
  # 「最終」は解散年が確かなとき（Unit#dissolution_date があるとき）だけ付ける
  def unit_meta_description_members(unit, names, room)
    label = unit.dissolution_date ? '最終メンバー' : 'メンバー'
    names.size.downto(1).each do |count|
      text = "#{label}は#{names.first(count).join('、')}#{'ほか' if count < names.size}。"
      return text if text.length <= room
    end
    ''
  end
end
