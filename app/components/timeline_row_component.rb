# frozen_string_literal: true

class TimelineRowComponent < ViewComponent::Base
  with_collection_parameter :unit

  NAME_COL_W = 176

  PHENOMENON_COLORS = {
    'announcement' => '#e879f9',
    'formation' => '#22c55e',
    'first_live' => '#f97316',
    'finish' => '#ef4444',
    'pending' => '#71717a',
    'rename' => '#a78bfa',
    'suspend' => '#94a3b8',
    'restart' => '#06b6d4',
    'limited' => '#84cc16',
    'major_debut' => '#f59e0b',
    'live' => '#fb7185',
    'media' => '#3b82f6',
    'unknown' => '#71717a',
    'other' => '#71717a'
  }.freeze

  def initialize(unit:, year_min:, year_max:, trend_markers:)
    super()
    @unit          = unit
    @year_min      = year_min
    @year_max      = year_max
    @trend_markers = trend_markers
  end

  # バー領域の幅係数（年数）
  def chart_width_factor = @year_max - @year_min + 1

  # 最初の5年グリッドまでのオフセット係数（年数）
  def five_year_offset_factor = (5 - @year_min % 5) % 5

  # グリッド背景: CSS変数 --year-px に依存、1年グリッドは --year-grid-fine-alpha で制御
  def row_grid_style
    offset    = five_year_offset_factor
    five_year = 'repeating-linear-gradient(to right, transparent, transparent calc(var(--year-px) * 5 - 2px), ' \
                'rgba(113,113,122,0.35) calc(var(--year-px) * 5 - 2px), rgba(113,113,122,0.35) calc(var(--year-px) * 5))'
    one_year  = 'repeating-linear-gradient(to right, transparent, transparent calc(var(--year-px) - 1px), ' \
                'rgba(113,113,122,var(--year-grid-fine-alpha,0)) calc(var(--year-px) - 1px), ' \
                'rgba(113,113,122,var(--year-grid-fine-alpha,0)) var(--year-px))'
    "background-image: #{five_year}, #{one_year}; " \
    'background-size: calc(var(--year-px) * 5) 100%, var(--year-px) 100%; ' \
    "background-position: calc(var(--year-px) * #{offset}) 0, 0 0;"
  end

  def bar_color = '#3b82f6'
  def row_type  = 'major'

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

  # バー左端の係数（年数単位、year_px を乗じると px になる）
  def bar_left_factor(from_year, from_month = 1)
    months_from_start = (from_year - @year_min) * 12 + (from_month - 1)
    (months_from_start / 12.0).round(4)
  end

  # バー幅の係数（年数単位）
  def bar_width_factor(from_year, from_month, to_year, to_month)
    start_months = (from_year - @year_min) * 12 + (from_month - 1)
    end_months   = (to_year   - @year_min) * 12 + to_month
    factor = (end_months - start_months) / 12.0
    [factor, 0.5].max.round(4)
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

    { left: bar_left_factor(from_year_c, from_month), width: bar_width_factor(from_year_c, from_month, to_year_c, to_month) }
  end

  # マーカー位置の係数（年数単位）
  def marker_x_factor(marker)
    ((marker[:year] - @year_min) + ((marker[:month] || 1) - 1) / 12.0).round(4)
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
