class LegacyRedirectsController < ApplicationController
  def show
    old_key = params[:old_key]

    # Try to find Unit by old_key
    if (unit = Unit.find_by(old_key: old_key))
      new_url = profile_url(unit.key)
      response.headers["Link"] = "<#{new_url}>; rel=\"canonical\""
      redirect_to new_url, status: :moved_permanently
      return
    end

    # Fallback: Try to find Person by old_key
    if (person = Person.find_by(old_key: old_key))
      new_url = profile_url(person.key)
      response.headers["Link"] = "<#{new_url}>; rel=\"canonical\""
      redirect_to new_url, status: :moved_permanently
      return
    end

    # If neither found, prepare data for 404 page with creation link
    @old_key = old_key
    begin
      # Try to decode old_key (EUC-JP) to UTF-8 unit_name
      # Unescape first, then force encoding to EUC-JP and transcode to UTF-8
      decoded_bytes = URI.decode_www_form_component(old_key)
      @unit_name = decoded_bytes.force_encoding("EUC-JP").encode("UTF-8")
    rescue StandardError
      @unit_name = nil
    end

    render "not_found", status: :not_found, layout: false
  end
end
