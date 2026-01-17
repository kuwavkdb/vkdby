class UnitMembersComponent < ViewComponent::Base
  def initialize(unit:, active_members:, past_members:)
    @unit = unit
    @active_members = active_members
    @past_members = past_members
  end

  def render?
    @unit.is_a?(Unit) && (@active_members.present? || @past_members.present?)
  end
end
