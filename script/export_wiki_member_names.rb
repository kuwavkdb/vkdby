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
#   MAX_SNAPSHOTS=1 bundle exec rails runner script/export_wiki_member_names.rb
#   MIN_SNAPSHOTS=2 OUTPUT=tmp/multi.tsv bundle exec rails runner script/export_wiki_member_names.rb
#
#   OUTPUT:        出力先（既定: db/data/issue_1972_snapshot_person_names.tsv）
#   KIND:          renamed（既定。別の名前になっている行のみ） / notation（表記の違いだけの行のみ） / all
#   MAX_SNAPSHOTS: スナップショットがこの数以下のユニットだけを対象にする（既定: 制限なし）。
#                  1 にすると、対応付け先のスナップショットが1つに決まるユニットだけになる
#   MIN_SNAPSHOTS: スナップショットがこの数以上のユニットだけを対象にする（既定: 制限なし）
#
# 日付のないスナップショットは取り込み時の順番（snapshot_index）で対応付けるため、次のユニットは対象にしない。
# - 取り込み後にスナップショットが追加されたユニット（作成日時が取り込み時から離れている）。
#   追加したスナップショットは snapshot_index が既定の 0 になり、取り込み時の 0 番と区別できない。
#   また、追加にあわせて並べ替えている（snapshot_index が 1 から振り直される）ことがある
# - 同じ種類（メンバー／関係者）の中で snapshot_index がぶつかっているユニット
# 並べ替えだけを行ったユニットはない前提とする（並べ替えると 0 番が無くなるので、見つかれば対象にしない）。
#
# 旧wikiの表示名に HTML の文字参照（&#248; など）が残っている行は、そのまま入れると画面に符号が出るため書き出さない。

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

# HTML の文字参照（&#248; / &#x00F8; / &amp; など）
CHARACTER_REFERENCE = /&(?:#\d+|#x\h+|[a-z]+);/i

# 空白・読み仮名の括弧・記号・全角半角・大文字小文字の違いを無視して比べるための正規化
def normalize_name(name)
  name.to_s.unicode_normalize(:nfkc).downcase
      .gsub(/[（(][\p{Hiragana}\p{Katakana}ー・\s]+[）)]/, '')
      .gsub(/[^\p{L}\p{N}]/, '')
end

# 取り込み時に作られたスナップショットは作成日時がほぼそろう。これより離れていれば、後から追加されたとみなす
SNAPSHOT_ADDED_THRESHOLD = 1.hour

# 取り込み時の順番のまま使えないユニットなら、その理由を返す
def unsafe_snapshots_reason(snapshots)
  return nil if snapshots.size <= 1

  created = snapshots.map(&:created_at)
  return :snapshot_added if created.max - created.min > SNAPSHOT_ADDED_THRESHOLD

  groups = snapshots.group_by(&:past).values
  return :index_collision if groups.any? { |group| group.map(&:snapshot_index).uniq.size < group.size }
  # 取り込み処理はメンバー・関係者それぞれ 0 から番号を振る。0 番が無ければ並べ替えられている
  return :reordered if groups.any? { |group| group.map(&:snapshot_index).min != 0 }

  nil
end

def tsv_cell(value)
  value.to_s.gsub(/[\t\r\n]+/, ' ')
end

kind_filter = ENV['KIND'].presence || 'renamed'
abort 'エラー: KIND は renamed / notation / all のいずれかを指定してください' unless %w[renamed notation all].include?(kind_filter)

max_snapshots = ENV['MAX_SNAPSHOTS'].presence
abort 'エラー: MAX_SNAPSHOTS は1以上の整数を指定してください' if max_snapshots && !max_snapshots.match?(/\A[1-9]\d*\z/)
max_snapshots = max_snapshots&.to_i

min_snapshots = ENV['MIN_SNAPSHOTS'].presence
abort 'エラー: MIN_SNAPSHOTS は1以上の整数を指定してください' if min_snapshots && !min_snapshots.match?(/\A[1-9]\d*\z/)
min_snapshots = min_snapshots&.to_i

output = ENV['OUTPUT'].presence || Rails.root.join('db/data/issue_1972_snapshot_person_names.tsv')
FileUtils.mkdir_p(File.dirname(output))

counts = Hash.new(0)
rows = []

Unit.with_discarded.where.not(old_wiki_id: nil).find_each do |unit|
  wikipage = Wikipage.find_by(id: unit.old_wiki_id)
  next unless wikipage

  snapshots = unit.unit_snapshots.to_a
  if (max_snapshots && snapshots.size > max_snapshots) || (min_snapshots && snapshots.size < min_snapshots)
    counts[:skipped_units] += 1
    next
  end
  if (reason = unsafe_snapshots_reason(snapshots))
    counts[:"unsafe_#{reason}"] += 1
    next
  end

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

      if wiki_name.match?(CHARACTER_REFERENCE)
        counts[:character_reference] += 1
        next
      end

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

conditions = ["KIND=#{kind_filter}"]
conditions << "MAX_SNAPSHOTS=#{max_snapshots}" if max_snapshots
conditions << "MIN_SNAPSHOTS=#{min_snapshots}" if min_snapshots
puts "書き出し: #{rows.size}行（#{conditions.join(', ')}） → #{output}"
puts "  スナップショットの数の条件で対象外にしたユニット: #{counts[:skipped_units]}" if max_snapshots || min_snapshots
puts "  取り込み後にスナップショットが追加されたため対象外にしたユニット: #{counts[:unsafe_snapshot_added]}"
puts "  snapshot_index がぶつかっているため対象外にしたユニット: #{counts[:unsafe_index_collision]}"
puts "  並べ替えられているため対象外にしたユニット: #{counts[:unsafe_reordered]}"
puts "  別の名前（renamed）: #{counts[:renamed]}"
puts "  表記の違いだけ（notation）: #{counts[:notation]}"
puts "  同じ名前: #{counts[:same]}"
puts "  旧wikiと照合できなかった: #{counts[:unmatched]}"
puts "  文字参照（&#…; など）を含むため書き出さなかった: #{counts[:character_reference]}"
puts "書き出した行のうち、スナップショットを順番で対応付けた行（matched_by=index）: #{counts[:matched_by_index]}"
# スナップショットが1つしかないユニットだけなら、対応付け先は1つに決まるので確認は要らない
needs_visual_check = counts[:matched_by_index].positive? && max_snapshots != 1
puts '  別の時期のスナップショットと結び付いていないか、TSV で目視確認してください' if needs_visual_check
