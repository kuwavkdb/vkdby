# frozen_string_literal: true

class ItemsController < ApplicationController
  def index
    dates = Item.pluck(:release_date)
    @year_counts = dates.map(&:year).tally
    @years = @year_counts.keys.sort.reverse

    scope = Item.all.order(release_date: :desc)

    if params[:year].present?
      year = params[:year].to_i
      month = params[:month].presence&.to_i

      target_dates = dates.select { |d| d.year == year }
      @month_counts = target_dates.map(&:month).tally
      @months = @month_counts.keys.sort.reverse

      start_date = Date.new(year, month || 1, 1)
      end_date = month ? start_date.end_of_month : start_date.end_of_year

      scope = scope.where(release_date: start_date..end_date)
    end

    @pagy, @items = pagy(scope, limit: 20)
  end
end
