# frozen_string_literal: true

require 'test_helper'

class TwitterEmbedComponentTest < ActiveSupport::TestCase
  test 'render? is true when a twitter status link is present' do
    link = OpenStruct.new(url: 'https://x.com/nonameactorsjp/status/892008297930268674')

    component = TwitterEmbedComponent.new(links: [link])

    assert component.render?
  end

  test 'render? is false when no links are present' do
    component = TwitterEmbedComponent.new(links: [])

    refute component.render?
  end
end
