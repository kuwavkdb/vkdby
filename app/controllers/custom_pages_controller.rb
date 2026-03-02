# frozen_string_literal: true

class CustomPagesController < ApplicationController
  def show
    @page = CustomPage.published.find_by!(key: params[:key])
  rescue ActiveRecord::RecordNotFound
    render file: Rails.root.join('public/404.html'), status: :not_found, layout: false
  end

  def index_page
    @page = CustomPage.published.find_by!(key: 'index')
    render :show
  rescue ActiveRecord::RecordNotFound
    render file: Rails.root.join('public/404.html'), status: :not_found, layout: false
  end
end
