class LegacyRedirectsController < ApplicationController
  def show
    old_key = params[:old_key]

    # Try to find Unit by old_key
    if (unit = Unit.find_by(old_key: old_key))
      redirect_to profile_path(unit.key), status: :moved_permanently
      return
    end

    # Fallback: Try to find Person by old_key
    if (person = Person.find_by(old_key: old_key))
      redirect_to profile_path(person.key), status: :moved_permanently
      return
    end

    # If neither found, render 404
    raise ActiveRecord::RecordNotFound
  end
end
