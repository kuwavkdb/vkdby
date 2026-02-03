# frozen_string_literal: true

  def index
    @people = Person.where.not(key: [nil, '']).order(updated_at: :desc)
    @people = @people.where('name ILIKE :q OR name_log::text ILIKE :q', q: "%#{params[:q]}%") if params[:q].present?
  end

  def show
    @person = Person.find_by!(key: params[:key])
    render json: @person
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Person not found' }, status: :not_found
  end
end
