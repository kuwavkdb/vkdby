# frozen_string_literal: true

class UnitHistoryItemComponentPreview < ViewComponent::Preview
  layout 'component_preview'

  def unit_log
    Unit.new(name: 'Unit Name', key: 'unit_key')
    log = UnitLog.new(log_date: Date.today, phenomenon: 'first_live')

    render(UnitHistoryItemComponent.new(log: log))
  end

  def with_alias
    Unit.new(name: 'Unit Name', key: 'unit_key')
    log = UnitLog.new(log_date: Date.today, phenomenon: 'finish', phenomenon_alias: '集結')

    render(UnitHistoryItemComponent.new(log: log))
  end
end
