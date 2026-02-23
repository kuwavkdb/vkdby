# frozen_string_literal: true

class PeopleController < ApplicationController
  def index
    scope = Person.where.not(key: [nil, '']).order(updated_at: :desc)
    if params[:q].present?
      scope = scope.where(
        'name ILIKE :q OR name_kana ILIKE :q OR name_log::text ILIKE :q OR aliases::text ILIKE :q',
        q: "%#{params[:q]}%"
      )
    end
    @pagy, @people = pagy(scope, limit: 60)
  end

  def show
    @person = Person.find_by!(key: params[:key])
    render json: @person
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Person not found' }, status: :not_found
  end
end
