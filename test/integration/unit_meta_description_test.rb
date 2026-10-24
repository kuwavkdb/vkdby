# frozen_string_literal: true

require 'test_helper'

# ユニットのページのmeta description（issue #1937）
class UnitMetaDescriptionTest < ActionDispatch::IntegrationTest
  def meta_description
    css_select('meta[name="description"]').first['content']
  end

  test '解散したバンドは結成年・解散年と最終メンバーを書き、サポート・脱退者は含めない' do
    unit = Unit.create!(name: 'Meta Band', name_kana: 'メタバンド', key: 'meta-band', status: :disbanded, unit_type: :band,
                        activity_period: [{ 'from' => '2012/04/**', 'to' => '2014/**/**' },
                                          { 'from' => '2016/01/01', 'to' => '2018/12/24' }])
    snapshot = unit.unit_snapshots.create!(snapshot_date: Date.new(2018, 1, 1), current: true)
    snapshot.snapshot_people.create!(person_name: 'ボーカル', part: :vocal, sort_order: 1)
    snapshot.snapshot_people.create!(person_name: 'ギター', part: :guitar, sort_order: 2)
    snapshot.snapshot_people.create!(person_name: '脱退者', part: :bass, status: :left, sort_order: 3)
    snapshot.snapshot_people.create!(person_name: 'サポート', part: :drums, support: true, sort_order: 4)

    get profile_path(unit.key)

    assert_equal 'Meta Band（メタバンド）は2012年結成、2018年解散のバンド。最終メンバーはボーカル、ギター。' \
                 'バンドの歴史やメンバーの経歴、音源等を掲載。', meta_description
    assert_equal meta_description, css_select('meta[property="og:description"]').first['content']
  end

  test '活動休止中のバンドは結成年と活動休止中を書く' do
    unit = Unit.create!(name: 'Meta Freeze', key: 'meta-freeze', status: :freeze,
                        activity_period: [{ 'from' => '2015', 'to' => nil }])
    snapshot = unit.unit_snapshots.create!(snapshot_date: Date.new(2020, 1, 1), current: true)
    snapshot.snapshot_people.create!(person_name: 'ボーカル', part: :vocal, sort_order: 1)

    get profile_path(unit.key)

    assert_equal 'Meta Freezeは2015年結成のバンド（活動休止中）。メンバーはボーカル。' \
                 'バンドの歴史やメンバーの経歴、音源等を掲載。', meta_description
  end

  test 'ソロはアーティストとし、活動開始・活動終了と書いてメンバーは書かない' do
    unit = Unit.create!(name: 'Meta Solo', key: 'meta-solo', status: :disbanded, unit_type: :solo,
                        activity_period: [{ 'from' => '2015/**/**', 'to' => '2020/03/**' }])
    snapshot = unit.unit_snapshots.create!(snapshot_date: Date.new(2020, 1, 1), current: true)
    snapshot.snapshot_people.create!(person_name: '本人', part: :vocal, sort_order: 1)

    get profile_path(unit.key)

    assert_equal 'Meta Soloは2015年活動開始、2020年活動終了のアーティスト。アーティストの歴史や経歴、音源等を掲載。',
                 meta_description
  end

  test '活動期間もメンバーも無いバンドは名前と掲載内容だけにする' do
    unit = Unit.create!(name: 'Meta Empty', key: 'meta-empty', status: :active)

    get profile_path(unit.key)

    assert_equal 'Meta Emptyはバンド。バンドの歴史やメンバーの経歴、音源等を掲載。', meta_description
  end

  test '準備中・不明のバンドは活動期間を書かない' do
    unit = Unit.create!(name: 'Meta Unknown', key: 'meta-unknown', status: :unknown,
                        activity_period: [{ 'from' => '2010', 'to' => '2011' }])

    get profile_path(unit.key)

    assert_equal 'Meta Unknownはバンド。バンドの歴史やメンバーの経歴、音源等を掲載。', meta_description
  end

  test '非公開のユニットはサイト共通の説明文のままにする' do
    unit = Unit.create!(name: 'Meta Unpublished', key: 'meta-unpublished', status: :active)
    tag_index = TagIndex.create!(id: Rails.application.config.unpublished_tag_ids.first, name: '掲載停止')
    TagIndexItem.create!(tag_index: tag_index, indexable: unit)

    get profile_path(unit.key)

    assert_equal Rails.application.config.site_description, meta_description
  end
end
