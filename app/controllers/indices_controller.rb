# frozen_string_literal: true

class IndicesController < ApplicationController
  def index
    @index_group = params[:index_group].to_i
    # index_group: 1=Kana, etc.
    @indices = TagIndex.where(index_group: @index_group).order(:order_in_group, :name)

    # Optional: You might want to map index_group to a name for display
    @group_name = case @index_group
                  when 1 then 'カナ索引'
                  when 2 then '地域索引'
                  else "グループ #{@index_group}"
                  end
  end

  def show
    @index = TagIndex.find(params[:id])
    @people = @index.people.order(:name_kana, :name)
    @units = @index.units.order(:name_kana, :name)
  end
end
