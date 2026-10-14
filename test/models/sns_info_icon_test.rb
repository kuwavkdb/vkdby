# frozen_string_literal: true

require 'test_helper'

class SnsInfoIconTest < ActiveSupport::TestCase
  test 'commented_out? は行頭が // または # のアカウントを判定する（issue #1854）' do
    ['// https://instagram.com/old', '//@old', '#@old_handle', '# https://example.com', '  // indented'].each do |account|
      assert SnsInfoIcon.commented_out?(account), account
    end
    ['@handle', 'https://example.com/#anchor', 'https://example.com//path', '', nil].each do |account|
      assert_not SnsInfoIcon.commented_out?(account), account.inspect
    end
  end
end
