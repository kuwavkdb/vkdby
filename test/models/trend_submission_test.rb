# frozen_string_literal: true

require 'test_helper'

# == Schema Information
#
# Table name: trend_submissions
#
#  id                 :bigint           not null, primary key
#  content             :text
#  date                :date             not null
#  day_unknown         :boolean          default(FALSE), not null
#  email               :string
#  is_related_person   :boolean          default(FALSE), not null
#  month_unknown       :boolean          default(FALSE), not null
#  phenomenon          :integer          not null
#  submission_status   :integer          default(0), not null
#  submitter_ip        :string
#  target_id           :bigint
#  target_name         :string           not null
#  target_type         :integer          not null
#  title               :string
#  via_url             :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  converted_trend_id  :bigint
#
class TrendSubmissionTest < ActiveSupport::TestCase
  def valid_attributes
    {
      target_type: :unit, target_name: 'Test Unit', date: Date.new(2026, 1, 1),
      via_url: 'https://example.com', phenomenon: Trend.unit_phenomenons['announcement']
    }
  end

  test 'target_type is required' do
    submission = TrendSubmission.new(valid_attributes.except(:target_type))

    assert_not submission.valid?
    assert_includes submission.errors[:target_type], 'を入力してください'
  end

  test 'target_name is required' do
    submission = TrendSubmission.new(valid_attributes.merge(target_name: ''))

    assert_not submission.valid?
    assert_includes submission.errors[:target_name], 'を入力してください'
  end

  test 'date is required' do
    submission = TrendSubmission.new(valid_attributes.except(:date))

    assert_not submission.valid?
    assert_includes submission.errors[:date], 'を入力してください'
  end

  test 'via_url is required' do
    submission = TrendSubmission.new(valid_attributes.merge(via_url: ''))

    assert_not submission.valid?
    assert_includes submission.errors[:via_url], 'を入力してください'
  end

  test 'via_url に javascript: などのスキームは保存できない' do
    submission = TrendSubmission.new(valid_attributes.merge(via_url: 'javascript:alert(1)'))

    assert_not submission.valid?
    assert_includes submission.errors[:via_url], 'は http:// または https:// で始まるURLを入力してください'
  end

  test 'phenomenon is required' do
    submission = TrendSubmission.new(valid_attributes.except(:phenomenon))

    assert_not submission.valid?
    assert_includes submission.errors[:phenomenon], 'を入力してください'
  end

  test 'saves successfully with valid attributes' do
    submission = TrendSubmission.new(valid_attributes)

    assert submission.save
  end

  test 'defaults to pending submission_status' do
    submission = TrendSubmission.create!(valid_attributes)

    assert_predicate submission, :pending?
  end

  test 'converted_trend can reference a Trend' do
    trend = Trend.create!(date: Date.new(2026, 1, 1), publish_start_at: Time.current, active: true,
                          unit_phenomenon: :announcement)
    submission = TrendSubmission.create!(valid_attributes.merge(submission_status: :converted, converted_trend: trend))

    assert_equal trend, submission.reload.converted_trend
  end

  test 'phenomenon_options_for returns unit_phenomenon keys for unit target_type' do
    assert_equal Trend.unit_phenomenons.keys, TrendSubmission.phenomenon_options_for('unit')
  end

  test 'phenomenon_options_for returns person_phenomenon keys for person target_type' do
    assert_equal Trend.person_phenomenons.keys, TrendSubmission.phenomenon_options_for('person')
  end

  test 'phenomenon_key_for maps the raw integer value back to the enum key for the given target_type' do
    assert_equal 'announcement', TrendSubmission.phenomenon_key_for('unit', Trend.unit_phenomenons['announcement'])
    assert_equal 'join_member', TrendSubmission.phenomenon_key_for('person', Trend.person_phenomenons['join_member'])
  end

  test 'phenomenon_label renders the translated label for the target_type' do
    submission = TrendSubmission.new(valid_attributes)

    assert_equal 'お知らせ', submission.phenomenon_label
  end

  test 'builds date from year/month/day when year is present' do
    submission = TrendSubmission.new(valid_attributes.except(:date).merge(year: '2026', month: '3', day: '15'))

    assert submission.valid?
    assert_equal Date.new(2026, 3, 15), submission.date
    assert_not submission.month_unknown?
    assert_not submission.day_unknown?
  end

  test 'marks month_unknown and day_unknown when month/day are left blank' do
    submission = TrendSubmission.new(valid_attributes.except(:date).merge(year: '2026', month: '', day: ''))

    assert submission.valid?
    assert_equal Date.new(2026, 1, 1), submission.date
    assert_predicate submission, :month_unknown?
    assert_predicate submission, :day_unknown?
  end

  test 'rejects a year that is not 4 digits' do
    submission = TrendSubmission.new(valid_attributes.except(:date).merge(year: '26', month: '3', day: '15'))

    assert_not submission.valid?
    assert_includes submission.errors[:year], 'は4桁の数字で入力してください'
  end

  test 'adds a date error when year/month/day form a nonexistent date' do
    submission = TrendSubmission.new(valid_attributes.except(:date).merge(year: '2026', month: '2', day: '30'))

    assert_not submission.valid?
    assert_includes submission.errors[:date], 'が正しくありません（存在しない日付です）'
  end
end
