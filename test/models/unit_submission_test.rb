# frozen_string_literal: true

require 'test_helper'

# == Schema Information
#
# Table name: unit_submissions
#
#  id                :bigint           not null, primary key
#  email             :string
#  is_related_person :boolean          default(FALSE), not null
#  name              :string           not null
#  name_kana         :string
#  note              :text
#  status            :integer
#  submission_status :integer          default(0), not null
#  submitter_ip      :string
#  unit_type         :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  converted_unit_id :bigint
#
# Indexes
#
#  index_unit_submissions_on_converted_unit_id  (converted_unit_id)
#  index_unit_submissions_on_submission_status  (submission_status)
#
# Foreign Keys
#
#  fk_rails_...  (converted_unit_id => units.id)
#
class UnitSubmissionTest < ActiveSupport::TestCase
  def valid_attributes
    {
      name: 'Test Unit', unit_type: :band, status: :active,
      links_attributes: { '0' => { url: 'https://example.com' } }
    }
  end

  test 'name is required' do
    submission = UnitSubmission.new(valid_attributes.merge(name: ''))

    assert_not submission.valid?
    assert_includes submission.errors[:name], 'を入力してください'
  end

  test 'at least one link is required' do
    submission = UnitSubmission.new(name: 'No Link Unit')

    assert_not submission.valid?
    assert_includes submission.errors[:base], 'リンクを1件以上入力してください'
  end

  test 'blank links are rejected via reject_if and do not count toward the link requirement' do
    submission = UnitSubmission.new(name: 'Blank Link Unit', links_attributes: { '0' => { url: '' } })

    assert_not submission.valid?
    assert_includes submission.errors[:base], 'リンクを1件以上入力してください'
  end

  test 'saves successfully with a name and at least one link' do
    submission = UnitSubmission.new(valid_attributes)

    assert submission.save
    assert_equal 1, submission.links.count
    assert_equal 'https://example.com', submission.links.first.url
  end

  test 'defaults to pending submission_status' do
    submission = UnitSubmission.create!(valid_attributes)

    assert_predicate submission, :pending?
  end

  test 'converted_unit can reference a Unit' do
    unit = Unit.create!(name: 'Converted Target', key: 'unit-submission-converted-target', status: :active)
    submission = UnitSubmission.create!(valid_attributes.merge(submission_status: :converted, converted_unit: unit))

    assert_equal unit, submission.reload.converted_unit
  end
end
