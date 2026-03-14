# frozen_string_literal: true

class TimelineController < ApplicationController
  TARGET_TAG_NAMES = ['メジャー', 'メジャーで解散'].freeze
  CACHE_KEY = 'timeline/major_units'
  CACHE_TTL = 1.hour

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

      { units:, year_min:, year_max: }
    end

    @units     = @timeline_data[:units]
    @year_min  = @timeline_data[:year_min]
    @year_max  = @timeline_data[:year_max]
    @year_range = (@year_min..@year_max).to_a
  end

  private

  # 1970年未満は不正データとみなして nil を返す
  def parse_year(str)
    return nil if str.blank?

    str.to_s.split('/').first.to_i.then { |y| y >= 1970 ? y : nil }
  end
  helper_method :parse_year
end
