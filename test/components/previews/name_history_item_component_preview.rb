# frozen_string_literal: true

class NameHistoryItemComponentPreview < ViewComponent::Preview
  # @label Default
  def default
    log = OpenStruct.new(
      date: '2024/01/01',
      name: 'Sample Band Name',
      name_kana: 'サンプルバンドメイ'
    )
    render(NameHistoryItemComponent.new(log: log))
  end

  # @label No Date
  def no_date
    log = OpenStruct.new(
      date: nil,
      name: 'Undated Band Name',
      name_kana: 'ヒヅケナシ'
    )
    render(NameHistoryItemComponent.new(log: log))
  end

  # @label No Kana
  def no_kana
    log = OpenStruct.new(
      date: '2020/05/05',
      name: 'Band Name Only',
      name_kana: nil
    )
    render(NameHistoryItemComponent.new(log: log))
  end

  # @label Collection
  def collection
    logs = [
      OpenStruct.new(date: '2020/01/01', name: 'First Name', name_kana: 'イチバンメ'),
      OpenStruct.new(date: '2022/01/01', name: 'Second Name', name_kana: 'ニバンメ'),
      OpenStruct.new(date: nil, name: 'Current Name', name_kana: 'ゲンザイ')
    ]
    render(NameHistoryItemComponent.with_collection(logs))
  end
end
