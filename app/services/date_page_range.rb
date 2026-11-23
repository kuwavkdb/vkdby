# frozen_string_literal: true

# 日付ページ（/date/:year 以下の年別・月別・日別ページ）で扱える年の範囲。
# コントローラーの年の妥当性判定と、ほかの画面から年別ページへリンクするかどうかの判断で同じ値を使う（issue #2101）
module DatePageRange
  MIN_YEAR = 1970
  # 公開予定の動向など、先の年も少しだけ扱う
  FUTURE_YEARS = 10

  def self.cover?(year)
    year >= MIN_YEAR && year <= Date.current.year + FUTURE_YEARS
  end
end
