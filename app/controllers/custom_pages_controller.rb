# frozen_string_literal: true

class CustomPagesController < ApplicationController
  before_action :load_sidebar_data

  def show
    @page = CustomPage.published.find_by!(key: params[:key])
  rescue ActiveRecord::RecordNotFound
    render_not_found(query: params[:key])
  end

  def index_page
    @page = CustomPage.published.find_by!(key: 'index')
    render :show
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  private

  def load_sidebar_data
    today = Date.current
    ttl = Time.current.end_of_day - Time.current

    load_recent_trends(today, ttl)

    @recently_updated = Rails.cache.fetch('sidebar/recently_updated', expires_in: 10.minutes) do
      pages   = CustomPage.published.order(updated_at: :desc).limit(10).to_a
      units   = Unit.kept.order(updated_at: :desc).limit(10).to_a
      persons = Person.kept.order(updated_at: :desc).limit(10).to_a
      (pages + units + persons).sort_by(&:updated_at).reverse.first(8)
    end

    @birthday_people = Rails.cache.fetch("sidebar/birthday_people/#{today}", expires_in: ttl) do
      Person.kept.birthday_on(today).or(Person.kept.birthday_on(today + 1)).order(:name_kana).to_a
    end
  end

  def load_recent_trends(today, ttl)
    @weekly_trends = Rails.cache.fetch("sidebar/weekly_trends/#{today}", expires_in: ttl) do
      from_today = Trend.where(date: today..).order(date: :asc).limit(5).to_a
      recent     = Trend.where(date: (today - 2)..(today - 1)).order(date: :desc).limit(5).to_a
      (from_today + recent).sort_by(&:date).reverse
    end

    unit_ids   = @weekly_trends.flat_map { |t| t.units&.map { |u| u['unit_id'] } }.compact.uniq
    person_ids = @weekly_trends.flat_map { |t| t.people&.map { |p| p['person_id'] } }.compact.uniq
    @weekly_trend_units  = Unit.kept.where(id: unit_ids).index_by(&:id)
    @weekly_trend_people = Person.kept.where(id: person_ids).index_by(&:id)
  end
end
