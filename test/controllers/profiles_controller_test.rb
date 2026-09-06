# frozen_string_literal: true

require 'test_helper'

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  test 'should show unit with dot in key' do
    unit = Unit.create!(name: 'Sick.', key: 'sick.', old_key: 'Sick.', status: :active)
    get profile_path(unit.key)
    assert_response :success
  end

  test 'should show person with dot in key' do
    person = Person.create!(name: 'Mr.Dot', key: 'mr.dot', old_key: 'Mr.Dot', status: :active)
    get profile_path(person.key)
    assert_response :success
  end

  test 'accessing a unit by its previous key redirects to the current key after change_key!' do
    unit = Unit.create!(name: 'Renamed Unit', key: 'unit-redirect-before', status: :active)
    unit.change_key!('unit-redirect-after')

    get profile_path('unit-redirect-before')

    assert_response :moved_permanently
    assert_redirected_to profile_path('unit-redirect-after')

    follow_redirect!
    assert_response :success
    assert_includes response.body, 'Renamed Unit'
  end

  test 'accessing a person by its previous key redirects to the current key after change_key!' do
    person = Person.create!(name: 'Renamed Person', key: 'person-redirect-before', status: :active)
    person.change_key!('person-redirect-after')

    get profile_path('person-redirect-before')

    assert_response :moved_permanently
    assert_redirected_to profile_path('person-redirect-after')

    follow_redirect!
    assert_response :success
    assert_includes response.body, 'Renamed Person'
  end

  test 'accessing a key renamed twice requires two redirect hops to reach the final key' do
    unit = Unit.create!(name: 'Twice Renamed Unit', key: 'unit-chain-a', status: :active)
    unit.change_key!('unit-chain-b')
    unit.change_key!('unit-chain-c')

    get profile_path('unit-chain-a')
    assert_response :moved_permanently
    assert_redirected_to profile_path('unit-chain-b')

    follow_redirect!
    assert_response :moved_permanently
    assert_redirected_to profile_path('unit-chain-c')

    follow_redirect!
    assert_response :success
    assert_includes response.body, 'Twice Renamed Unit'
  end

  test 'shows an unpublished message instead of content for a person tagged as unpublished' do
    person = Person.create!(name: 'Unpublished Person', key: 'person-unpublished-page', status: :active)
    tag_index = TagIndex.create!(id: Rails.application.config.unpublished_tag_ids.first, name: '掲載停止')
    TagIndexItem.create!(tag_index: tag_index, indexable: person)

    get profile_path(person.key)

    assert_response :success
    assert_includes response.body, 'Unpublished Person'
    assert_includes response.body, '諸事情により掲載を停止しております。'
  end

  test 'shows an unpublished message instead of content for a unit tagged as unpublished' do
    unit = Unit.create!(name: 'Unpublished Unit', key: 'unit-unpublished-page', status: :active)
    tag_index = TagIndex.create!(id: Rails.application.config.unpublished_tag_ids.first, name: '掲載停止')
    TagIndexItem.create!(tag_index: tag_index, indexable: unit)

    get profile_path(unit.key)

    assert_response :success
    assert_includes response.body, 'Unpublished Unit'
    assert_includes response.body, '諸事情により掲載を停止しております。'
  end

  test 'shows an active section but hides an inactive section' do
    unit = Unit.create!(name: 'Section Visibility Unit', key: 'unit-section-visibility', status: :active)
    unit.sections.create!(name: 'Visible Note', markdown: 'active section body')
    unit.sections.create!(name: 'Hidden Note', markdown: 'inactive section body', active: false)

    get profile_path(unit.key)

    assert_response :success
    assert_includes response.body, 'active section body'
    assert_not_includes response.body, 'inactive section body'
  end

  test 'does not render a canonical tag when canonical_host is not configured' do
    unit = Unit.create!(name: 'No Canonical Unit', key: 'unit-no-canonical', status: :active)
    get profile_path(unit.key)
    assert_response :success
    assert_not_includes response.body, 'rel="canonical"'
  end

  test 'renders a canonical tag pointing at the configured canonical host' do
    unit = Unit.create!(name: 'Canonical Unit', key: 'unit-canonical', status: :active)
    with_canonical_host('www.vkdb.jp') { get profile_path(unit.key) }
    assert_response :success
    assert_includes response.body, "<link rel=\"canonical\" href=\"https://www.vkdb.jp#{profile_path(unit.key)}\">"
  end

  test 'renders og:image pointing at the generated per-unit banner (issue #1259)' do
    skip 'libvips is not installed in this environment' unless ActiveStorage::VIPS_AVAILABLE

    unit = Unit.create!(name: 'OGP Image Unit', key: 'unit-ogp-image', status: :active)
    get profile_path(unit.key)

    assert_response :success
    assert_includes response.body, 'property="og:image" content="http://www.example.com/rails/active_storage/'
  end

  test 'falls back to the default og:image when the per-page image cannot be generated' do
    unit = Unit.create!(name: 'Fallback Image Unit', key: 'unit-ogp-fallback', status: :active)

    stub_class_method(OgpImageGenerator, :call, nil) { get profile_path(unit.key) }

    assert_response :success
    assert_includes response.body,
                    "property=\"og:image\" content=\"http://www.example.com#{Rails.application.config.site_ogp_image_path}\""
  end

  test 'does not render the comments section when DISQUS_SHORTNAME is not configured' do
    unit = Unit.create!(name: 'No Disqus Unit', key: 'unit-no-disqus', status: :active)
    get profile_path(unit.key)
    assert_response :success
    assert_not_includes response.body, 'id="comments"'
  end

  test 'renders the comments section pointing at the old www.vkdb.jp URL when old_key is present' do
    unit = Unit.create!(name: 'Disqus Unit', key: 'unit-disqus', old_key: 'DisqusUnit', status: :active)
    with_disqus_shortname('vkdbjp') { get profile_path(unit.key) }
    assert_response :success
    assert_includes response.body, 'id="comments"'
    assert_includes response.body, 'data-disqus-shortname="vkdbjp"'
    assert_includes response.body, 'data-disqus-page-url="https://www.vkdb.jp/DisqusUnit.html"'
  end

  test 'renders the comments section without a page-url override when old_key is absent' do
    unit = Unit.create!(name: 'New Disqus Unit', key: 'unit-disqus-no-old-key', status: :active)
    with_disqus_shortname('vkdbjp') { get profile_path(unit.key) }
    assert_response :success
    assert_includes response.body, 'id="comments"'
    assert_includes response.body, 'data-disqus-page-url=""'
  end

  test 'does not render the comments section for an unpublished resource even when DISQUS_SHORTNAME is configured' do
    unit = Unit.create!(name: 'Unpublished Disqus Unit', key: 'unit-unpublished-disqus', status: :active)
    tag_index = TagIndex.create!(id: Rails.application.config.unpublished_tag_ids.first, name: '掲載停止')
    TagIndexItem.create!(tag_index: tag_index, indexable: unit)

    with_disqus_shortname('vkdbjp') { get profile_path(unit.key) }

    assert_response :success
    assert_not_includes response.body, 'id="comments"'
  end

  test 'unit update log shows the name and part of an added snapshot member (issue #1405)' do
    unit = Unit.create!(name: 'Log Member Unit', key: 'unit-log-member', status: :active)
    snapshot = unit.unit_snapshots.create!(snapshot_date: Date.current, current: true)
    member = snapshot.snapshot_people.create!(person_name: 'テストメンバー', part: :vocal)
    UpdateLog.create!(user: users(:one), action: 'create', loggable: member, diff: nil)

    get profile_update_logs_path(unit.key)

    assert_response :success
    assert_includes response.body, '[メンバー: テストメンバー (Vocal)]'
  end

  test 'unit trend list shows the recorded name when it differs from the current unit name' do
    unit = Unit.create!(name: 'Renamed Trend Unit', key: 'unit-trend-name-badge', status: :active)
    Trend.create!(title: 'Trend before rename', date: Date.current, publish_start_at: Time.current,
                  unit_phenomenon: :other, units: [{ 'unit_id' => unit.id, 'name' => 'Old Trend Unit Name' }])

    get profile_path(unit.key)

    assert_response :success
    assert_includes response.body, 'Old Trend Unit Name'
  end

  private

  def with_canonical_host(host)
    original = Rails.application.config.canonical_host
    Rails.application.config.canonical_host = host
    yield
  ensure
    Rails.application.config.canonical_host = original
  end

  def with_disqus_shortname(shortname)
    original = ENV.fetch('DISQUS_SHORTNAME', nil)
    ENV['DISQUS_SHORTNAME'] = shortname
    yield
  ensure
    ENV['DISQUS_SHORTNAME'] = original
  end
end
