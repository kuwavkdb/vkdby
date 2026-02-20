# frozen_string_literal: true

class PersonCardComponentPreview < ViewComponent::Preview
  layout 'component_preview'

  # size: :sm（デフォルト）、読みがなあり（誕生日セクション向け）
  def small
    person = Person.new(name: 'HYDE', name_kana: 'はいど', key: 'hyde')
    render(PersonCardComponent.new(person: person))
  end

  # size: :lg（/people インデックス向け）
  def large
    person = Person.new(name: 'HYDE', name_kana: 'はいど', key: 'hyde')
    render(PersonCardComponent.new(person: person, size: :lg))
  end

  # 読みがななし
  def without_kana
    person = Person.new(name: 'HYDE', key: 'hyde')
    render(PersonCardComponent.new(person: person, size: :lg))
  end

  # /people インデックスと同様のステータス・更新日表示
  def large_with_status
    render_with_template(locals: { person: Person.new(name: 'HYDE', name_kana: 'はいど', key: 'hyde', status: 'active') })
  end

  # 誕生日セクションと同様の所属履歴表示
  def small_with_history
    render_with_template(locals: { person: Person.new(name: 'HYDE', name_kana: 'はいど', key: 'hyde') })
  end
end
