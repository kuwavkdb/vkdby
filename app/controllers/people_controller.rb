# frozen_string_literal: true

class PeopleController < ApplicationController
  def index
    @people = Person.all.order(updated_at: :desc)
  end

  def show
    @person = Person.find_by!(key: params[:key])
    render json: @person
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Person not found' }, status: :not_found
  end
end
