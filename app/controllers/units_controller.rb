# frozen_string_literal: true

class UnitsController < ApplicationController
  def index
    @filter_groups = IndexGroup.for_units.includes(tag_indices: :items)
    all_tag_index_ids = @filter_groups.flat_map { |g| g.tag_indices.map(&:id) }
    @tag_unit_counts = TagIndexItem.where(tag_index_id: all_tag_index_ids, indexable_type: 'Unit')
                                   .group(:tag_index_id)
                                   .count

    scope = Unit.kept.where.not(name: [nil, '']).order(updated_at: :desc)
    if params[:q].present?
      scope = scope.where(
        'units.name ILIKE :q OR units.name_kana ILIKE :q OR units.name_log::text ILIKE :q OR units.aliases::text ILIKE :q',
        q: "%#{params[:q]}%"
      )
    end
    @selected_tag_ids = params[:tag_ids]&.to_unsafe_h&.transform_values(&:presence)&.compact || {}
    if @selected_tag_ids.any?
      @selected_tag_ids.each_value do |tag_id|
        scope = scope.where(id: Unit.joins(:tag_indices).where(tag_indices: { id: tag_id }).select(:id))
      end
      scope = scope.reorder(name_kana: :asc)
    end

    @pagy, @units = pagy(scope, limit: 60)
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
    units = Unit.kept.where('name ILIKE :q OR name_kana ILIKE :q', q: "%#{q}%")
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
    render json: units
  end

  def show
    @unit = Unit.kept.find_by!(key: params[:key])
    render json: @unit
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Unit not found' }, status: :not_found
  end
end
