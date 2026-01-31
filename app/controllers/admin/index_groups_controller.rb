# frozen_string_literal: true

module Admin
  class IndexGroupsController < Admin::BaseController
    before_action :set_index_group, only: %i[show edit update reorder_indices detach_indices]

    def index
      @index_groups = IndexGroup.ordered
    end

    def new
      @index_group = IndexGroup.new
    end

    def create
      @index_group = IndexGroup.new(index_group_params)
      if @index_group.save
        redirect_to admin_index_groups_path, notice: 'インデックスグループを作成しました'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def show
      if @index_group.id.zero?
        base_scope = TagIndex.where(index_group_id: nil)
        base_scope = base_scope.where('name LIKE ?', "%#{params[:q]}%") if params[:q].present?
        @indices = base_scope.order(:name)
        @groups = IndexGroup.ordered
      else
        indices_scope = @index_group.tag_indices
        indices_scope = indices_scope.where('name LIKE ?', "%#{params[:q]}%") if params[:q].present?
        @indices = indices_scope.ordered
      end
    end

    def edit; end

    def update
      if @index_group.update(index_group_params)
        redirect_to admin_index_groups_path, notice: 'インデックスグループを更新しました'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def reorder_indices
      return head :forbidden if @index_group.id.zero?

      ActiveRecord::Base.transaction do
        params[:ids].each_with_index do |id, index|
          @index_group.tag_indices.find(id).update!(order_in_group: index + 1)
        end
      end
      head :ok
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def move_indices
      target_group = IndexGroup.find(params[:target_group_id])
      TagIndex.where(id: params[:tag_index_ids]).update_all(index_group_id: target_group.id)

      redirect_to admin_index_group_path(id: 0), notice: 'タグを移動しました'
    end

    def detach_indices
      TagIndex.where(id: params[:tag_index_ids]).update_all(index_group_id: nil)
      redirect_to admin_index_group_path(@index_group), notice: 'タグをグループから削除しました'
    end

    private

    def set_index_group
      @index_group = if params[:id] == '0'
                       IndexGroup.new(id: 0, name: '未分類')
                     else
                       IndexGroup.find(params[:id])
                     end
    end

    def index_group_params
      params.require(:index_group).permit(:name, :sort_order, :active)
    end
  end
end
