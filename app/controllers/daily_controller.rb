# frozen_string_literal: true

class DailyController < ApplicationController
  # PersonCardComponent（show_history: true）の表示に必要な列のみを取得し、
  # old_wiki_text/note など大きいテキスト列のロードを避ける
  PERSON_CARD_COLUMNS = %i[id key name name_kana aliases old_history].freeze

  def show
    @year_agnostic = params[:year].nil?

    return render_not_found if !@year_agnostic && !valid_year?(params[:year].to_i)

    @date = parse_date_params
    return redirect_to root_path, alert: '日付の形式が正しくありません' unless @date

    if @year_agnostic
      month = @date.month
      day = @date.day
      @trends = Trend.on_month_day(month, day).select(:id, :date, :title, :units).order(date: :asc)
      @birthdays = Person.kept.published.birthday_on(@date).select(*PERSON_CARD_COLUMNS).order(name_kana: :asc)
      @releases = Item.released_on_month_day(month, day).order(release_date: :asc)
    else
      @trends = Trend.on_date(@date).select(:id, :date, :title, :units).order(created_at: :desc)
      @birthdays = Person.kept.published.birthday_on(@date).where(status: %i[active hiatus])
                         .select(*PERSON_CARD_COLUMNS).order(name_kana: :asc)
      @releases = Item.released_on(@date).order(created_at: :desc)
    end

    # Load related units for trends
    all_unit_ids = @trends.flat_map { |t| t.units&.map { |u| u['unit_id'] } }.compact.uniq
    @related_units = Unit.kept.where(id: all_unit_ids).index_by(&:id)
  end

  private

  def parse_date_params
    month = params[:month].to_i
    day   = params[:day].to_i

    if params[:year].nil?
      Date.new(2000, month, day)
    else
      Date.new(params[:year].to_i, month, day)
    end
  rescue ArgumentError
    nil
  end
end
