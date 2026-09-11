# frozen_string_literal: true

class LegacyRedirectsController < ApplicationController
  # Fixed legacy pages keyed by their EUC-JP decoded name (issue #925)
  SPECIAL_LEGACY_PAGES = {
    '索引' => '/units',
    '個人索引' => '/people'
  }.freeze
  YEARLY_TREND_PATTERN = %r{\A動向/(\d{4})\z}
  DAILY_CALENDAR_PATTERN = %r{\Aカレンダー/(\d{4})-(\d{1,2})-(\d{1,2})\z}
  WIKI_CGI_DATE_PATTERN = %r{\A(\d{4})/(\d{1,2})/(\d{1,2})\z}

  def show
    redirect_for_old_key(params[:old_key])
  end

  # 旧wiki.cgi宛のリクエストの救済（issue #1482）
  # ?page=XXX は .html と同様のold_key解決、?date=YYYY/MM/DD&action=DAY は
  # 日付ページへの転送のみ対応する（無理のない範囲での救済のため）
  def wiki_cgi
    if params[:page].present?
      redirect_for_old_key(params[:page])
      return
    end

    date = request.query_parameters['date']
    if date.present? && request.query_parameters['action'] == 'DAY' && (match = date.match(WIKI_CGI_DATE_PATTERN))
      redirect_to daily_path(year: match[1], month: match[2], day: match[3]), status: :moved_permanently
      return
    end

    render 'not_found', status: :not_found
  end

  def news_redirect
    trend = Trend.find_by(id: params[:id])
    if trend
      redirect_to trend_url(trend), status: :moved_permanently
    else
      render 'not_found', status: :not_found
    end
  end

  def item_redirect
    item = Item.kept.find_by(asin: params[:asin])
    if item
      redirect_to item_url(item), status: :moved_permanently
    else
      render 'not_found', status: :not_found
    end
  end

  private

  # old_key（.html の旧ページ名、またはwiki.cgiのpageパラメータ）から
  # 対応する新URLを解決してリダイレクトする
  def redirect_for_old_key(old_key)
    encoded_old_key = URI.encode_www_form_component(old_key.gsub('+', ' '))
    decoded_name = decode_euc_jp(old_key)

    # 固定の旧サイトページ（索引・年表・年別動向）はUnit/Personの検索より優先する。
    # 旧サイトの索引・一覧ページがUnitとして誤って取り込まれ、old_keyがこれらの
    # 名前と衝突しているデータが存在するため。
    if decoded_name && (special_redirect_path = special_legacy_redirect_path(decoded_name))
      redirect_to special_redirect_path, status: :moved_permanently
      return
    end

    # Try to find CustomPage by old_key（issue #1085）
    if (custom_page = CustomPage.published.find_by(old_key: old_key) ||
                      CustomPage.published.find_by(old_key: encoded_old_key))
      new_url = custom_page_url(custom_page.key)
      response.headers['Link'] = "<#{new_url}>; rel=\"canonical\""
      redirect_to new_url, status: :moved_permanently
      return
    end

    # Try to find Unit by old_key
    if (unit = Unit.find_by(old_key: old_key) || Unit.find_by(old_key: encoded_old_key) ||
               Unit.where('aliases @> ?', [{ old_key: old_key }].to_json).first ||
               Unit.where('aliases @> ?', [{ old_key: encoded_old_key }].to_json).first)
      new_url = profile_url(unit.key)
      response.headers['Link'] = "<#{new_url}>; rel=\"canonical\""
      redirect_to new_url, status: :moved_permanently
      return
    end

    # Fallback: Try to find Person by old_key
    if (person = Person.find_by(old_key: old_key) || Person.find_by(old_key: encoded_old_key) ||
                 Person.where('aliases @> ?', [{ old_key: old_key }].to_json).first ||
                 Person.where('aliases @> ?', [{ old_key: encoded_old_key }].to_json).first)
      new_url = profile_url(person.key)
      response.headers['Link'] = "<#{new_url}>; rel=\"canonical\""
      redirect_to new_url, status: :moved_permanently
      return
    end

    # If neither found, prepare data for 404 page with creation link
    @old_key = old_key
    @unit_name = decoded_name
    @not_found_query = decoded_name.presence || old_key

    render 'not_found', status: :not_found
  end

  # Try to decode old_key (EUC-JP) to UTF-8
  # Unescape first, then force encoding to EUC-JP and transcode to UTF-8
  def decode_euc_jp(old_key)
    URI.decode_www_form_component(old_key).force_encoding('EUC-JP').encode('UTF-8')
  rescue StandardError
    nil
  end

  def special_legacy_redirect_path(decoded_name)
    return SPECIAL_LEGACY_PAGES[decoded_name] if SPECIAL_LEGACY_PAGES.key?(decoded_name)
    return '/timeline' if decoded_name.start_with?('年表')

    if (match = decoded_name.match(DAILY_CALENDAR_PATTERN))
      return "/date/#{match[1]}/#{match[2]}/#{match[3]}"
    end

    (match = decoded_name.match(YEARLY_TREND_PATTERN)) && "/date/#{match[1]}"
  end
end
