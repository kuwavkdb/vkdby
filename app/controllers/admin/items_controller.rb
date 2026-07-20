# frozen_string_literal: true

module Admin
  class ItemsController < Admin::BaseController
    before_action :require_super_operator, only: %i[new create edit update]
    before_action :require_admin, only: %i[destroy]
    before_action :set_item, only: %i[edit update destroy]

    def index
      @q = params[:q]
      scope = Item.all.order(release_date: :desc)
      scope = scope.where('title ILIKE :q OR asin ILIKE :q', q: "%#{@q}%") if @q.present?
      @pagy, @items = pagy(scope)
    end

    def new
      @item = Item.new(
        title: params[:title],
        release_date: params[:release_date],
        link_url: params[:link_url],
        asin: params[:asin],
        image_url: params[:image_url]
      )
      @item.artists = build_artist_from_params
    end

    def create
      @item = Item.new(item_params)
      @item.artists = build_artists_from_json(params[:item][:artists_json])

      if @item.save
        redirect_to admin_items_path, notice: 'Item created successfully.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      @item.assign_attributes(item_params)
      @item.artists = build_artists_from_json(params[:item][:artists_json])

      if @item.save
        redirect_to edit_admin_item_path(@item), notice: 'Item updated successfully.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @item.destroy
      redirect_to admin_items_path, notice: 'Item deleted successfully.'
    end

    private

    def set_item
      @item = Item.find(params[:id])
    end

    def item_params
      params.require(:item).permit(:title, :release_date, :link_url, :asin, :image_url, :various_artists)
    end

    def build_artist_from_params
      return [] if params[:artist_name].blank?

      [{ 'name' => params[:artist_name], 'key' => params[:artist_key], 'old_key' => params[:artist_old_key] }.compact_blank]
    end

    def build_artists_from_json(json)
      return [] if json.blank?

      JSON.parse(json)
          .reject { |a| a['name'].blank? }
          .map { |a| a.slice('name', 'key', 'old_key', 'alias').compact_blank }
    rescue JSON::ParserError
      []
    end
  end
end
