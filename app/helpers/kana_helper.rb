# frozen_string_literal: true

module KanaHelper
  # 名前とヨミガナが同じ文字列ならヨミガナは冗長なので出さない（issue #1730）
  def show_kana?(name, kana)
    kana.present? && kana.strip != name.to_s.strip
  end

  # titleタグ等で使う「名前（ヨミガナ）」形式の表示名
  def name_with_kana(name, kana)
    show_kana?(name, kana) ? "#{name}（#{kana}）" : name
  end
end
