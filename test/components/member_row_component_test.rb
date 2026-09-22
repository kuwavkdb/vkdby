# frozen_string_literal: true

require 'test_helper'

class MemberRowComponentTest < ActionView::TestCase
  include ViewComponent::TestHelpers

  test 'sns_icon_for returns :x for an "@handle" account' do
    member = UnitPerson.new(part: 'vocal', sns: ['@vocalist'])

    component = MemberRowComponent.new(member: member)

    assert_equal :x, component.sns_icon_for('@vocalist')
  end

  test 'sns_icon_for returns :instagram for an Instagram URL' do
    member = UnitPerson.new(part: 'vocal', sns: ['https://instagram.com/vocalist'])

    component = MemberRowComponent.new(member: member)

    assert_equal :instagram, component.sns_icon_for('https://instagram.com/vocalist')
  end

  test 'sns_icon_for returns nil for a non-SNS URL' do
    member = UnitPerson.new(part: 'vocal', sns: ['https://example.com/official'])

    component = MemberRowComponent.new(member: member)

    assert_nil component.sns_icon_for('https://example.com/official')
  end

  test 'sns_url_for converts an "@handle" account to an x.com URL' do
    member = UnitPerson.new(part: 'vocal', sns: ['@vocalist'])

    component = MemberRowComponent.new(member: member)

    assert_equal 'https://x.com/vocalist', component.sns_url_for('@vocalist')
  end

  test 'sns_url_for keeps a URL as-is' do
    member = UnitPerson.new(part: 'vocal', sns: ['https://instagram.com/vocalist'])

    component = MemberRowComponent.new(member: member)

    assert_equal 'https://instagram.com/vocalist', component.sns_url_for('https://instagram.com/vocalist')
  end

  test 'renders distinct SNS icons for X, Instagram, YouTube and a non-SNS link' do
    member = UnitPerson.new(
      part: 'vocal',
      sns: ['@vocalist', 'https://instagram.com/vocalist', 'https://youtube.com/@vocalist', 'https://example.com/official']
    )

    render_inline(MemberRowComponent.new(member: member))

    assert_text '(Twitter)'
    assert_text '(Instagram)'
    assert_text '(YouTube)'
    assert_text '(外部サイト)'
  end
end
