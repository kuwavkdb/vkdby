# frozen_string_literal: true

require 'test_helper'

class BasicAttributesComponentTest < ViewComponent::TestCase
  # issue #2071: 個人の項目は パート → ステータス → 血液型 → 出身地 → 誕生日 の順に並べる
  test '個人の項目をパート・ステータス・血液型・出身地・誕生日の順に並べる' do
    person = Person.new(name: 'Order Person', key: 'order-person', status: :active, parts: %w[vocal],
                        blood: 'A', hometown: '東京都', birthday: Date.new(Person::DUMMY_BIRTH_YEAR, 7, 12), birth_year: 1990)

    render_inline(BasicAttributesComponent.new(resource: person))

    assert_equal %w[パート ステータス 血液型 出身地 誕生日], page.all('dl > div > dt').map(&:text).first(5)
  end

  test 'ユニットの項目は種別・ステータスの順に並べる' do
    unit = Unit.new(name: 'Order Unit', key: 'order-unit', status: :active, unit_type: :band)

    render_inline(BasicAttributesComponent.new(resource: unit))

    assert_equal %w[種別 ステータス], page.all('dl > div > dt').map(&:text).first(2)
  end

  # issue #2101: 年別ページは1970年以降しかないため、1969年以前の誕生年は個人一覧の誕生年の絞り込みへリンクする
  test '1969年以前の誕生年は個人一覧の誕生年の絞り込みへリンクする' do
    person = Person.new(name: 'Old Person', key: 'old-person', birthday: Date.new(Person::DUMMY_BIRTH_YEAR, 7, 12), birth_year: 1969)

    render_inline(BasicAttributesComponent.new(resource: person))

    assert_selector "a[href='/people?birth_year=1969']", text: '1969'
    assert_no_selector "a[href='/date/1969']"
  end

  test '1970年以降の誕生年は年別ページへリンクする' do
    person = Person.new(name: 'New Person', key: 'new-person', birthday: Date.new(Person::DUMMY_BIRTH_YEAR, 7, 12), birth_year: 1970)

    render_inline(BasicAttributesComponent.new(resource: person))

    assert_selector "a[href='/date/1970']", text: '1970'
  end
end
