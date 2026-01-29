# frozen_string_literal: true

module Admin
  class IndexGroupsController < Admin::ApplicationController
    before_action :set_index_group, only: %i[show edit update destroy reorder_indices]

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
      @indices = @index_group.tag_indices.ordered
    end

    def edit
    end

    def update
      if @index_group.update(index_group_params)
        redirect_to admin_index_groups_path, notice: 'インデックスグループを更新しました'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def reorder_indices
      ActiveRecord::Base.transaction do
        params[:ids].each_with_index do |id, index|
          @index_group.tag_indices.find(id).update!(order_in_group: index + 1)
        end
      end
      head :ok
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def set_index_group
      @index_group = IndexGroup.find(params[:id])
    end

    def index_group_params
      params.require(:index_group).permit(:name, :sort_order, :active)
    end
  end
end
