# frozen_string_literal: true

require 'test_helper'

class WikipageImporterTest < ActiveSupport::TestCase
  WikipageStub = Struct.new(:wiki, :name, :title) do
    def attributes
      {}
    end
  end

  def parse_activity_period(unit, wiki_content)
    stub = WikipageStub.new(wiki_content, 'テストバンド', 'テストバンド')
    WikipageImporter.new(stub).send(:parse_activity_period, unit)
  end

  test '活動時期にwikiリンク形式の会場情報が付加されている場合は日付のみ取り込まれる' do
    unit = units(:one)
    wiki = "*活動時期 … 2001/10/14~2007/05/05([[池袋CYBER]])\n"
    parse_activity_period(unit, wiki)
    unit.reload
    assert_equal [{ 'from' => '2001/10/14', 'to' => '2007/05/05', 'label' => nil }], unit.activity_period
  end

  test '活動時期に付加情報がない場合はそのまま取り込まれる' do
    unit = units(:one)
    wiki = "*活動時期 … 2001/10/14~2007/05/05\n"
    parse_activity_period(unit, wiki)
    unit.reload
    assert_equal [{ 'from' => '2001/10/14', 'to' => '2007/05/05', 'label' => nil }], unit.activity_period
  end

  test '終了日がない活動時期（活動中バンド）は to が nil になる' do
    unit = units(:one)
    wiki = "*活動時期 … 2005/02/15~\n"
    parse_activity_period(unit, wiki)
    unit.reload
    assert_equal [{ 'from' => '2005/02/15', 'to' => nil, 'label' => nil }], unit.activity_period
  end

  test 'ワイルドカードの開始日も取り込まれる' do
    unit = units(:one)
    wiki = "*活動時期 … 2001/05/**~2004/10/30\n"
    parse_activity_period(unit, wiki)
    unit.reload
    assert_equal [{ 'from' => '2001/05/**', 'to' => '2004/10/30', 'label' => nil }], unit.activity_period
  end

  test '終了日に活動中が含まれる場合もそのまま取り込まれる' do
    unit = units(:one)
    wiki = "*活動時期 … 1998/08/25~活動中\n"
    parse_activity_period(unit, wiki)
    unit.reload
    assert_equal [{ 'from' => '1998/08/25', 'to' => '活動中', 'label' => nil }], unit.activity_period
  end

  test 'バックスラッシュエスケープされた区切り文字（\~）が含まれる場合はバックスラッシュを除去する' do
    unit = units(:one)
    wiki = "*活動時期 … 2003/07/01\\~2009/12/31\n"
    parse_activity_period(unit, wiki)
    unit.reload
    assert_equal [{ 'from' => '2003/07/01', 'to' => '2009/12/31', 'label' => nil }], unit.activity_period
  end

  test '活動時期に括弧付きラベルがある場合はラベルとして取り込まれる' do
    unit = units(:one)
    wiki = "*活動時期（ロックバンド） … 2012/08/20~2013/12/12\n"
    parse_activity_period(unit, wiki)
    unit.reload
    assert_equal [{ 'from' => '2012/08/20', 'to' => '2013/12/12', 'label' => 'ロックバンド' }], unit.activity_period
  end
end
