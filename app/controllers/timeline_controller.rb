# frozen_string_literal: true

class TimelineController < ApplicationController
  TARGET_TAG_NAMES = %w[メジャー メジャーで解散].freeze
  CACHE_KEY = 'timeline/major_units'
  CACHE_TTL = 1.hour

  # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity
  def index
    @timeline_data = Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
      units = Unit.kept
                  .joins(tag_index_items: :tag_index)
                  .where(tag_indices: { name: TARGET_TAG_NAMES })
                  .where.not(activity_period: nil)
                  .distinct
                  .preload(tag_index_items: :tag_index)
                  .to_a

      all_years = units.flat_map do |unit|
        unit.activity_periods.map { |p| parse_year(p.from) }
      end.compact

      year_min = all_years.min || Time.current.year
      year_max = Time.current.year

      # 活動開始年の昇順でソート（同年はかな順）
      units.sort_by! do |unit|
        earliest = unit.activity_periods.map { |p| parse_year(p.from) }.compact.min || 9999
        [earliest, unit.name_kana.to_s]
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

      # 「メジャーデビュー」Trend を収集し unit_id → [{year:, date:, title:}] のハッシュに変換
      unit_id_set = units.map(&:id).to_set
      debut_trends = Trend
                     .where('title LIKE ?', '%メジャーデビュー%')
                     .where(active: true)
                     .select(:id, :date, :title, :units)

      debut_markers = {}
      debut_trends.each do |trend|
        (trend.units || []).each do |u|
          uid = u['unit_id'].to_i
          next unless unit_id_set.include?(uid)

          (debut_markers[uid] ||= []) << { year: trend.date.year, date: trend.date.to_s, title: trend.title }
        end
      end

      { units:, year_min:, year_max:, debut_markers: }
    end

    @units          = @timeline_data[:units]
    @year_min       = @timeline_data[:year_min]
    @year_max       = @timeline_data[:year_max]
    @year_range     = (@year_min..@year_max).to_a
    @debut_markers  = @timeline_data[:debut_markers]
  end
  # rubocop:enable Metrics/AbcSize, Metrics/PerceivedComplexity

  private

  # 1970年未満は不正データとみなして nil を返す
  def parse_year(str)
    return nil if str.blank?

    str.to_s.split('/').first.to_i.then { |y| y >= 1970 ? y : nil }
  end
  helper_method :parse_year
end
