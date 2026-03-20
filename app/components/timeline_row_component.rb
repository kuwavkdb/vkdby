# frozen_string_literal: true

class TimelineRowComponent < ViewComponent::Base
  with_collection_parameter :unit

  DEFAULT_YEAR_PX = 24
  NAME_COL_W      = 176

  PHENOMENON_COLORS = {
    'announcement' => '#e879f9',
    'formation'    => '#22c55e',
    'first_live'   => '#f97316',
    'finish'       => '#ef4444',
    'pending'      => '#71717a',
    'rename'       => '#a78bfa',
    'suspend'      => '#94a3b8',
    'restart'      => '#06b6d4',
    'limited'      => '#84cc16',
    'major_debut'  => '#f59e0b',
    'live'         => '#fb7185',
    'media'        => '#3b82f6',
    'unknown'      => '#71717a',
    'other'        => '#71717a'
  }.freeze

  def initialize(unit:, year_min:, year_max:, trend_markers:, year_px: DEFAULT_YEAR_PX)
    super()
    @unit          = unit
    @year_min      = year_min
    @year_max      = year_max
    @trend_markers = trend_markers
    @year_px       = year_px
  end

  def chart_width      = (@year_max - @year_min + 1) * @year_px
  def grid_span        = @year_px * 5
  def five_year_offset = (5 - @year_min % 5) % 5 * @year_px

  def row_grid_style
    five_year = "repeating-linear-gradient(to right, transparent, transparent #{grid_span - 2}px, " \
                "rgba(113,113,122,0.35) #{grid_span - 2}px, rgba(113,113,122,0.35) #{grid_span}px)"

    return "background-image: #{five_year}; background-size: #{grid_span}px 100%; background-position: #{five_year_offset}px 0;" unless @year_px > 24

    one_year = "repeating-linear-gradient(to right, transparent, transparent #{@year_px - 1}px, " \
               "rgba(113,113,122,0.15) #{@year_px - 1}px, rgba(113,113,122,0.15) #{@year_px}px)"
    "background-image: #{five_year}, #{one_year}; " \
    "background-size: #{grid_span}px 100%, #{@year_px}px 100%; " \
    "background-position: #{five_year_offset}px 0, 0 0;"
  end

  def tag_names = @unit.tag_index_items.map { |ti| ti.tag_index.name }
  def major_disbanded? = tag_names.include?('メジャーで解散')
  def bar_color      = major_disbanded? ? '#a855f7' : '#3b82f6'
  def row_type       = major_disbanded? ? 'major-disbanded' : 'major'

  def earliest_year
    @unit.activity_periods.filter_map do |p|
      y = parse_year(p.from)
      y + (parse_month(p.from) - 1) / 12.0 if y
    end.min || 9999
  end

  def markers_for_unit
    @trend_markers[@unit.id] || []
  end

  def marker_color(phenomenon)
    PHENOMENON_COLORS.fetch(phenomenon.to_s, '#71717a')
  end

  def major_debut_marker?(marker)
    marker[:phenomenon].to_s == 'major_debut'
  end

  def bar_left(from_year, from_month = 1)
    months_from_start = (from_year - @year_min) * 12 + (from_month - 1)
    (months_from_start * @year_px / 12.0).round(2)
  end

  def bar_width(from_year, from_month, to_year, to_month)
    start_months = (from_year - @year_min) * 12 + (from_month - 1)
    end_months   = (to_year   - @year_min) * 12 + to_month
    width = (end_months - start_months) * @year_px / 12.0
    [width, @year_px / 2.0].max.round(2)
  end

  def bar_dimensions(period)
    from_year = parse_year(period.from)
    return nil unless from_year

    from_month  = parse_month(period.from)
    to_year     = parse_year(period.to) || @year_max
    to_month    = period.to.present? ? parse_month(period.to) : 12

    from_year_c = clamp_year(from_year, @year_min, @year_max)
    to_year_c   = clamp_year(to_year,   @year_min, @year_max)
    from_month  = 1  if from_year_c > from_year
    to_month    = 12 if to_year_c < to_year
    return nil if from_year_c > to_year_c

    { left: bar_left(from_year_c, from_month), width: bar_width(from_year_c, from_month, to_year_c, to_month) }
  end

  def marker_x(marker)
    (@year_min.zero? ? 0 : (marker[:year] - @year_min)) * @year_px +
      ((marker[:month] || 1) - 1) * @year_px / 12
  end

  def clamp_year(year, min, max) = [[year, min].max, max].min

  def parse_year(str)
    return nil if str.blank?

    str.to_s.split('/').first.to_i.then { |y| y >= 1970 ? y : nil }
  end

  def parse_month(str)
    return 1 if str.blank?

    parts = str.to_s.split('/')
    parts.length >= 2 ? parts[1].to_i.clamp(1, 12) : 1
  end
end
