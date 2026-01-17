class HistoryComponentPreview < ViewComponent::Preview
  layout "component_preview"
  def person_logs
    person = Person.new(name: "Person Name", key: "person_key")
    unit = Unit.new(name: "Unit Name", key: "unit_key")

    logs = [
      PersonLog.new(log_date: Date.today, status: "join", person: person, unit: unit, part: "vocal"),
      PersonLog.new(log_date: Date.today - 1.year, status: "stay", person: person, unit: unit),
      PersonLog.new(log_date: Date.today - 2.years, text: "Some text log", person: person, unit: unit)
    ]
    render(HistoryComponent.new(logs: logs, resource: person))
  end

  def unit_logs
    logs = [
      UnitLog.new(log_date: Date.today, phenomenon: "first_live"),
      UnitLog.new(log_date: Date.today - 3.months, text: "Some unit event", phenomenon: "finish")
    ]
    # Unit context with UnitLogs
    render(HistoryComponent.new(logs: logs, resource: Unit.new(name: "Unit Name")))
  end

  def unit_profile_context
    person = Person.new(name: "Member Name", key: "member_key")
    unit = Unit.new(name: "My Unit", key: "my_unit")
    logs = [
      PersonLog.new(log_date: Date.today, status: "join", person: person, unit: unit, part: "guitar"),
      PersonLog.new(log_date: Date.today - 1.year, status: "leave", person: person, unit: unit, part: nil) # Case without part
    ]
    # Unit context with PersonLogs (should show Person Name)
    render(HistoryComponent.new(logs: logs, resource: unit))
  end
end
