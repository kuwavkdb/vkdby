# frozen_string_literal: true

class IndicesController < ApplicationController
  def index
    @index_group = IndexGroup.find_by(id: params[:index_group])
    
    if @index_group
      @indices = @index_group.tag_indices.ordered
      @group_name = @index_group.name
    else
      redirect_to root_path, alert: "Index group not found"
    end
  end

  def show
    @index = TagIndex.find(params[:id])
    @people = @index.people.order(:name_kana, :name)
    @units = @index.units.order(:name_kana, :name)
  end
end
