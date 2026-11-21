# frozen_string_literal: true

# Basic Information セクション内の label/value 1項目分を表示する。
# 項目ごとに薄い枠で囲み、見出しの横に値が収まれば1段、収まらなければ値だけを下の段に送って右寄せにする
# （issue #2071）。2列の枠で見出しと値を左右に並べると、年付きの誕生日など少し長い値の中身が折り返していたため。
# 横幅いっぱいの行（移行先・活動時期・タグ、会場の住所など）も同じ見た目にするため、クラスを定数で公開する
class BasicAttributeItemComponent < ViewComponent::Base
  with_collection_parameter :item

  # 枠線は付けず、薄い地の色だけで項目を区切る
  ITEM_CLASS = 'flex flex-wrap justify-between items-baseline gap-x-3 gap-y-1 min-w-0 rounded-md ' \
               'bg-zinc-50 dark:bg-zinc-800/50 px-2.5 py-2'
  LABEL_CLASS = 'text-xs font-semibold text-zinc-500 dark:text-zinc-400 whitespace-nowrap'
  # 値は縮めずにまるごと下の段へ送る（shrink-0）。枠より長い値は枠の幅で中身を折り返す（max-w-full）
  VALUE_PLACEMENT_CLASS = 'ml-auto max-w-full shrink-0 text-right'
  VALUE_CLASS = "#{VALUE_PLACEMENT_CLASS} text-[0.9375rem] font-bold text-zinc-900 dark:text-zinc-100".freeze
  # 2列のときに最後の1つだけが段に残らないよう、項目の数が奇数なら最後の項目を2列分の幅にする
  WIDE_CLASS = '@[20rem]:col-span-2'

  def initialize(item:, item_iteration: nil)
    super()
    @item = item
    @wide = item_iteration&.last? && item_iteration.size.odd?
  end

  def item_class
    @wide ? "#{ITEM_CLASS} #{WIDE_CLASS}" : ITEM_CLASS
  end
end
