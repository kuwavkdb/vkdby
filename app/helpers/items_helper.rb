# frozen_string_literal: true

require 'cgi'

module ItemsHelper
  AMAZON_IMAGE_CDN = %r{https?://(?:[a-z0-9-]+\.)?(?:images-amazon\.com|m\.media-amazon\.com)/}i

  def amazon_image?(url)
    url.present? && AMAZON_IMAGE_CDN.match?(url)
  end

  def amazon_image_url(url, size)
    url.sub(/(\._[A-Z][A-Z0-9_]*_)?(\.(jpe?g|png|gif|webp))$/i) { "._SL#{size}_#{::Regexp.last_match(2)}" }
  end

  # 購入リンクのラベル。ASINが無いアイテムはAmazon以外での販売なので汎用のラベルにする（issue #1820）
  # with_domain: true のときは「販売ページ（ドメイン）で購入」とリンク先のドメインを示す（アイテムページ用）
  def item_purchase_label(item, amazon_label: 'Amazonで購入', with_domain: false)
    return amazon_label if item.asin.present?

    domain = purchase_link_domain(item.display_link_url) if with_domain
    domain ? "販売ページ（#{domain}）で購入" : '販売サイト で購入'
  end

  # 購入リンクの配色。Amazon・TOWER RECORDS・Yahoo!のボタンと見分けられるよう、販売サイトはtealにする
  def item_purchase_color_class(item)
    item.asin.present? ? 'bg-amber-500 hover:bg-amber-600 text-black' : 'bg-teal-700 hover:bg-teal-800 text-white'
  end

  # アーティストのプロフィールページへのパスを生成
  # 優先順位: key > old_key。どちらも無い(名前のみの)アーティストはページが存在しないためリンクにしない
  def artist_profile_path(artist_data)
    if artist_data['key'].present?
      "/#{artist_data['key']}"
    elsif artist_data['old_key'].present?
      "/#{artist_data['old_key']}.html"
    end
  end

  # アーティストで絞り込んだItem#indexへのパスを生成
  # 優先順位: key > old_key。どちらも無い(名前のみの)アーティストは絞り込み対象を一意に特定できないためリンクにしない
  def artist_items_path(artist_data)
    if artist_data['key'].present?
      items_path(key: artist_data['key'])
    elsif artist_data['old_key'].present?
      items_path(old_key: artist_data['old_key'])
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

  private

  # 購入リンクのドメイン（先頭の www. は省く）。URLとして解釈できなければnil
  def purchase_link_domain(url)
    host = URI.parse(url.to_s).host
    host.presence&.delete_prefix('www.')
  rescue URI::InvalidURIError
    nil
  end
end
