# frozen_string_literal: true

require 'test_helper'

class MetaDescriptionHelperTest < ActionView::TestCase
  test 'PART_NAMESはPerson::AVAILABLE_PARTSのパートを、etc を除いてすべて持つ（issue #1938, #2039）' do
    assert_equal (Person::AVAILABLE_PARTS - %w[etc]).sort, MetaDescriptionHelper::PART_NAMES.keys.sort
  end
end
