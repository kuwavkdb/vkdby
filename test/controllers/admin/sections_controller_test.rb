# frozen_string_literal: true

require 'test_helper'

module Admin
  class SectionsControllerTest < ActionDispatch::IntegrationTest
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
      assert_select "button[data-action*='markdown-preview#serverPreview']", text: 'プレビュー'
    end
  end
end
