# frozen_string_literal: true

class MonthlyCalendarComponent < ViewComponent::Base
  def initialize(date:, daily_trend_counts:)
    super()
    @date = date
    @daily_trend_counts = daily_trend_counts
    @today = Date.today
  end

  def render?
    @date.present?
  end

  def calendar_weeks
    start_date = @date.beginning_of_month
    end_date = @date.end_of_month

    first_wday = start_date.wday
    calendar_start = start_date - first_wday.days

    last_wday = end_date.wday
    days_to_add = 6 - last_wday
    calendar_end = end_date + days_to_add.days

    (calendar_start..calendar_end).to_a.each_slice(7).to_a
  end

  def current_month?(date)
    date.year == @date.year && date.month == @date.month
  end

  def today?(date)
    date == @today
  end

  def trend_count(date)
    return 0 unless current_month?(date)

    @daily_trend_counts[date.day] || 0
  end
end
