# frozen_string_literal: true

require 'test_helper'

class MetaDescriptionHelperTest < ActionView::TestCase
  test 'PART_NAMESはPerson::AVAILABLE_PARTSのパートをすべて持つ（issue #1938）' do
    assert_equal Person::AVAILABLE_PARTS.sort, MetaDescriptionHelper::PART_NAMES.keys.sort
  end
end
