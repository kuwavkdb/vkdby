# frozen_string_literal: true

class UnitSnapshotsComponent < ViewComponent::Base
  def initialize(snapshots:, unit: nil, admin: false)
    super()
    @snapshots = snapshots
    @unit = unit
    @admin = admin
  end

  def render?
    @snapshots.present?
  end
end
