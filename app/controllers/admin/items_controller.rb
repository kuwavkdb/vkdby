# frozen_string_literal: true

module Admin
  class ItemsController < Admin::BaseController
    MATCH_TYPES = %w[old_key key name].freeze

    before_action :require_super_operator, only: %i[new create edit update bulk_artist_edit bulk_artist_update]
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

    def bulk_artist_edit
      @match_type = params[:match_type].presence_in(MATCH_TYPES)
      @match_value = params[:match_value].to_s.strip

      scope = Item.all.order(release_date: :desc)
      scope = scope.public_send(:"by_artist_#{@match_type}", @match_value) if @match_type.present? && @match_value.present?
      @pagy, @items = pagy(scope)
    end

    def bulk_artist_update
      ids = Array(params[:ids]).map(&:to_i).reject(&:zero?)
      match_type = params[:match_type].presence_in(MATCH_TYPES)
      match_value = params[:match_value].to_s.strip
      replacement = build_replacement_from_json(params[:replacement_json])
      redirect_params = { match_type: match_type, match_value: match_value }

      return redirect_to bulk_artist_edit_admin_items_path(redirect_params), alert: '項目が選択されていません' if ids.empty?
      return redirect_to bulk_artist_edit_admin_items_path(redirect_params), alert: '検索条件が不正です' if match_type.blank? || match_value.blank?
      return redirect_to bulk_artist_edit_admin_items_path(redirect_params), alert: '置換先のUnit/Personを選択してください' if replacement.blank?

      count = 0
      Item.where(id: ids).find_each do |item|
        count += 1 if item.replace_artist!(match_type: match_type, match_value: match_value, replacement: replacement)
      end
      redirect_to bulk_artist_edit_admin_items_path(redirect_params), notice: "#{count}件のアーティストを差し替えました"
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

      artist = { 'name' => params[:artist_name], 'key' => params[:artist_key], 'old_key' => params[:artist_old_key] }.compact_blank
      artist['confirmed'] = false
      [artist]
    end

    def build_artists_from_json(json)
      return [] if json.blank?

      JSON.parse(json)
          .reject { |a| a['name'].blank? }
          .map { |a| a.slice('name', 'key', 'old_key', 'alias').compact_blank }
    rescue JSON::ParserError
      []
    end

    def build_replacement_from_json(json)
      return nil if json.blank?

      entry = JSON.parse(json).find { |a| a['name'].present? }
      return nil unless entry

      entry.slice('name', 'key', 'old_key').compact_blank
    rescue JSON::ParserError
      nil
    end
  end
end
