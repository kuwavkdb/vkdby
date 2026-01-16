class PeopleController < ApplicationController
  def show
    @person = Person.find_by!(key: params[:key])
    render json: @person
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Person not found" }, status: :not_found
  end
end
