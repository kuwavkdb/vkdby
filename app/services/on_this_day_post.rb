# frozen_string_literal: true

# 「今日は何の日？」の紹介ポスト文（OnThisDayPostBuilder の結果、issue #1742）。
# kind は :trends（出来事）か :birthdays（誕生日、issue #1753）
OnThisDayPost = Struct.new(:kind, :date, :text, :page_url, keyword_init: true) do
  # X の数え方での文字数（XPostLength）
  def weighted_length
    XPostLength.count(text)
  end

  # タップすると投稿文が入力済みの X の投稿画面が開くURL
  def intent_url
    "https://x.com/intent/post?text=#{ERB::Util.url_encode(text)}"
  end
end
