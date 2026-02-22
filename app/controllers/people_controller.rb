# frozen_string_literal: true

class PeopleController < ApplicationController
  def index
    scope = Person.where.not(key: [nil, '']).order(updated_at: :desc)
    scope = scope.where('name ILIKE :q OR name_kana ILIKE :q OR name_log::text ILIKE :q', q: "%#{params[:q]}%") if params[:q].present?
    @pagy, @people = pagy(scope, limit: 60)
  end

  def search
    q = params[:q].to_s.strip
    if q.length < 2
      render json: []
      return
    end

    people = Person.where.not(key: [nil, ''])
                   .where('name ILIKE :q OR name_kana ILIKE :q', q: "%#{q}%")
                   .order(name_kana: :asc)
                   .limit(10)
                   .pluck(:name, :name_kana, :key)
                   .map { |name, name_kana, key| { name:, name_kana:, key: } }
    render json: people
  end

  def show
    @person = Person.find_by!(key: params[:key])
    render json: @person
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Person not found' }, status: :not_found
  end
end
