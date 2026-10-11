# frozen_string_literal: true

# 検索の表記ゆれを吸収するための正規化（issue #1842）。
# 登録されている名前（search_text 列、SearchTextable）と検索語の両方に同じルールをかけて比べる。
#
# - NFKC（全角英数字→半角、半角カナ→全角など）
# - 英字は小文字にそろえる
# - ひらがなはカタカナにそろえる（「でぃる」でも「ディル」に当たる）
# - 「ヴァ・ヴィ・ヴ・ヴェ・ヴォ」はバ行にそろえる
# - 長音記号（ー・〜）、空白、記号は取り除く（「direngrey」でも「DIR EN GREY」に当たる）
module SearchNormalizer
  VU_TO_BA = { 'ヴァ' => 'バ', 'ヴィ' => 'ビ', 'ヴェ' => 'ベ', 'ヴォ' => 'ボ', 'ヴ' => 'ブ' }.freeze
  VU_PATTERN = Regexp.union(VU_TO_BA.keys)

  module_function

  def normalize(text)
    text.to_s.unicode_normalize(:nfkc).downcase
        .tr('ぁ-ゖ', 'ァ-ヶ')
        .gsub(VU_PATTERN, VU_TO_BA)
        .gsub(/[ー〜～]/, '')
        .gsub(/[^\p{L}\p{N}]/, '')
  end

  # search_text 列に入れる文字列。名前ごとに正規化して空白でつなぐ。
  # 正規化した検索語には空白が含まれないため、2つの名前にまたがって一致することはない。
  def join(texts)
    texts.map { |text| normalize(text) }.compact_blank.uniq.join(' ')
  end

  # 検索語を空白で区切った語の配列（語ごとの AND 検索に使う）
  def words(query)
    query.to_s.unicode_normalize(:nfkc).split(/[[:space:]]+/).compact_blank
  end
end
