# frozen_string_literal: true

class DailyController < ApplicationController
  def show
    @date = parse_date_params
    return redirect_to root_path, alert: '日付の形式が正しくありません' unless @date

    @trends = Trend.on_date(@date).order(created_at: :desc)
    @birthdays = Person.birthday_on(@date).where(status: %i[active hiatus]).order(name_kana: :asc)
    @releases = Item.released_on(@date).order(created_at: :desc)

    # Load related units for trends
    all_unit_ids = @trends.flat_map { |t| t.units&.map { |u| u['unit_id'] } }.compact.uniq
    @related_units = Unit.where(id: all_unit_ids).index_by(&:id)
  end

  private

  def parse_date_params
    year = params[:year].to_i
    month = params[:month].to_i
    day = params[:day].to_i

    Date.new(year, month, day)
  rescue ArgumentError
    nil
  end
end
