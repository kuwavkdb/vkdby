# frozen_string_literal: true

# 検索語の表記ゆれを軽く吸収するための補助（issue #2042）。
# ヨミガナ（name_kana）はカタカナで登録されているため、ひらがなだけの検索語はカタカナにした語でも探す。
# 名前がひらがなのユニット・人物もあるので、置き換えずに元の語と両方で探す。
module SearchQuery
  # ひらがな（ぁ〜ゖ）・長音・空白だけからなり、ひらがなを1文字以上含む語
  HIRAGANA_ONLY = /\A(?=.*[ぁ-ゖ])[ぁ-ゖー ]+\z/

  module_function

  # 検索語と、それがひらがなだけならカタカナにした語を返す。
  # query は normalize_search_query 済みの検索語を渡す。
  def variants(query)
    return [query] unless HIRAGANA_ONLY.match?(query)

    [query, query.tr('ぁ-ゖ', 'ァ-ヶ')]
  end
end
