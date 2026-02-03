# frozen_string_literal: true

  def index
    @units = Unit.all.order(updated_at: :desc)
    @units = @units.where('name ILIKE :q OR name_log::text ILIKE :q', q: "%#{params[:q]}%") if params[:q].present?
  end

  def show
    @unit = Unit.find_by!(key: params[:key])
    render json: @unit
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Unit not found' }, status: :not_found
  end
end
