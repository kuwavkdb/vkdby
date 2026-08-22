# frozen_string_literal: true

require 'test_helper'

class SectionComponentTest < ActionView::TestCase
  include ViewComponent::TestHelpers

  test '{{include}}の識別子省略記法（自身の別セクションを参照）がUnit付随セクションでも動作する（issue #1193）' do
    unit = Unit.create!(name: 'Section Component Unit', key: 'section-component-unit', status: :active)
    unit.sections.create!(name: 'about', markdown: '自己紹介です')
    section = unit.sections.create!(name: 'main', markdown: '{{include about}}')

    render_inline(SectionComponent.new(section: section))

    assert_text '自己紹介です'
  end
end
