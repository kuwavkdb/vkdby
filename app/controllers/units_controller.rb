class UnitsController < ApplicationController
  def index
    @units = Unit.all.order(updated_at: :desc)
  end

  def show
    @unit = Unit.find_by!(key: params[:key])
    render json: @unit
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Unit not found" }, status: :not_found
  end
end
