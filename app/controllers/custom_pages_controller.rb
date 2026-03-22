# frozen_string_literal: true

class CustomPagesController < ApplicationController
  before_action :load_sidebar_data

  def show
    @page = CustomPage.published.find_by!(key: params[:key])
  rescue ActiveRecord::RecordNotFound
    render file: Rails.root.join('public/404.html'), status: :not_found, layout: false
  end

  def index_page
    @page = CustomPage.published.find_by!(key: 'index')
    render :show
  rescue ActiveRecord::RecordNotFound
    render file: Rails.root.join('public/404.html'), status: :not_found, layout: false
  end

  private

  def load_sidebar_data
    today = Date.current
    ttl = Time.current.end_of_day - Time.current

    @weekly_trends = Rails.cache.fetch("sidebar/weekly_trends/#{today}", expires_in: ttl) do
      Trend.where(date: (today - 7)..(today + 7)).order(:date).to_a
    end

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
end
