# frozen_string_literal: true

class UnitsController < ApplicationController
  def index
    scope = Unit.all.order(updated_at: :desc)
    scope = scope.where('name ILIKE :q OR name_kana ILIKE :q_kana OR name_log::text ILIKE :q', q: "%#{params[:q]}%", q_kana: "%#{params[:q].tr('ぁ-ん', 'ァ-ン')}%") if params[:q].present?
    @pagy, @units = pagy(scope, limit: 60)
  end

  def show
    @unit = Unit.find_by!(key: params[:key])
    render json: @unit
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Unit not found' }, status: :not_found
  end
end
