# frozen_string_literal: true

module Admin
  class LinksController < Admin::BaseController
    before_action :set_linkable

    def reorder
      params[:ids].each_with_index do |id, index|
        @linkable.links.find(id).update(sort_order: index + 1)
      end
      head :ok
    end

    private

    def set_linkable
      type = params[:linkable_type]
      id   = params[:linkable_id]
      @linkable = case type
                  when 'Unit'   then Unit.find(id)
                  when 'Person' then Person.find(id)
                  else raise ActionController::BadRequest, 'Invalid linkable_type'
                  end
    end
  end
end
