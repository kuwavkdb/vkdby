# frozen_string_literal: true

# 検索エンジン向けの sitemap.xml を動的に生成する（issue #1491）。
# 対象URLはリクエストの都度DBから組み立てるが、毎回全件クエリすると
# 重いため Rails.cache に一定時間キャッシュする。
class SitemapsController < ApplicationController
  CACHE_EXPIRES_IN = 6.hours

  # 日付ページ（yearly/monthly/daily）は年月日の組み合わせが膨大なため、
  # 対象範囲を絞り込む（issue #1491 コメントでの合意）。
  DATE_PAGES_START_YEAR = 1980
  DAILY_PAGES_LOOKBACK = 1.year

  def show
    xml = Rails.cache.fetch('sitemap.xml', expires_in: CACHE_EXPIRES_IN) do
      render_to_string(template: 'sitemaps/show', formats: [:xml], locals: { urls: build_urls })
    end
    render xml: xml
  end

  private

  def build_urls
    urls = static_urls + index_group_urls + profile_urls + trend_urls + item_urls + custom_page_urls +
           yearly_urls + monthly_urls + daily_urls
    # Unit/Personのkeyがまれに重複しており(profiles#showはUnit優先で解決する)、
    # 同一URLが2件出力されることがあるため重複除去する。profile_urlsはUnitを
    # Personより先に列挙しているため、先勝ちのuniqでUnit優先の結果と一致する。
    urls.uniq { |url| url[:loc] }
  end

  def static_urls
    [
      { loc: root_url },
      { loc: people_url },
      { loc: units_url },
      { loc: trends_url },
      { loc: items_url },
      { loc: timeline_url },
      { loc: indices_groups_url }
    ]
  end

  def index_group_urls
    IndexGroup.active.pluck(:id).map { |id| { loc: indices_group_url(id) } }
  end

  # Unit/Person: kept かつ published（タグによる非公開指定なし）のみ対象。
  # discard済み・destination_keyありのリダイレクトスタブ（KeyChangeable#redirect_source?）は
  # 常にdiscarded状態なので kept スコープの時点で除外される。
  def profile_urls
    Unit.kept.published.pluck(:key, :updated_at).map { |key, updated_at| { loc: profile_url(key), lastmod: updated_at } } +
      Person.kept.published.pluck(:key, :updated_at).map { |key, updated_at| { loc: profile_url(key), lastmod: updated_at } }
  end

  # Trendには非公開の仕組みがないため全件対象
  def trend_urls
    Trend.pluck(:id, :updated_at).map { |id, updated_at| { loc: trend_url(id), lastmod: updated_at } }
  end

  def item_urls
    Item.kept.pluck(:id, :updated_at).map { |id, updated_at| { loc: item_url(id), lastmod: updated_at } }
  end

  # non_system_pages: index/footer/top_message/IPブロックリスト用ページを除外
  # （indexはroot('/')と同一ページのため二重計上しない）
  def custom_page_urls
    CustomPage.published.non_system_pages.pluck(:key, :updated_at).map do |key, updated_at|
      { loc: custom_page_url(key), lastmod: updated_at }
    end
  end

  def yearly_urls
    (DATE_PAGES_START_YEAR..Date.current.year).map { |year| { loc: yearly_url(year:) } }
  end

  def monthly_urls
    (DATE_PAGES_START_YEAR..Date.current.year).flat_map do |year|
      last_month = year == Date.current.year ? Date.current.month : 12
      (1..last_month).map { |month| { loc: monthly_url(year:, month:) } }
    end
  end

  # 誕生日データ（Person#birthday_on）は在籍者数が多く、直近1年365日すべてに
  # 該当者が存在してしまい絞り込みの意味がなくなるため判定基準に含めない。
  # Trend/Itemの実データが存在する日のみを対象とする。
  def daily_urls
    range = (Date.current - DAILY_PAGES_LOOKBACK)..Date.current
    trend_dates = Trend.where(date: range, day_unknown: false, month_unknown: false).distinct.pluck(:date)
    item_dates = Item.where(release_date: range).distinct.pluck(:release_date)
    (trend_dates + item_dates).uniq.map { |date| { loc: daily_url(year: date.year, month: date.month, day: date.day) } }
  end
end
