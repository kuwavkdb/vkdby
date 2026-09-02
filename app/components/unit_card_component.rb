# frozen_string_literal: true

class UnitCardComponent < ViewComponent::Base
  with_collection_parameter :unit

  def initialize(unit:, show_details: false)
    super()
    @unit = unit
    @show_details = show_details
  end

  def display_aliases
    @unit.aliases.reject { |a| a.name.blank? || a.hidden }
  end
end
