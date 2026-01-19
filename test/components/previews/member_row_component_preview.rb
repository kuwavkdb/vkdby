class MemberRowComponentPreview < ViewComponent::Preview
  layout "component_preview"
  def active_member
    person = Person.new(name: "Active Member", key: "active_person")
    member = UnitPerson.new(
      person: person,
      part: "vocal",
      status: "active"
    )
    render(MemberRowComponent.new(member: member))
  end

  def past_member
    person = Person.new(name: "Past Person", key: "past_person")
    member = UnitPerson.new(
      person: person,
      part: "bass",
      status: "left"
    )
    render(MemberRowComponent.new(member: member))
  end

  def with_active_hidden
    person = Person.new(name: "Hidden Status Person", key: "hidden_person")
    member = UnitPerson.new(
      person: person,
      part: "guitar",
      status: "active"
    )
    render(MemberRowComponent.new(member: member, hide_active: true))
  end

  def with_logs
    # Using Struct to mock the object graph since AR associations on new records can be tricky
    mock_unit = Struct.new(:name, :key, keyword_init: true).new(name: "Other Unit", key: "other_unit")

    mock_log1 = Struct.new(:log_date, :phenomenon, :phenomenon_text, :unit, :unit_name, :name, :sort_order, keyword_init: true).new(
      log_date: Date.today.to_s,
      phenomenon: "join",
      phenomenon_text: "加入",
      unit: mock_unit,
      unit_name: nil,
      name: nil,
      sort_order: 1
    )

    mock_log2 = Struct.new(:log_date, :phenomenon, :phenomenon_text, :unit, :unit_name, :name, :sort_order, keyword_init: true).new(
      log_date: (Date.today - 365).to_s,
      phenomenon: "stay",
      phenomenon_text: "残留",
      unit: nil,
      unit_name: "Previous Band",
      name: "Previous Band",
      sort_order: 0
    )

    mock_person = Struct.new(:name, :key, :person_logs, keyword_init: true).new(
      name: "Logged Person",
      key: "logged_person",
      person_logs: [ mock_log1, mock_log2 ]
    )

    mock_member = Struct.new(:person, :part, :status, keyword_init: true).new(
      person: mock_person,
      part: "drums",
      status: "active"
    )

    render(MemberRowComponent.new(member: mock_member))
  end
end
