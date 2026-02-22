# frozen_string_literal: true

class UnitsController < ApplicationController
  def index
    @tag_indices = TagIndex.where(index_group_id: 1).ordered
    @tag_unit_counts = TagIndexItem.where(tag_index_id: @tag_indices.select(:id), indexable_type: 'Unit')
                                   .group(:tag_index_id)
                                   .count

    scope = Unit.all.order(updated_at: :desc)
    scope = scope.where('name ILIKE :q OR name_kana ILIKE :q OR name_log::text ILIKE :q', q: "%#{params[:q]}%") if params[:q].present?
    if params[:tag_id].present?
      scope = scope.joins(:tag_indices).where(tag_indices: { id: params[:tag_id] })
      scope = scope.reorder(name_kana: :asc)
    end

    @pagy, @units = pagy(scope, limit: 60)
  end

  def search
    q = params[:q].to_s.strip
    if q.length < 2
      render json: []
      return
    end

    units = Unit.where('name ILIKE :q OR name_kana ILIKE :q', q: "%#{q}%")
                .order(name_kana: :asc)
                .limit(10)
                .pluck(:name, :name_kana, :key)
                .map { |name, name_kana, key| { name:, name_kana:, key: } }
    render json: units
  end

  def show
    @unit = Unit.find_by!(key: params[:key])
    render json: @unit
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Unit not found' }, status: :not_found
  end
end
