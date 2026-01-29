# frozen_string_literal: true

module ApplicationHelper
  include Pagy::Frontend

  def logged_in?
    false
  end
end
