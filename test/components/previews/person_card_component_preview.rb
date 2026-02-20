# frozen_string_literal: true

class PersonCardComponentPreview < ViewComponent::Preview
  layout 'component_preview'

  # 基本（読みがなあり、誕生日セクション向け）
  def default
    person = Person.new(name: 'HYDE', name_kana: 'はいど', key: 'hyde')
    render(PersonCardComponent.new(person: person))
  end

  # 読みがななし
  def without_kana
    person = Person.new(name: 'HYDE', key: 'hyde')
    render(PersonCardComponent.new(person: person))
  end

  # 更新日表示あり（/people インデックス向け）
  def with_details
    person = Person.new(name: 'HYDE', name_kana: 'はいど', key: 'hyde', status: 'active',
                        updated_at: Time.current)
    render(PersonCardComponent.new(person: person, show_details: true))
  end

  # 所属履歴表示あり（誕生日セクション向け）
  def with_history
    render_with_template(locals: { person: Person.new(name: 'HYDE', name_kana: 'はいど', key: 'hyde') })
  end
end
