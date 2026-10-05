# frozen_string_literal: true

require 'test_helper'

module Admin
  class UnitsControllerTest < ActionDispatch::IntegrationTest # rubocop:disable Metrics/ClassLength
    setup do
      post login_path, params: { email: users(:one).email, password: 'password' }
      @unit = Unit.create!(name: 'Existing Unit', key: 'existing-unit-controller-test', status: :active)
    end

    test 'search finds a unit whose name is half-width when queried with full-width alphanumerics' do
      Unit.create!(name: 'ABC123', key: 'zenkaku-search-admin-units-test', status: :active)

      get search_admin_units_path(q: 'ＡＢＣ１２３')

      assert_response :success
      assert_includes response.parsed_body.pluck('name'), 'ABC123'
    end

    test 'update does not change key even when key param is submitted' do
      patch admin_unit_path(@unit), params: {
        unit: { name: 'Renamed Unit', key: 'attempted-new-key' }
      }

      assert_redirected_to edit_admin_unit_path(@unit)
      @unit.reload
      assert_equal 'existing-unit-controller-test', @unit.key
      assert_equal 'Renamed Unit', @unit.name
    end

    test 'create allows setting key' do
      assert_difference('Unit.count') do
        post admin_units_path, params: {
          unit: { name: 'Brand New Unit', key: 'brand-new-unit-key', status: 'active' }
        }
      end

      assert_equal 'brand-new-unit-key', Unit.last.key
    end

    # issue #1545: 公開の投稿フォーム(UnitSubmission)から「承認」した際、内容が新規作成フォームに
    # 引き継がれ、保存すると投稿が「変換済み」になることを確認する
    test 'new prefills the form from a pending unit submission' do
      submission = UnitSubmission.create!(name: 'Submitted Unit', name_kana: 'トウコウユニット', unit_type: 'unit',
                                          status: 'active', note: '見つからなかったので投稿します', email: 'fan@example.com',
                                          links_attributes: { '0' => { text: '公式サイト', url: 'https://example.com/submitted' } })

      get new_admin_unit_path(unit_submission_id: submission.id)

      assert_response :success
      assert_includes response.body, 'Submitted Unit'
      assert_includes response.body, 'https://example.com/submitted'
    end

    test 'create converts the pending unit submission and links it to the created unit' do
      submission = UnitSubmission.create!(name: 'Submitted Unit', unit_type: 'band', status: 'active',
                                          links_attributes: { '0' => { url: 'https://example.com/submitted' } })

      assert_difference('Unit.count') do
        post admin_units_path, params: {
          unit: { name: 'Submitted Unit', key: 'submitted-unit-key', status: 'active' },
          unit_submission_id: submission.id
        }
      end

      submission.reload
      assert_predicate submission, :converted?
      assert_equal Unit.last, submission.converted_unit
    end

    test 'create does not touch the unit submission when the unit fails to save' do
      submission = UnitSubmission.create!(name: 'Submitted Unit', unit_type: 'band', status: 'active',
                                          links_attributes: { '0' => { url: 'https://example.com/submitted' } })

      assert_no_difference('Unit.count') do
        post admin_units_path, params: {
          unit: { name: 'Submitted Unit', key: '', status: 'active' },
          unit_submission_id: submission.id
        }
      end

      assert_predicate submission.reload, :pending?
    end

    # issue #1719: 投稿画像は、adminが承認したときに選んだものをUnitの「画像」セクションへ移し、
    # 選ばなかったものは縮小して投稿に残す
    test 'new shows submission images to admins with all of them selected' do
      login_as_admin
      submission = submission_with_images(2)

      get new_admin_unit_path(unit_submission_id: submission.id)

      assert_response :success
      assert_select 'input[type=checkbox][name=?][checked]', 'unit_submission_image_ids[]', count: 2
    end

    test 'new does not show submission images to non-admins' do
      submission = submission_with_images(1)

      get new_admin_unit_path(unit_submission_id: submission.id)

      assert_response :success
      assert_select 'input[name=?]', 'unit_submission_image_ids[]', count: 0
    end

    test 'new does not show submission images without image usage consent' do
      login_as_admin
      submission = submission_with_images(1)
      submission.update_columns(image_usage_consented: false)

      get new_admin_unit_path(unit_submission_id: submission.id)

      assert_select 'input[name=?]', 'unit_submission_image_ids[]', count: 0
    end

    test 'create moves the selected submission images to a new image section and shrinks the rest' do
      login_as_admin
      submission = submission_with_images(2)
      selected, remaining = submission.images_attachments.order(:id).to_a
      shrunk = []
      # stub_class_method はキーワード引数をハッシュのまま渡す
      shrink = lambda do |file, options|
        shrunk << options
        SubmissionImageSanitizer::Result.new(io: StringIO.new(File.binread(file.path)), filename: 'small.png',
                                             content_type: 'image/png')
      end

      stub_class_method(SubmissionImageSanitizer, :call, shrink) do
        post admin_units_path, params: {
          unit: { name: 'Submitted [Unit]', key: 'submitted-unit-with-images', status: 'active' },
          unit_submission_id: submission.id,
          unit_submission_image_ids: ['', selected.id.to_s]
        }
      end

      unit = Unit.find_by!(key: 'submitted-unit-with-images')
      section = unit.sections.sole
      assert_equal UnitSubmissionImageTransfer::SECTION_NAME, section.name
      assert_predicate section, :active?
      assert_equal [selected.blob_id], section.images.map(&:blob_id)
      assert_match %r{\A!\[Submitted Unit\]\(/rails/active_storage/blobs/(?:redirect|proxy)/[^)]+\)\z}, section.markdown
      assert UpdateLog.exists?(loggable: section, action: 'create', subject: unit)

      assert_equal [{ max_dimension: 800, quality: 80, filename: 'image.png' }], shrunk
      submission.reload
      assert_predicate submission, :converted?
      assert_equal(['small.png'], submission.images.map { |image| image.filename.to_s })
      assert_not ActiveStorage::Attachment.exists?(remaining.id)
    end

    test 'create keeps the remaining images as they are when they cannot be shrunk' do
      login_as_admin
      submission = submission_with_images(1)

      stub_class_method(SubmissionImageSanitizer, :vips_available?, false) do
        post admin_units_path, params: {
          unit: { name: 'Submitted Unit', key: 'submitted-unit-unshrunk', status: 'active' },
          unit_submission_id: submission.id,
          unit_submission_image_ids: ['']
        }
      end

      assert_empty Unit.find_by!(key: 'submitted-unit-unshrunk').sections
      assert_equal(['image.png'], submission.reload.images.map { |image| image.filename.to_s })
    end

    test 'create does not transfer submission images for non-admins' do
      submission = submission_with_images(1)
      attachment = submission.images_attachments.first

      post admin_units_path, params: {
        unit: { name: 'Submitted Unit', key: 'submitted-unit-by-operator', status: 'active' },
        unit_submission_id: submission.id,
        unit_submission_image_ids: [attachment.id.to_s]
      }

      assert_predicate submission.reload, :converted?
      assert_empty Unit.find_by!(key: 'submitted-unit-by-operator').sections
      assert_equal [attachment.id], submission.images_attachments.pluck(:id)
    end

    test 'create keeps the image selection when the unit fails to save' do
      login_as_admin
      submission = submission_with_images(2)
      selected = submission.images_attachments.order(:id).first

      post admin_units_path, params: {
        unit: { name: 'Submitted Unit', key: '', status: 'active' },
        unit_submission_id: submission.id,
        unit_submission_image_ids: ['', selected.id.to_s]
      }

      assert_response :unprocessable_entity
      assert_select 'input[type=checkbox][name=?][checked]', 'unit_submission_image_ids[]', count: 1
      assert_select 'input[type=checkbox][value=?][checked]', selected.id.to_s
      assert_equal 2, submission.reload.images.count
    end

    # issue #1277: keyが空のまま作成できると、以降Unit一覧ページ(管理画面・公開ページとも)が
    # profile_path(key)のUrlGenerationErrorで全面的に500エラーになっていた
    test 'create rejects a blank key and re-renders the form' do
      assert_no_difference('Unit.count') do
        post admin_units_path, params: {
          unit: { name: 'Blank Key Unit', key: '', status: 'active' }
        }
      end

      assert_response :unprocessable_entity
    end

    test 'index still renders when a unit has a blank key' do
      Unit.new(name: 'Legacy Blank Key Unit', status: :active).save(validate: false)

      get admin_units_path

      assert_response :success
    end

    test 'change_key requires admin role' do
      patch change_key_admin_unit_path(@unit), params: { new_key: 'attempted-new-key' }

      assert_redirected_to root_path
      assert_equal 'existing-unit-controller-test', @unit.reload.key
    end

    test 'update records an UpdateLog for a link change with subject set to the unit (issue #1530)' do
      patch admin_unit_path(@unit), params: {
        unit: {
          name: @unit.name, status: @unit.status,
          links_attributes: { '0' => { text: '公式サイト', url: 'https://example.com/subject-test' } }
        }
      }

      link = @unit.links.last
      assert UpdateLog.exists?(loggable: link, action: 'create', subject: @unit)
    end

    test 'change_key updates the key and creates a redirect stub when admin' do
      login_as_admin

      patch change_key_admin_unit_path(@unit), params: { new_key: 'new-unit-key-via-endpoint' }

      assert_redirected_to edit_admin_unit_path(@unit)
      assert_nil flash[:alert]
      assert_equal 'Key changed successfully.', flash[:notice]
      assert_equal 'new-unit-key-via-endpoint', @unit.reload.key
      stub = Unit.discarded.find_by(key: 'existing-unit-controller-test')
      assert stub.present?
      assert_equal 'new-unit-key-via-endpoint', stub.destination_key
      assert UpdateLog.exists?(loggable: @unit, action: 'change_key')
    end

    test 'change_key shows an error when the new key is already taken' do
      login_as_admin
      Unit.create!(name: 'Other Unit', key: 'already-taken-key', status: :active)

      patch change_key_admin_unit_path(@unit), params: { new_key: 'already-taken-key' }

      assert_redirected_to edit_admin_unit_path(@unit)
      assert_equal 'existing-unit-controller-test', @unit.reload.key
    end

    test 'purge requires admin role' do
      @unit.change_key!('new-key-for-purge-auth-test')
      stub = Unit.discarded.find_by(key: 'existing-unit-controller-test')

      delete purge_admin_unit_path(stub)

      assert_redirected_to root_path
      assert Unit.exists?(id: stub.id)
    end

    test 'purge is rejected for a record that is not discarded' do
      login_as_admin

      delete purge_admin_unit_path(@unit)

      assert_redirected_to admin_units_path(redirect_source: 'only')
      assert_equal '論理削除済みのレコードのみ物理削除できます。', flash[:alert]
      assert Unit.exists?(id: @unit.id)
    end

    test 'purge deletes the redirect-source stub and logs the action' do
      login_as_admin
      @unit.change_key!('new-key-for-purge-test')
      stub = Unit.discarded.find_by(key: 'existing-unit-controller-test')

      delete purge_admin_unit_path(stub)

      assert_redirected_to admin_units_path(redirect_source: 'only')
      assert_equal 'リダイレクト元レコードを物理削除しました。', flash[:notice]
      assert_not Unit.exists?(id: stub.id)
      assert UpdateLog.exists?(loggable_type: 'Unit', loggable_id: stub.id, action: 'purge')
    end

    test 'purge deletes a plain discarded record without a destination_key' do
      login_as_admin
      @unit.discard

      delete purge_admin_unit_path(@unit)

      assert_redirected_to admin_units_path(redirect_source: 'only')
      assert_equal 'リダイレクト元レコードを物理削除しました。', flash[:notice]
      assert_not Unit.exists?(id: @unit.id)
      assert UpdateLog.exists?(loggable_type: 'Unit', loggable_id: @unit.id, action: 'purge')
    end

    test 'purge is rejected when the key is still referenced by an item' do
      login_as_admin
      @unit.change_key!('new-key-for-purge-item-test')
      stub = Unit.discarded.find_by(key: 'existing-unit-controller-test')
      Item.create!(title: 'Some Album', release_date: Date.current, link_url: 'https://example.com/item',
                   artists: [{ 'key' => stub.key, 'name' => 'Existing Unit' }])

      delete purge_admin_unit_path(stub)

      assert_redirected_to admin_units_path(redirect_source: 'only')
      assert_equal 'このキーはまだ作品から参照されているため物理削除できません。', flash[:alert]
      assert Unit.exists?(id: stub.id)
    end

    test 'purge is rejected when the key is still used as another redirect destination' do
      login_as_admin
      @unit.discard
      Unit.create!(name: 'Newer Unit', key: 'newer-unit-controller-test', status: :active,
                   destination_key: @unit.key).discard

      delete purge_admin_unit_path(@unit)

      assert_redirected_to admin_units_path(redirect_source: 'only')
      assert_equal 'このキーはリダイレクト先として参照されているため物理削除できません。', flash[:alert]
      assert Unit.exists?(id: @unit.id)
    end

    test 'purge is rejected when a unit_people row still references a real person' do
      login_as_admin
      person = Person.create!(name: 'Real Member', key: 'real-member-purge-test', status: :active)
      @unit.unit_people.create!(person: person, status: :active, part: :vocal)
      @unit.discard

      delete purge_admin_unit_path(@unit)

      assert_redirected_to admin_units_path(redirect_source: 'only')
      assert_equal '実在のPersonに紐づくメンバー情報が残っているため物理削除できません。', flash[:alert]
      assert Unit.exists?(id: @unit.id)
    end

    test 'purge destroys unit_people rows that only hold inline placeholder data' do
      login_as_admin
      unit_person = @unit.unit_people.create!(person_name: 'Inline Member', status: :active, part: :vocal)
      @unit.discard

      delete purge_admin_unit_path(@unit)

      assert_redirected_to admin_units_path(redirect_source: 'only')
      assert_equal 'リダイレクト元レコードを物理削除しました。', flash[:notice]
      assert_not Unit.exists?(id: @unit.id)
      assert_not UnitPerson.exists?(id: unit_person.id)
    end

    test 'purging a redirect-source stub allows reverting the key' do
      login_as_admin
      @unit.change_key!('new-key-for-purge-revert-test')
      stub = Unit.discarded.find_by(key: 'existing-unit-controller-test')

      delete purge_admin_unit_path(stub)
      @unit.reload.change_key!('existing-unit-controller-test')

      assert_equal 'existing-unit-controller-test', @unit.reload.key
    end

    test 'quick_new renders the quick create form' do
      get quick_new_admin_units_path

      assert_response :success
      assert_includes response.body, 'Unit簡単登録'
    end

    # issue #1611: URLのクエリパラメータで事前入力できることを確認する
    test 'quick_new prefills the form from query parameters' do
      get quick_new_admin_units_path, params: {
        unit: {
          name: 'Prefilled Band', key: 'prefilled-band', unit_type: 'unit', status: 'freeze',
          snapshot_date: '2024-04-01', snapshot_label: '結成時',
          members: {
            '0' => { person_name: 'Vocalist', part: 'vocal' },
            '1' => { person_name: 'Guitarist', part: 'guitar' }
          }
        }
      }

      assert_response :success
      assert_includes response.body, 'value="Prefilled Band"'
      assert_includes response.body, 'value="prefilled-band"'
      assert_includes response.body, 'value="2024-04-01"'
      assert_includes response.body, 'value="結成時"'
      assert_includes response.body, 'value="Vocalist"'
      assert_includes response.body, 'value="Guitarist"'
    end

    test 'quick_new ignores unknown enum values from query parameters' do
      get quick_new_admin_units_path, params: {
        unit: { unit_type: 'not_a_real_type', status: 'not_a_real_status' }
      }

      assert_response :success
    end

    # issue #1616: URLのクエリパラメータで活動時期・公式リンクも事前入力できることを確認する
    test 'quick_new prefills activity periods and links from query parameters' do
      get quick_new_admin_units_path, params: {
        unit: {
          name: 'Prefilled Band',
          activity_periods: { '0' => { from: '2010/01/**', to: '', label: '結成時' } },
          links: { '0' => { text: '公式サイト', url: 'https://example.com/' } }
        }
      }

      assert_response :success
      assert_includes response.body, 'value="2010/01/**"'
      assert_includes response.body, 'value="結成時"'
      assert_includes response.body, 'value="公式サイト"'
      assert_includes response.body, 'value="https://example.com/"'
    end

    # issue #1620: URLのクエリパラメータでメンバーの extra_profile（issue #1619）も事前入力できることを確認する
    test 'quick_new prefills member extra_profile from query parameters' do
      get quick_new_admin_units_path, params: {
        unit: {
          name: 'Prefilled Band',
          members: {
            '0' => { person_name: 'Vocalist', part: 'vocal', extra_profile: { birthday: '7/12', hometown: '東京都' } }
          }
        }
      }

      assert_response :success
      assert_includes response.body, 'value="7/12"'
      assert_includes response.body, 'value="東京都"'
    end

    # メンバーのSNSアカウントもURLのクエリパラメータ（配列）で事前入力できることを確認する
    test 'quick_new prefills member sns from query parameters' do
      get quick_new_admin_units_path, params: {
        unit: {
          name: 'Prefilled Band',
          members: {
            '0' => { person_name: 'Vocalist', part: 'vocal', sns: ['@vocalist_x', 'https://www.instagram.com/vocalist/'] }
          }
        }
      }

      assert_response :success
      assert_select 'textarea[name=?]', 'unit[members][0][sns]',
                    text: "@vocalist_x\nhttps://www.instagram.com/vocalist/"
    end

    test 'quick_new prefills member name_kana from query parameters' do
      get quick_new_admin_units_path, params: {
        unit: { name: 'Prefilled Band', members: { '0' => { person_name: '山田太郎', name_kana: 'ヤマダタロウ', part: 'vocal' } } }
      }

      assert_response :success
      assert_select 'input[name=?][value=?]', 'unit[members][0][name_kana]', 'ヤマダタロウ'
    end

    # issue #1611: URL経由で渡されたキーが既存Unitと重複している場合、保存前に警告と
    # 重複先の編集画面へのリンクを表示する
    test 'quick_new warns with a link to the existing unit when the prefilled key is already in use' do
      get quick_new_admin_units_path, params: { unit: { key: @unit.key } }

      assert_response :success
      assert_includes response.body, 'このキーはすでに'
      assert_includes response.body, @unit.name
      assert_includes response.body, edit_admin_unit_path(@unit)
    end

    test 'quick_new detects a duplicated key case-insensitively' do
      get quick_new_admin_units_path, params: { unit: { key: @unit.key.upcase } }

      assert_response :success
      assert_includes response.body, 'このキーはすでに'
      assert_includes response.body, edit_admin_unit_path(@unit)
    end

    test 'quick_new does not warn when the key is unique' do
      get quick_new_admin_units_path, params: { unit: { key: 'brand-new-unique-key' } }

      assert_response :success
      assert_not_includes response.body, 'このキーはすでに'
    end

    test 'quick_new does not warn when no key is given' do
      get quick_new_admin_units_path

      assert_response :success
      assert_not_includes response.body, 'このキーはすでに'
    end

    test 'quick_new warns and links to the unit even when the duplicated key belongs to a discarded unit' do
      @unit.discard

      get quick_new_admin_units_path, params: { unit: { key: @unit.key } }

      assert_response :success
      assert_includes response.body, 'このキーはすでに'
      assert_includes response.body, '（削除済み）'
      assert_includes response.body, edit_admin_unit_path(@unit)
    end

    # issue #1596: バンド名・メンバー名をまとめて入力し、Unit・現在のラインナップ用のUnitSnapshot・
    # SnapshotPersonを1回のsubmitで一括作成できることを確認する
    test 'quick_create creates the unit, a current snapshot, and its members in one submission' do
      assert_difference('Unit.count' => 1, 'UnitSnapshot.count' => 1, 'SnapshotPerson.count' => 2) do
        post quick_create_admin_units_path, params: {
          unit: {
            name: 'Quick Created Band', key: 'quick-created-band', unit_type: 'band', status: 'active',
            snapshot_date: '2024/04/01', snapshot_label: '結成時',
            members: {
              '0' => { person_name: 'Vocalist', part: 'vocal' },
              '1' => { person_name: 'Guitarist', part: 'guitar' },
              '2' => { person_name: '', part: 'bass' }
            }
          }
        }
      end

      unit = Unit.find_by(key: 'quick-created-band')
      assert_redirected_to edit_admin_unit_path(unit)
      assert_equal 'band', unit.unit_type
      snapshot = unit.unit_snapshots.sole
      assert snapshot.current?
      assert snapshot.active?
      assert_equal '結成時', snapshot.label
      assert_equal Date.new(2024, 4, 1), snapshot.snapshot_date
      assert_equal %w[Vocalist Guitarist], snapshot.snapshot_people.order(:sort_order).map(&:person_name)
      assert UpdateLog.exists?(loggable: unit, action: 'create', subject: unit)
      assert UpdateLog.exists?(loggable: snapshot, action: 'create', subject: unit)
      snapshot.snapshot_people.each do |sp|
        assert UpdateLog.exists?(loggable: sp, action: 'create', subject: unit)
      end
    end

    # issue #1616: 活動時期・公式リンクも一括作成できることを確認する
    test 'quick_create saves activity periods and links along with the unit' do
      assert_difference('Unit.count' => 1, 'Link.count' => 1) do
        post quick_create_admin_units_path, params: {
          unit: {
            name: 'Band With Links', key: 'band-with-links', unit_type: 'band', status: 'active',
            activity_periods: { '0' => { from: '2010/01/**', to: '', label: '結成時' } },
            links: { '0' => { text: '公式サイト', url: 'https://example.com/' } },
            members: { '0' => { person_name: 'Vocalist', part: 'vocal' } }
          }
        }
      end

      unit = Unit.find_by(key: 'band-with-links')
      assert_redirected_to edit_admin_unit_path(unit)
      assert_equal [{ 'from' => '2010/01/**', 'to' => nil, 'label' => '結成時' }], unit.activity_period
      assert_equal 'https://example.com/', unit.links.sole.url
      assert_equal '公式サイト', unit.links.sole.text
    end

    # issue #1620: YAML貼り付け機能で入力される extra_profile（issue #1619）も
    # quick_create で一括作成できることを確認する
    test 'quick_create saves member extra_profile along with the unit' do
      assert_difference('Unit.count' => 1, 'SnapshotPerson.count' => 1) do
        post quick_create_admin_units_path, params: {
          unit: {
            name: 'Band With Profile', key: 'band-with-profile', unit_type: 'band', status: 'active',
            members: {
              '0' => {
                person_name: 'Vocalist', part: 'vocal',
                extra_profile: { birthday: '7/12', birth_year: '1990', blood: 'AB', hometown: '東京都' }
              }
            }
          }
        }
      end

      unit = Unit.find_by(key: 'band-with-profile')
      snapshot_person = unit.unit_snapshots.sole.snapshot_people.sole
      assert_equal(
        { 'birthday' => '7/12', 'birth_year' => '1990', 'blood' => 'AB', 'hometown' => '東京都' },
        snapshot_person.extra_profile
      )
    end

    test 'quick_create drops blank extra_profile fields' do
      post quick_create_admin_units_path, params: {
        unit: {
          name: 'Band With Blank Profile', key: 'band-with-blank-profile', unit_type: 'band', status: 'active',
          members: {
            '0' => { person_name: 'Vocalist', part: 'vocal', extra_profile: { birthday: '', blood: 'O' } }
          }
        }
      }

      unit = Unit.find_by(key: 'band-with-blank-profile')
      snapshot_person = unit.unit_snapshots.sole.snapshot_people.sole
      assert_equal({ 'blood' => 'O' }, snapshot_person.extra_profile)
    end

    # YAML貼り付け機能で入力されるメンバーのSNSアカウント（テキストエリアに1行1アカウント）を
    # SnapshotPerson#sns として保存できることを確認する
    test 'quick_create saves member sns along with the unit' do
      post quick_create_admin_units_path, params: {
        unit: {
          name: 'Band With Sns', key: 'band-with-sns', unit_type: 'band', status: 'active',
          members: {
            '0' => { person_name: 'Vocalist', part: 'vocal', sns: "@vocalist_x\r\n\r\nhttps://www.instagram.com/vocalist/\n" },
            '1' => { person_name: 'Guitarist', part: 'guitar', sns: '' }
          }
        }
      }

      unit = Unit.find_by(key: 'band-with-sns')
      vocalist, guitarist = unit.unit_snapshots.sole.snapshot_people.order(:sort_order).to_a
      assert_equal ['@vocalist_x', 'https://www.instagram.com/vocalist/'], vocalist.sns
      assert_nil guitarist.sns
    end

    # メンバーのヨミガナは SnapshotPerson にカラムが無いため、extra_profile の name_kana として保存する
    test 'quick_create saves member name_kana into extra_profile' do
      post quick_create_admin_units_path, params: {
        unit: {
          name: 'Band With Kana', key: 'band-with-kana', unit_type: 'band', status: 'active',
          members: {
            '0' => { person_name: '山田太郎', name_kana: ' ヤマダタロウ ', part: 'vocal', extra_profile: { blood: 'O' } },
            '1' => { person_name: 'Guitarist', name_kana: '', part: 'guitar' }
          }
        }
      }

      unit = Unit.find_by(key: 'band-with-kana')
      vocalist, guitarist = unit.unit_snapshots.sole.snapshot_people.order(:sort_order).to_a
      assert_equal({ 'blood' => 'O', 'name_kana' => 'ヤマダタロウ' }, vocalist.extra_profile)
      assert_nil guitarist.extra_profile
    end

    test 'quick_create rolls back the unit and snapshot when the unit is invalid' do
      assert_no_difference(['Unit.count', 'UnitSnapshot.count', 'SnapshotPerson.count']) do
        post quick_create_admin_units_path, params: {
          unit: {
            name: 'Invalid Band', key: '', status: 'active',
            members: { '0' => { person_name: 'Vocalist', part: 'vocal' } }
          }
        }
      end

      assert_response :unprocessable_entity
    end

    test 'edit shows the change key form for admin' do
      login_as_admin

      get edit_admin_unit_path(@unit)

      assert_response :success
      assert_includes response.body, 'キー変更'
    end

    test 'edit does not show the change key form for non-admin' do
      get edit_admin_unit_path(@unit)

      assert_response :success
      assert_not_includes response.body, 'キー変更'
    end

    test 'edit shows the discard button for super_operator or above' do
      get edit_admin_unit_path(@unit)

      assert_response :success
      assert_includes response.body, '論理削除'
    end

    test 'edit does not show the discard button for operator' do
      login_as_operator

      get edit_admin_unit_path(@unit)

      assert_response :success
      assert_not_includes response.body, '論理削除'
    end

    test 'edit does not show the discard button for an already discarded unit' do
      @unit.discard

      get edit_admin_unit_path(@unit)

      assert_response :success
      assert_not_includes response.body, '論理削除'
    end

    test 'index renders tag filter comboboxes only for groups and tags visible on units' do
      group = IndexGroup.create!(name: '属性グループ', units_filter_order: 1)
      hidden_group = IndexGroup.create!(name: '非表示グループ', units_filter_order: nil)
      TagIndex.create!(name: '有効タグ', index_group: group, order_in_group: 1)
      TagIndex.create!(name: '無効タグ', index_group: group, active: false)
      TagIndex.create!(name: '孤立タグ', index_group: hidden_group)

      # q で一致しない検索にして、key が未設定なfixtureのUnitが一覧描画でエラーにならないようにする
      get admin_units_path(q: 'no-such-unit-zzz')

      assert_response :success
      assert_includes response.body, '属性グループ'
      assert_includes response.body, '有効タグ'
      assert_not_includes response.body, '無効タグ'
      assert_not_includes response.body, '非表示グループ'
      assert_not_includes response.body, '孤立タグ'
    end

    test 'index filters units by tag_index_id selected from the tag filter' do
      group = IndexGroup.create!(name: '属性グループ', units_filter_order: 1)
      tag = TagIndex.create!(name: '有効タグ', index_group: group, order_in_group: 1)
      TagIndexItem.create!(tag_index: tag, indexable: @unit)
      other_unit = Unit.create!(name: 'Other Unit', key: 'other-unit-controller-test', status: :active)

      get admin_units_path(tag_index_id: tag.id)

      assert_response :success
      assert_includes response.body, @unit.name
      assert_not_includes response.body, other_unit.name
    end

    test 'index filters units by status' do
      frozen_unit = Unit.create!(name: 'Frozen Unit', key: 'frozen-unit-controller-test', status: :freeze, unit_type: :band)

      get admin_units_path(status: 'freeze')

      assert_response :success
      assert_includes response.body, frozen_unit.name
      assert_not_includes response.body, @unit.name
    end

    test 'index combines tag_index_id and status filters' do
      group = IndexGroup.create!(name: '属性グループ', units_filter_order: 1)
      tag = TagIndex.create!(name: '有効タグ', index_group: group, order_in_group: 1)
      tagged_active = Unit.create!(name: 'Tagged Active Unit', key: 'tagged-active-unit-test', status: :active)
      tagged_frozen = Unit.create!(name: 'Tagged Frozen Unit', key: 'tagged-frozen-unit-test', status: :freeze)
      TagIndexItem.create!(tag_index: tag, indexable: tagged_active)
      TagIndexItem.create!(tag_index: tag, indexable: tagged_frozen)

      get admin_units_path(tag_index_id: tag.id, status: 'freeze')

      assert_response :success
      assert_includes response.body, tagged_frozen.name
      assert_not_includes response.body, tagged_active.name
    end

    test 'bulk_update_status requires admin role' do
      other_unit = Unit.create!(name: 'Other Unit', key: 'bulk-status-auth-unit', status: :active)

      patch bulk_update_status_admin_units_path, params: { ids: [@unit.id, other_unit.id], status: 'freeze' }

      assert_redirected_to root_path
      assert_equal 'active', @unit.reload.status
      assert_equal 'active', other_unit.reload.status
    end

    test 'bulk_update_status updates the status of the selected units and logs each change' do
      login_as_admin
      other_unit = Unit.create!(name: 'Other Unit', key: 'bulk-status-unit', status: :active)

      patch bulk_update_status_admin_units_path, params: { ids: [@unit.id, other_unit.id], status: 'freeze' }

      assert_redirected_to admin_units_path
      assert_equal '2件のStatusを更新しました', flash[:notice]
      assert_equal 'freeze', @unit.reload.status
      assert_equal 'freeze', other_unit.reload.status
      assert UpdateLog.exists?(loggable: @unit, action: 'update')
      assert UpdateLog.exists?(loggable: other_unit, action: 'update')
    end

    test 'bulk_update_status shows an alert when no ids are selected' do
      login_as_admin

      patch bulk_update_status_admin_units_path, params: { ids: [], status: 'freeze' }

      assert_redirected_to admin_units_path
      assert_equal '項目が選択されていません', flash[:alert]
    end

    test 'bulk_update_status shows an alert for an invalid status' do
      login_as_admin

      patch bulk_update_status_admin_units_path, params: { ids: [@unit.id], status: 'not-a-real-status' }

      assert_redirected_to admin_units_path
      assert_equal 'Statusを選択してください', flash[:alert]
      assert_equal 'active', @unit.reload.status
    end

    test 'edit shows unit snapshots with current first, then ordered by display order' do
      third = @unit.unit_snapshots.create!(label: 'Snapshot Third', snapshot_date: '2024-03-01', snapshot_index: 3)
      first = @unit.unit_snapshots.create!(label: 'Snapshot First', snapshot_date: '2024-01-01', snapshot_index: 1)
      current = @unit.unit_snapshots.create!(label: 'Snapshot Current', snapshot_date: '2024-02-01', snapshot_index: 2,
                                             current: true)

      get edit_admin_unit_path(@unit)

      assert_response :success
      body = response.body
      positions = [current, first, third].map { |snapshot| body.index(snapshot.label) }
      assert positions.all?, 'expected all snapshot labels to appear in the response body'
      assert_equal positions, positions.sort
    end

    test 'edit shows past snapshots after non-past snapshots' do
      related = @unit.unit_snapshots.create!(label: 'Snapshot Related', snapshot_date: '2020-01-01',
                                             snapshot_index: 1, past: true)
      members = @unit.unit_snapshots.create!(label: 'Snapshot Members', snapshot_date: '2024-01-01',
                                             snapshot_index: 2, past: false)

      get edit_admin_unit_path(@unit)

      assert_response :success
      assert_operator response.body.index(members.label), :<, response.body.index(related.label)
    end

    # issue #1764: 簡単登録のメモ・仮登録
    test 'quick_create saves the note and always creates a provisional unit for a non-admin user' do
      post quick_create_admin_units_path, params: {
        unit: { name: 'Provisional Band', key: 'provisional-band-non-admin', note: '情報源: https://example.com/',
                provisional: '0', members: { '0' => { person_name: 'Vo', part: 'vocal' } } }
      }

      unit = Unit.find_by(key: 'provisional-band-non-admin')
      assert_redirected_to edit_admin_unit_path(unit)
      assert_equal '情報源: https://example.com/', unit.note
      assert unit.provisional?
    end

    test 'quick_create lets an admin create a public unit by unchecking provisional' do
      login_as_admin

      post quick_create_admin_units_path, params: {
        unit: { name: 'Public Band', key: 'public-band-by-admin', provisional: '0' }
      }

      assert_not Unit.find_by(key: 'public-band-by-admin').provisional?
    end

    test 'quick_create keeps an admin unit provisional when the checkbox stays checked' do
      login_as_admin

      post quick_create_admin_units_path, params: {
        unit: { name: 'Admin Provisional Band', key: 'provisional-band-by-admin', provisional: '1' }
      }

      assert Unit.find_by(key: 'provisional-band-by-admin').provisional?
    end

    test 'quick_new shows the provisional checkbox checked only for an admin' do
      get quick_new_admin_units_path

      assert_response :success
      assert_select 'input[type=checkbox][name="unit[provisional]"]', count: 0
      assert_select 'textarea[name="unit[note]"]'

      login_as_admin
      get quick_new_admin_units_path(unit: { note: '事前入力メモ' })

      assert_select 'input[type=checkbox][name="unit[provisional]"][checked]'
      assert_select 'textarea[name="unit[note]"]', text: /事前入力メモ/
    end

    test 'update does not change provisional' do
      @unit.update!(provisional: true)

      patch admin_unit_path(@unit), params: { unit: { name: 'Still Provisional', provisional: '0' } }

      assert @unit.reload.provisional?
    end

    test 'confirm_provisional requires admin role' do
      @unit.update!(provisional: true)

      patch confirm_provisional_admin_unit_path(@unit)

      assert @unit.reload.provisional?
    end

    test 'confirm_provisional makes the unit public and records an update log' do
      @unit.update!(provisional: true)
      snapshot = @unit.unit_snapshots.create!(current: true, active: true)
      snapshot.update_columns(updated_at: 1.day.ago)
      login_as_admin

      patch confirm_provisional_admin_unit_path(@unit)

      assert_redirected_to edit_admin_unit_path(@unit)
      assert_not @unit.reload.provisional?
      assert UpdateLog.exists?(loggable: @unit, action: 'update')
      assert_operator snapshot.reload.updated_at, :>, 1.minute.ago
    end

    test 'index can be filtered to provisional units only' do
      Unit.create!(name: 'Listed Provisional Unit', key: 'listed-provisional-unit', unit_type: :band, provisional: true)

      get admin_units_path(provisional: 'only')

      assert_response :success
      assert_includes response.body, 'Listed Provisional Unit'
      assert_not_includes response.body, 'Existing Unit'
      assert_includes response.body, '仮登録のみ（1件）'
    end

    private

    def login_as_admin
      admin = User.create!(email: 'admin-key-change-test@example.com', name: 'Admin', password: 'password', role: :admin)
      post login_path, params: { email: admin.email, password: 'password' }
    end

    def login_as_operator
      operator = User.create!(email: 'operator-discard-test@example.com', name: 'Operator', password: 'password', role: :operator)
      post login_path, params: { email: operator.email, password: 'password' }
    end

    def submission_with_images(count)
      submission = UnitSubmission.create!(name: 'Submitted Unit', unit_type: 'band', status: 'active',
                                          is_related_person: true, image_usage_consented: true,
                                          links_attributes: { '0' => { url: 'https://example.com/submitted' } })
      count.times do
        submission.images.attach(io: file_fixture('submission_image.png').open, filename: 'image.png',
                                 content_type: 'image/png')
      end
      submission
    end
  end
end
