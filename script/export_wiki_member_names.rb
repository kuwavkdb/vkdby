# frozen_string_literal: true

# 旧wikiのユニットページから在籍時のメンバー表示名を求め、紐付け済みSnapshotPersonの
# 個人の現在の名前と食い違う行を TSV に書き出す（issue #1972）。
#
# wikipages は本番に無いため、ローカルで実行する（wikipages は読み取りのみ）。
# 書き出した TSV をコミット・デプロイし、本番で次の rake タスクを実行して反映する。
#   bundle exec rails snapshot_people:backfill_person_name          # dry-run
#   bundle exec rails snapshot_people:backfill_person_name APPLY=1  # 反映
#
# SnapshotPerson の ID を本番と合わせるため、ローカルDBは本番のバックアップから復元した状態で実行すること。
#
# 使い方:
#   bundle exec rails runner script/export_wiki_member_names.rb
#   OUTPUT=tmp/names.tsv KIND=all bundle exec rails runner script/export_wiki_member_names.rb
#
#   OUTPUT: 出力先（既定: db/data/issue_1972_snapshot_person_names.tsv）
#   KIND:   renamed（既定。別の名前になっている行のみ） / notation（表記の違いだけの行のみ） / all

# 取り込み処理（WikipageImporterV2）と同じ解析で、セクションごとのメンバーを集める。
# register_snapshot_member を上書きし、DB には何も書き込まない。
class WikiMemberNameExtractor < WikipageImporterV2
  # [{ past:, snapshot_index:, date:, label:, entries: [{ name_str:, old_member_key:, sort_order:, ... }] }]
  def sections
    return [] if self.class.ignored?(@wikipage) || @wiki_content.nil?

    preprocess_content
    build(extract_dated_member_sections, past: false) + build(extract_dated_related_sections, past: true)
  end

  private

  def build(section_list, past:)
    section_list.each_with_index.map do |section, index|
      entries = []
      parse_snapshot_members(entries, section[:content])
      { past:, snapshot_index: index, date: section[:date], label: section[:label], entries: }
    end
  end

  def register_snapshot_member(entries, options = {})
    entries << options
  end
end

# 空白・読み仮名の括弧・記号・全角半角・大文字小文字の違いを無視して比べるための正規化
def normalize_name(name)
  name.to_s.unicode_normalize(:nfkc).downcase
      .gsub(/[（(][\p{Hiragana}\p{Katakana}ー・\s]+[）)]/, '')
      .gsub(/[^\p{L}\p{N}]/, '')
end

def tsv_cell(value)
  value.to_s.gsub(/[\t\r\n]+/, ' ')
end

kind_filter = ENV['KIND'].presence || 'renamed'
abort 'エラー: KIND は renamed / notation / all のいずれかを指定してください' unless %w[renamed notation all].include?(kind_filter)

output = ENV['OUTPUT'].presence || Rails.root.join('db/data/issue_1972_snapshot_person_names.tsv')
FileUtils.mkdir_p(File.dirname(output))

counts = Hash.new(0)
rows = []

Unit.with_discarded.where.not(old_wiki_id: nil).find_each do |unit|
  wikipage = Wikipage.find_by(id: unit.old_wiki_id)
  next unless wikipage

  snapshots = unit.unit_snapshots.to_a
  seen_dates = Set.new
  WikiMemberNameExtractor.new(wikipage).sections.each do |section|
    # 取り込み時（WikipageImporterV2#create_snapshot）、同じ日付のセクションは最初の1つだけスナップショットになり、
    # 2つ目以降は飛ばされる。ここでも2つ目以降は照合しない（同じ行を2回書き出さないため）
    if section[:date]
      next unless seen_dates.add?(section[:date])

      matched_by = 'date'
      snapshot = snapshots.find { |s| s.past == section[:past] && s.snapshot_date == section[:date] }
    else
      # 日付がなければ順番で対応付ける。新サイトでの追加・並べ替えで別の時期と結び付くことがあるため、
      # matched_by=index として TSV で見分けられるようにする
      matched_by = 'index'
      snapshot = snapshots.find { |s| s.past == section[:past] && s.snapshot_index == section[:snapshot_index] }
    end
    next unless snapshot

    targets = SnapshotPerson.with_discarded.includes(:person)
                            .where(unit_snapshot_id: snapshot.id, person_name: [nil, ''])
                            .where.not(person_id: nil)
    targets.each do |snapshot_person|
      candidates = section[:entries].select { |e| e[:old_member_key] == snapshot_person.old_person_key }
      entry = candidates.one? ? candidates.first : candidates.find { |e| e[:sort_order] == snapshot_person.sort_order }
      if entry.nil? || snapshot_person.person.nil?
        counts[:unmatched] += 1
        next
      end

      wiki_name = entry[:name_str].to_s.strip
      current_name = snapshot_person.person.name.to_s
      kind = if wiki_name == current_name || wiki_name.blank?
               'same'
             elsif normalize_name(wiki_name) == normalize_name(current_name)
               'notation'
             else
               'renamed'
             end
      counts[kind.to_sym] += 1
      next if kind == 'same' || (kind_filter != 'all' && kind != kind_filter)

      counts[:"matched_by_#{matched_by}"] += 1
      rows << [snapshot_person.id, snapshot_person.person_id, snapshot_person.old_person_key,
               current_name, wiki_name, kind, matched_by, unit.name, snapshot.label]
    end
  end
end

File.open(output, 'w') do |file|
  headers = SnapshotPersonNameBackfill::HEADERS + SnapshotPersonNameBackfill::REFERENCE_HEADERS
  file.puts headers.join("\t")
  rows.sort_by(&:first).each { |row| file.puts row.map { |value| tsv_cell(value) }.join("\t") }
end

puts "書き出し: #{rows.size}行（KIND=#{kind_filter}） → #{output}"
puts "  別の名前（renamed）: #{counts[:renamed]}"
puts "  表記の違いだけ（notation）: #{counts[:notation]}"
puts "  同じ名前: #{counts[:same]}"
puts "  旧wikiと照合できなかった: #{counts[:unmatched]}"
puts "書き出した行のうち、スナップショットを順番で対応付けた行（matched_by=index）: #{counts[:matched_by_index]}"
puts '  別の時期のスナップショットと結び付いていないか、TSV で目視確認してください' if counts[:matched_by_index].positive?
