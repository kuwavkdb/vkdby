# frozen_string_literal: true

class PeopleController < ApplicationController
  def index
    scope = Person.kept.where.not(key: [nil, '']).order(updated_at: :desc)
    if params[:q].present?
      scope = scope.where(
        'name ILIKE :q OR name_kana ILIKE :q OR name_log::text ILIKE :q OR aliases::text ILIKE :q OR old_history ILIKE :q',
        q: "%#{params[:q]}%"
      )
    end
    @pagy, @people = pagy(scope, limit: 60)
  end

  def search
    q = params[:q].to_s.strip.first(100)
    if q.length < 2
      render json: []
      return
    end

    conn = ActiveRecord::Base.connection
    quoted_exact = conn.quote(q)
    quoted_prefix = conn.quote("#{q}%")
    people = Person.kept
                   .where('name ILIKE :q OR name_kana ILIKE :q OR name_log::text ILIKE :q OR aliases::text ILIKE :q', q: "%#{q}%")
                   .order(Arel.sql(<<~SQL.squish))
                     CASE
                       WHEN name = #{quoted_exact} OR name_kana = #{quoted_exact} THEN 0
                       WHEN name ILIKE #{quoted_prefix} OR name_kana ILIKE #{quoted_prefix} THEN 1
                       ELSE 2
                     END
                   SQL
                   .order(name_kana: :asc)
                   .limit(10)
                   .pluck(:name, :name_kana, :key)
                   .map { |name, name_kana, key| { name:, name_kana:, key: } }
    render json: people
  end

  def units
    person = Person.kept.find_by!(key: params[:key])
    unit_keys = person.unit_people
                      .joins(:unit)
                      .merge(Unit.kept)
                      .distinct
                      .pluck('units.key')
    render json: { unit_keys:, person_name: person.name }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Person not found' }, status: :not_found
  end

  def show
    @person = Person.kept.find_by!(key: params[:key])
    render json: @person
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Person not found' }, status: :not_found
  end
end
