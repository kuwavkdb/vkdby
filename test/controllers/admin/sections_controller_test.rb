# frozen_string_literal: true

require 'test_helper'

module Admin
  class SectionsControllerTest < ActionDispatch::IntegrationTest # rubocop:disable Metrics/ClassLength
    setup do
      post login_path, params: { email: users(:one).email, password: 'password' }
    end

    test 'preview renders plugin macros via ApplicationHelper#markdown' do
      unit = Unit.create!(name: 'Preview Plugin Unit', key: 'sections-preview-plugin-unit', status: :active)

      post preview_admin_sections_path, params: {
        sectionable_type: 'Unit', sectionable_id: unit.id, body: '{{youtube C-PqwPsrDd0}}'
      }

      assert_response :success
      assert_includes response.parsed_body['html'], 'youtube.com/embed/C-PqwPsrDd0'
    end

    test 'preview resolves self-referencing include plugin against the given sectionable (issue #1193)' do
      unit = Unit.create!(name: 'Preview Include Unit', key: 'sections-preview-include-unit', status: :active)
      unit.sections.create!(name: 'greeting', markdown: 'こんにちは')

      post preview_admin_sections_path, params: {
        sectionable_type: 'Unit', sectionable_id: unit.id, body: '{{include ,greeting}}'
      }

      assert_response :success
      assert_equal '<p>こんにちは</p>', response.parsed_body['html'].strip
    end

    test 'preview does not expand include plugin for an inactive section' do
      unit = Unit.create!(name: 'Preview Inactive Include Unit', key: 'sections-preview-inactive-include-unit',
                          status: :active)
      unit.sections.create!(name: 'greeting', markdown: 'こんにちは', active: false)

      post preview_admin_sections_path, params: {
        sectionable_type: 'Unit', sectionable_id: unit.id, body: '{{include ,greeting}}'
      }

      assert_response :success
      assert_equal '', response.parsed_body['html'].strip
    end

    test 'update can toggle active off and on' do
      unit = Unit.create!(name: 'Toggle Active Unit', key: 'sections-toggle-active-unit', status: :active)
      section = unit.sections.create!(name: 'about', markdown: '本文')

      patch admin_section_path(section), params: { section: { active: false } }
      assert_redirected_to edit_admin_unit_path(unit)
      assert_not section.reload.active?

      patch admin_section_path(section), params: { section: { active: true } }
      assert section.reload.active?
    end

    test 'create/edit/redirect works for an Item sectionable' do
      item = Item.create!(title: 'Section Target Item', release_date: Date.current,
                          link_url: "https://example.com/section-target-item-#{SecureRandom.hex(4)}")

      post admin_sections_path, params: {
        sectionable_type: 'Item', sectionable_id: item.id,
        section: { name: 'about', wiki_text: '本文です' }
      }

      section = item.sections.last
      assert_redirected_to edit_admin_item_path(item)
      assert_equal '本文です', section.wiki_text

      get edit_admin_section_path(section)
      assert_response :success
      assert_select "a[href='#{edit_admin_item_path(item)}']", text: /Section Target Item/

      patch admin_section_path(section), params: { section: { wiki_text: '更新後の本文' } }
      assert_redirected_to edit_admin_item_path(item)
      assert_equal '更新後の本文', section.reload.wiki_text
    end

    test 'edit画面の下部にMarkdownヘルプが表示される' do
      unit = Unit.create!(name: 'Help Display Unit', key: 'sections-help-display-unit', status: :active)
      section = unit.sections.create!(name: 'about', markdown: '本文')

      get edit_admin_section_path(section)

      assert_response :success
      assert_select 'summary', text: /Markdownプラグイン一覧/
    end

    test 'edit画面のMarkdown欄にプレビューボタンがある' do
      unit = Unit.create!(name: 'Preview Button Unit', key: 'sections-preview-button-unit', status: :active)
      section = unit.sections.create!(name: 'about', markdown: '本文')

      get edit_admin_section_path(section)

      assert_response :success
      assert_select "button[data-action*='markdown-preview#serverPreview']", text: 'Markdownプレビュー'
    end

    test 'edit画面の右上に紐づくUnitへの導線リンクがある' do
      unit = Unit.create!(name: 'Linked Unit', key: 'sections-linked-unit', status: :active)
      section = unit.sections.create!(name: 'about', markdown: '本文')

      get edit_admin_section_path(section)

      assert_response :success
      assert_select "a[href='#{edit_admin_unit_path(unit)}']", text: /Linked Unit/
    end

    test 'edit画面の削除ボタンはページ下部に配置される（issue #1193 フォローアップ）' do
      unit = Unit.create!(name: 'Delete Button Unit', key: 'sections-delete-button-unit', status: :active)
      section = unit.sections.create!(name: 'about', markdown: '本文')

      get edit_admin_section_path(section)

      assert_response :success
      assert_select "form[action='#{admin_section_path(section)}'] button", text: '削除'
    end

    test 'edit/new画面のヘッダーが上部に固定表示される（sticky）' do
      unit = Unit.create!(name: 'Sticky Header Unit', key: 'sections-sticky-header-unit', status: :active)
      section = unit.sections.create!(name: 'about', markdown: '本文')

      get edit_admin_section_path(section)
      assert_response :success
      assert_select '.sticky.top-0 h1', text: /セクション編集/

      get new_admin_section_path(sectionable_type: 'Unit', sectionable_id: unit.id)
      assert_response :success
      assert_select '.sticky.top-0 h1', text: /セクション追加/
    end

    test 'フッタのキャンセル・プレビューボタンの並び順がCustomPage編集画面と統一されている' do
      unit = Unit.create!(name: 'Button Order Unit', key: 'sections-button-order-unit', status: :active)
      section = unit.sections.create!(name: 'about', markdown: '本文')

      get edit_admin_section_path(section)

      assert_response :success
      cancel_index = response.body.index('キャンセル')
      preview_index = response.body.index('Markdownプレビュー')
      assert_operator cancel_index, :<, preview_index,
                      'キャンセルボタンはプレビューボタンより前に表示されるべき（CustomPage編集画面と同じ並び）'
    end
  end
end
