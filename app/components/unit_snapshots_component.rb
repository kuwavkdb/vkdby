# frozen_string_literal: true

class UnitSnapshotsComponent < ViewComponent::Base
  def initialize(snapshots:)
    super
    @snapshots = snapshots
  end

  def render?
    @snapshots.present?
  end
end
