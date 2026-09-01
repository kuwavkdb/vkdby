# frozen_string_literal: true

require 'test_helper'

class HeaderActionLinkComponentTest < ActionView::TestCase
  include ViewComponent::TestHelpers

  test 'renders the link when visible' do
    render_inline(HeaderActionLinkComponent.new(label: 'Edit', url: '/admin/items/1/edit'))

    assert_link 'Edit', href: '/admin/items/1/edit'
  end

  test 'renders nothing when not visible' do
    render_inline(HeaderActionLinkComponent.new(label: 'Edit', url: '/admin/items/1/edit', visible: false))

    assert_no_link 'Edit'
  end
end
