# frozen_string_literal: true

# 経歴（Person#old_history など）の表示まわり
module HistoryHelper
  # 経歴に書かれた注記のうち、表示では言い回しをそろえるもの（issue #1992）。
  # 「現在」がいつかわからないため、状況のわからない人は「活動状況不明」で統一する
  HISTORY_NOTE_LABELS = {
    '個人/状況不明' => WikiParser::HISTORY_UNKNOWN_LABEL,
    '個人状況不明' => WikiParser::HISTORY_UNKNOWN_LABEL
  }.freeze

  # 経歴の注記（{{fn}}・{{category}}、ステータスから補った状態など）のバッジ。
  # 個人ページ・バンドページ・個人カードで同じ見た目にする。背景との境目がわかるよう枠線を付け、
  # 文字色はライト・ダークとも背景との差をとる。名前の無い項目（{{category 引退}} だけの項目など）では
  # 先頭のバッジの左の余白を付けない
  def history_note_badge(note)
    tag.span(HISTORY_NOTE_LABELS.fetch(note, note),
             class: 'inline-block ml-2 first:ml-0 px-2 py-0.5 rounded text-xs font-medium leading-4 ' \
                    'text-zinc-700 bg-zinc-100 ring-1 ring-inset ring-zinc-300 ' \
                    'dark:text-zinc-200 dark:bg-zinc-800 dark:ring-zinc-600')
  end
end
