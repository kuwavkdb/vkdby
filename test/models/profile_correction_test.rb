# frozen_string_literal: true

require 'test_helper'

# ユニット・個人の情報の訂正の投稿（issue #1902）
class ProfileCorrectionTest < ActiveSupport::TestCase
  setup do
    @unit = Unit.create!(key: 'correction-unit', name: '訂正ユニット', status: 'active')
    @person = Person.create!(key: 'correction-person', name: '訂正する人', status: :active)
  end

  test 'requires a correction and strips blank attributes' do
    correction = ProfileCorrection.new(target: @unit, correction: '  ', source_url: ' ', email: '')

    assert_not correction.valid?
    assert correction.errors.added?(:correction, :blank)
    assert_nil correction.source_url
    assert_nil correction.email
  end

  test 'rejects non-http source urls and malformed emails' do
    correction = ProfileCorrection.new(target: @person, correction: '誕生日が違います',
                                       source_url: 'javascript:alert(1)', email: 'not-an-email')

    assert_not correction.valid?
    assert correction.errors[:source_url].any?
    assert correction.errors[:email].any?
  end

  test 'correctable_target finds kept units and people by key' do
    assert_equal @unit, ProfileCorrection.correctable_target('correction-unit')
    assert_equal @person, ProfileCorrection.correctable_target('correction-person')
    assert_nil ProfileCorrection.correctable_target('')
    assert_nil ProfileCorrection.correctable_target('no-such-key')
  end

  test 'correctable_target excludes discarded, redirected and provisional targets' do
    @unit.update!(provisional: true)
    assert_nil ProfileCorrection.correctable_target('correction-unit')

    @person.update!(destination_key: 'correction-unit')
    assert_nil ProfileCorrection.correctable_target('correction-person')

    @person.update!(destination_key: nil)
    @person.discard!
    assert_nil ProfileCorrection.correctable_target('correction-person')
  end

  test 'target_label' do
    assert_equal 'ユニット', ProfileCorrection.new(target: @unit).target_label
    assert_equal '個人', ProfileCorrection.new(target: @person).target_label
  end
end
