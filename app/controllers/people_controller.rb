# frozen_string_literal: true

class PeopleController < ApplicationController
  def index
    @filter_groups = IndexGroup.for_people.includes(:tag_indices)
    all_tag_index_ids = @filter_groups.flat_map { |g| g.tag_indices.map(&:id) }
    @tag_person_counts = TagIndexItem.where(tag_index_id: all_tag_index_ids, indexable_type: 'Person')
                                     .group(:tag_index_id)
                                     .count

    scope = Person.kept.where.not(key: [nil, '']).order(updated_at: :desc)
    if params[:q].present?
      scope = scope.where(
        'people.name ILIKE :q OR people.name_kana ILIKE :q OR people.name_log::text ILIKE :q OR people.aliases::text ILIKE :q OR people.old_history ILIKE :q',
        q: "%#{normalize_search_query(params[:q])}%"
      )
    end
    @selected_tag_ids = params[:tag_ids]&.to_unsafe_h&.transform_values(&:presence)&.compact || {}
    if @selected_tag_ids.any?
      @selected_tag_ids.each_value do |tag_id|
        scope = scope.where(id: Person.joins(:tag_indices).where(tag_indices: { id: tag_id }).select(:id))
      end
      scope = scope.reorder(name_kana: :asc)
    end
    @pagy, @people = pagy(scope, limit: 60)
  end

  def search
    q = normalize_search_query(params[:q].to_s.strip.first(100))
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
    unit_keys = person.snapshot_people
                      .joins(unit_snapshot: :unit)
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
