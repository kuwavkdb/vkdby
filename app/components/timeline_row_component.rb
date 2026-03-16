# frozen_string_literal: true

class TimelineRowComponent < ViewComponent::Base
  with_collection_parameter :unit

  DEFAULT_YEAR_PX = 24
  NAME_COL_W      = 176

  def initialize(unit:, year_min:, year_max:, debut_markers:, year_px: DEFAULT_YEAR_PX)
    super()
    @unit          = unit
    @year_min      = year_min
    @year_max      = year_max
    @debut_markers = debut_markers
    @year_px       = year_px
  end

  def chart_width      = (@year_max - @year_min + 1) * @year_px
  def grid_span        = @year_px * 5
  def five_year_offset = (5 - @year_min % 5) % 5 * @year_px

  def row_grid_style
    gradient = "repeating-linear-gradient(to right, transparent, transparent #{grid_span - 2}px, " \
               "rgba(113,113,122,0.35) #{grid_span - 2}px, rgba(113,113,122,0.35) #{grid_span}px)"
    "background-image: #{gradient}; background-size: #{grid_span}px 100%; background-position: #{five_year_offset}px 0;"
  end

  def tag_names = @unit.tag_index_items.map { |ti| ti.tag_index.name }
  def major_disbanded? = tag_names.include?('メジャーで解散')
  def bar_color      = major_disbanded? ? '#a855f7' : '#3b82f6'
  def row_type       = major_disbanded? ? 'major-disbanded' : 'major'

  def earliest_year
    @unit.activity_periods.filter_map { |p| parse_year(p.from) }.min || 9999
  end

  def markers_for_unit
    @debut_markers[@unit.id] || []
  end

  def bar_left(from_year)            = (from_year - @year_min) * @year_px
  def bar_width(from_year, to_year)  = [((to_year - from_year + 1) * @year_px), @year_px / 2].max

  def marker_x(marker)
    (@year_min.zero? ? 0 : (marker[:year] - @year_min)) * @year_px +
      ((marker[:month] || 1) - 1) * @year_px / 12
  end

  def debut_marker?(marker)
    marker[:debut] || marker[:title].to_s.include?('メジャーデビュー')
  end

  def clamp_year(year, min, max) = [[year, min].max, max].min

  def parse_year(str)
    return nil if str.blank?

    str.to_s.split('/').first.to_i.then { |y| y >= 1970 ? y : nil }
  end
end
