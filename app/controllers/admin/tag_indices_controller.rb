# frozen_string_literal: true

module Admin
  class TagIndicesController < Admin::BaseController
    before_action :set_tag_index, only: %i[edit update destroy]

    def new
      @tag_index = TagIndex.new(index_group_id: params[:index_group_id])
    end

    def create
      @tag_index = TagIndex.new(tag_index_params)
      if @tag_index.save
        redirect_to admin_index_group_path(id: @tag_index.index_group_id || 0), notice: 'タグを追加しました'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @tag_index.update(tag_index_params)
        redirect_back(fallback_location: admin_index_groups_path, notice: 'タグを更新しました')
      elsif tag_index_params.key?(:name)
        render :edit, status: :unprocessable_entity
      else
        redirect_back(fallback_location: admin_index_groups_path, alert: '更新に失敗しました')
      end
    end

    def destroy
      redirect_group_id = @tag_index.index_group_id || 0
      @tag_index.destroy
      redirect_to admin_index_group_path(id: redirect_group_id), notice: 'タグを削除しました'
    end

    def bulk_update
      if params[:tag_index_ids].blank?
        redirect_back(fallback_location: admin_index_groups_path, alert: 'タグが選択されていません')
        return
      end

      active_status = params[:active] == 'true'
      TagIndex.where(id: params[:tag_index_ids]).update_all(active: active_status)
      redirect_back(fallback_location: admin_index_groups_path, notice: 'ステータスを更新しました')
    end

    private

    def set_tag_index
      @tag_index = TagIndex.find(params[:id])
    end

    def tag_index_params
      params.require(:tag_index).permit(:name, :active, :index_group_id)
    end
  end
end
