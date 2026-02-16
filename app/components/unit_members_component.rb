# frozen_string_literal: true

class UnitMembersComponent < ViewComponent::Base
  def initialize(unit:, past_members:)
    @unit = unit
    @past_members = past_members
  end

  def render?
    @unit.is_a?(Unit) && @past_members.present?
  end
end
