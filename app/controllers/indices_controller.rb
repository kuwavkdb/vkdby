# frozen_string_literal: true

class IndicesController < ApplicationController
  def groups
    @index_groups = IndexGroup.active.ordered
  end

  def index
    @index_group = IndexGroup.find_by(id: params[:index_group])

    if @index_group
      @indices = @index_group.tag_indices.ordered
      @group_name = @index_group.name
    else
      redirect_to root_path, alert: 'Index group not found'
    end
  end

  def show
    @index = TagIndex.find(params[:id])
    # 転送設定のあるタグは関連ページへ転送する。ログイン中は転送せず、タグページに案内を出す（issue #2027）
    return redirect_to @index.redirect_target if @index.redirect_target && !logged_in?

    @people = @index.people.kept.order(:name_kana, :name)
    @units = @index.units.publicly_visible.order(:name_kana, :name)
  end
end
