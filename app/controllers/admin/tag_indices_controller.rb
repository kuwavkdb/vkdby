# frozen_string_literal: true

module Admin
  class TagIndicesController < Admin::BaseController
    def update
      @tag_index = TagIndex.find(params[:id])
      if @tag_index.update(tag_index_params)
        redirect_back(fallback_location: admin_index_groups_path, notice: 'タグのステータスを更新しました')
      else
        redirect_back(fallback_location: admin_index_groups_path, alert: '更新に失敗しました')
      end
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

    def tag_index_params
      params.require(:tag_index).permit(:active)
    end
  end
end
