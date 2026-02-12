# frozen_string_literal: true

require 'cgi'

module ItemsHelper
  # アーティストのプロフィールページへのパスを生成
  # 優先順位: key > old_key > name(EUCエンコード)
  def artist_profile_path(artist_data)
    if artist_data['key'].present?
      "/#{artist_data['key']}"
    elsif artist_data['old_key'].present?
      "/#{artist_data['old_key']}.html"
    elsif artist_data['name'].present?
      # nameをEUC-JPでURLエンコードしてold_key形式として扱う
      encoded_name = ERB::Util.url_encode(artist_data['name'].encode('EUC-JP'))
      "/#{encoded_name}.html"
    end
  end

  # Tower Records OnlineのValueCommerceアフィリエイトトラッキング付き検索URL
  def tower_records_search_url(item)
    artist_names = item.artists.map { |a| a['name'] }.join(' ')
    # 商品名から半角カッコで括られた部分を除去
    title_without_parens = item.title.gsub(/\([^)]*\)/, '').strip
    search_query = "#{artist_names} #{title_without_parens}"
    # Perlの_url_encodeと同じ方式: 空白を+に、その他の記号を%XXに変換
    encoded_query = CGI.escape(search_query).gsub('%20', '+')

    # vc_urlパラメータには事前エンコード済みのbase URLを使用
    'http://ck.jp.ap.valuecommerce.com/servlet/referral?' \
      'sid=2143338&pid=881339479' \
      "&vc_url=http%3A%2F%2Ftower.jp%2Fsearch%2Fitem%2F#{encoded_query}" \
      '&vcpub=0.621812' \
      '&vcid=rwD6qes5X5jI5Dj1P-9SdUVI-jmvF99T6IToXR9ObmKVYSSEULJITZ2qOsxq7YYz' \
      '&isec=1770829360'
  end

  # YahooショッピングのValueCommerceアフィリエイトトラッキング付き検索URL
  def yahoo_shopping_search_url(item)
    artist_names = item.artists.map { |a| a['name'] }.join(' ')
    search_query = "#{artist_names} #{item.title}(CD+DVD)"
    encoded_query = ERB::Util.url_encode(search_query)
    search_url = "https://shopping.yahoo.co.jp/search?p=#{encoded_query}"

    'https://dalr.valuecommerce.com/dck/bcddbb148c?' \
      'pid=887036272&sid=2143338&aid=2840499&mid=2201292' \
      '&ub=aYpzZgAI7NeZ2Q0sCooBbQqKC%2FAgPQ%3D%3D' \
      '&rid=aYyM8gAAoxaZ2Q0sCooAHwqKCJSeiA' \
      '&isec=698c8cf2' \
      "&vcurl=#{ERB::Util.url_encode(search_url)}"
  end
end
