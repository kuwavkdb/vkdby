# frozen_string_literal: true

class UnitSnapshotsComponent < ViewComponent::Base
  def initialize(snapshots:, unit: nil, admin: false, show_label: true)
    super()
    @snapshots = snapshots
    @unit = unit
    @admin = admin
    @show_label = show_label
  end

  def render?
    @snapshots.present?
  end
end
