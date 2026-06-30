# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class TimelineController < ApplicationController
  CACHE_KEY = 'timeline/major_units/v5'
  CACHE_TTL = 1.hour

  VALID_ZOOMS = { '2' => 48 }.freeze
  DEFAULT_YEAR_PX = 24

  # Unit の全属性を持つ AR オブジェクトをキャッシュ・保持するとメモリを圧迫するため、
  # タイムライン表示に必要な属性のみを持つ軽量な値オブジェクトとして扱う。
  TimelineUnit = Struct.new(:id, :name, :key, :name_kana, :activity_period, keyword_init: true) do
    def activity_periods
      (activity_period || []).map { |h| OpenStruct.new(h) }
    end
  end

  # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity
  def index
    @year_px = VALID_ZOOMS.fetch(params[:zoom].to_s, DEFAULT_YEAR_PX)
    @zoom    = @year_px == DEFAULT_YEAR_PX ? '1' : params[:zoom]

    @timeline_data = Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
      major_debut_unit_ids = Trend
                             .where(unit_phenomenon: :major_debut, active: true)
                             .pluck(:units)
                             .flat_map { |arr| Array(arr).map { |u| u['unit_id'].to_i } }
                             .uniq

      units = Unit.kept
                  .where(id: major_debut_unit_ids)
                  .where.not(activity_period: nil)
                  .distinct
                  .pluck(:id, :name, :key, :name_kana, :activity_period)
                  .map { |id, name, key, name_kana, activity_period| TimelineUnit.new(id:, name:, key:, name_kana:, activity_period:) }

      all_years = units.flat_map do |unit|
        unit.activity_periods.map { |p| parse_year(p.from) }
      end.compact

      year_min = all_years.min || Time.current.year
      year_max = Time.current.year

      # 活動開始年月の昇順でソート（同年月はかな順）
      units.sort_by! do |unit|
        earliest = unit.activity_periods.filter_map do |p|
          y = parse_year(p.from)
          [y, parse_month(p.from)] if y
        end.min || [9999, 1]
        [*earliest, unit.name_kana.to_s]
      end

      # 有効なバーが1本も描けないユニットを除外
      units.select! do |unit|
        unit.activity_periods.any? do |p|
          fy = parse_year(p.from)
          next false unless fy

          ty = parse_year(p.to) || year_max
          [fy, year_min].max <= [ty, year_max].min
        end
      end

      # unit_phenomenon を持つ Trend を収集し unit_id → [{year:, date:, title:, phenomenon:}] のハッシュに変換
      # GIN インデックス（units jsonb）を利用して表示対象ユニットの Trend のみ DB で絞り込む
      unit_id_set = units.map(&:id).to_set
      unit_id_array = unit_id_set.to_a
      unit_trends = Trend
                    .where.not(unit_phenomenon: nil)
                    .where(active: true)
                    .where(
                      'units @> ANY(ARRAY[?]::jsonb[])',
                      unit_id_array.map { |uid| [{ unit_id: uid }].to_json }
                    )
                    .select(:id, :date, :title, :units, :unit_phenomenon)

      trend_markers = {}
      unit_trends.each do |trend|
        (trend.units || []).each do |u|
          uid = u['unit_id'].to_i
          next unless unit_id_set.include?(uid)

          (trend_markers[uid] ||= []) << {
            id: trend.id, year: trend.date.year, month: trend.date.month, date: trend.date.to_s,
            title: strip_wiki_links(trend.title), phenomenon: trend.unit_phenomenon
          }
        end
      end

      { units: units.map(&:to_h), year_min:, year_max:, trend_markers: }
    end

    @units          = @timeline_data[:units].map { |attrs| TimelineUnit.new(**attrs) }
    @year_min       = @timeline_data[:year_min]
    @year_max       = @timeline_data[:year_max]
    @year_range     = (@year_min..@year_max).to_a
    @trend_markers  = @timeline_data[:trend_markers]
  end
  # rubocop:enable Metrics/AbcSize, Metrics/PerceivedComplexity

  def unit
    cached = Rails.cache.read(CACHE_KEY)
    year_min = params[:ym].to_i.positive? ? params[:ym].to_i : (cached&.dig(:year_min) || Time.current.year)
    year_max = cached&.dig(:year_max) || Time.current.year

    unit = Unit.kept.find_by(key: params[:key])
    return head :not_found unless unit

    markers = []
    Trend.where(active: true)
         .where.not(unit_phenomenon: nil)
         .where('units @> ?', [{ unit_id: unit.id }].to_json)
         .select(:id, :date, :title, :units, :unit_phenomenon).each do |trend|
      (trend.units || []).each do |u|
        next unless u['unit_id'].to_i == unit.id

        markers << {
          id: trend.id, year: trend.date.year, month: trend.date.month, date: trend.date.to_s,
          title: strip_wiki_links(trend.title), phenomenon: trend.unit_phenomenon
        }
      end
    end

    component = TimelineRowComponent.new(
      unit: unit, year_min: year_min, year_max: year_max,
      trend_markers: { unit.id => markers }
    )
    render component, layout: false
  end

  def units
    keys = Array(params[:keys]).first(20)
    return render json: {} if keys.empty?

    cached = Rails.cache.read(CACHE_KEY)
    year_min = params[:ym].to_i.positive? ? params[:ym].to_i : (cached&.dig(:year_min) || Time.current.year)
    year_max = cached&.dig(:year_max) || Time.current.year

    units = Unit.kept.where(key: keys)
    return render json: {} if units.empty?

    trend_markers = fetch_trend_markers(units.map(&:id))

    result = {}
    units.each do |u|
      component = TimelineRowComponent.new(
        unit: u, year_min: year_min, year_max: year_max,
        trend_markers: { u.id => trend_markers[u.id] || [] }
      )
      result[u.key] = render_to_string(component, layout: false)
    end

    render json: result
  end

  private

  def fetch_trend_markers(unit_ids)
    unit_id_set = unit_ids.to_set
    markers = {}
    Trend
      .where(active: true)
      .where.not(unit_phenomenon: nil)
      .where(
        'units @> ANY(ARRAY[?]::jsonb[])',
        unit_ids.map { |uid| [{ unit_id: uid }].to_json }
      )
      .select(:id, :date, :title, :units, :unit_phenomenon)
      .each do |trend|
        (trend.units || []).each do |u|
          uid = u['unit_id'].to_i
          next unless unit_id_set.include?(uid)

          (markers[uid] ||= []) << {
            id: trend.id, year: trend.date.year, month: trend.date.month, date: trend.date.to_s,
            title: strip_wiki_links(trend.title), phenomenon: trend.unit_phenomenon
          }
        end
      end
    markers
  end

  # Wiki記法リンクをラベルテキストに置換 [[A|B]]→A, [A|B]→A, [[A]]→A
  def strip_wiki_links(str)
    str.gsub(/\[{1,2}([^|\]]+)(?:\|[^\]]+)?\]{1,2}/, '\1')
  end
  helper_method :strip_wiki_links

  # 1970年未満は不正データとみなして nil を返す
  def parse_year(str)
    return nil if str.blank?

    str.to_s.split('/').first.to_i.then { |y| y >= 1970 ? y : nil }
  end
  helper_method :parse_year

  def parse_month(str)
    return 1 if str.blank?

    parts = str.to_s.split('/')
    parts.length >= 2 ? parts[1].to_i.clamp(1, 12) : 1
  end
  helper_method :parse_month
end
# rubocop:enable Metrics/ClassLength
