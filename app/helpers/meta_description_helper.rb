# frozen_string_literal: true

# ページごとの meta description（検索結果のスニペット）を登録データから組み立てる（issue #1937）。
# 出力は layout の content_for(:description) 経由。160字への切り詰めは ApplicationHelper#meta_description_text が行う。
# ジャンル（ヴィジュアル系）はサイトの方向性であってユニット自体の分類ではないため書かない。
module MetaDescriptionHelper
  # ユニットのページ。例:
  #   「UnsraW（アンスロウ）は2012年結成、2018年解散のバンド。最終メンバーは〇〇、〇〇。バンドの歴史やメンバーの経歴、音源等を掲載。」
  # ソロは「アーティスト」とし、結成・解散を活動開始・活動終了に言い換え、メンバーは書かない。
  # 結成年やメンバーが無ければその部分を省く。
  def unit_meta_description(unit, snapshots: [])
    solo = unit.solo?
    noun = solo ? 'アーティスト' : 'バンド'
    sentences = ["#{name_with_kana(unit.name, unit.name_kana)}は#{unit_meta_description_period(unit, solo:)}#{noun}" \
                 "#{'（活動休止中）' if unit.status == 'freeze'}。"]
    members = solo ? [] : unit_json_ld_members(snapshots).pluck('name').compact_blank
    sentences << "#{unit.disbanded? ? '最終メンバー' : 'メンバー'}は#{members.join('、')}。" if members.any?
    sentences << (solo ? 'アーティストの歴史や経歴、音源等を掲載。' : 'バンドの歴史やメンバーの経歴、音源等を掲載。')
    sentences.join
  end

  private

  # 「2012年結成、2018年解散の」。準備中・不明のユニットと、結成年が読めないユニットは何も書かない
  def unit_meta_description_period(unit, solo:)
    return '' unless unit.status.in?(%w[active freeze disbanded])

    from = json_ld_partial_dates(unit.activity_periods.map(&:from)).min&.first(4)
    return '' unless from

    to = json_ld_partial_dates(unit.activity_periods.map(&:to)).max&.first(4) if unit.disbanded?
    parts = ["#{from}年#{solo ? '活動開始' : '結成'}"]
    parts << "#{to}年#{solo ? '活動終了' : '解散'}" if to
    "#{parts.join('、')}の"
  end
end
