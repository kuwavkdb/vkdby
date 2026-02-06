# frozen_string_literal: true

class PeopleController < ApplicationController
  def index
    scope = Person.where.not(key: [nil, '']).order(updated_at: :desc)
    scope = scope.where('name ILIKE :q OR name_kana ILIKE :q_kana OR name_log::text ILIKE :q', q: "%#{params[:q]}%", q_kana: "%#{params[:q].tr('ぁ-ん', 'ァ-ン')}%") if params[:q].present?
    @pagy, @people = pagy(scope, limit: 60)
  end

  def show
    @person = Person.find_by!(key: params[:key])
    render json: @person
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Person not found' }, status: :not_found
  end
end
