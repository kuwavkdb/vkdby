# frozen_string_literal: true

# TSVの1セル分の値。タブ・改行はセル区切り・行区切りと衝突するため空白に置き換える
def tsv_cell(value)
  value.to_s.gsub(/[\t\r\n]+/, ' ')
end

namespace :trends do
  desc '既存Trendに会場（Venue）を後付けする（issue #1690）。既定はdry-run、APPLY=1で実行'
  task backfill_venues: :environment do
    apply = ENV['APPLY'] == '1'
    output = ENV['OUTPUT'].presence || Rails.root.join("tmp/trend_venue_backfill_#{Time.current.strftime('%Y%m%d_%H%M%S')}.tsv")
    puts apply ? '== APPLY: venue_idを設定します ==' : '== DRY RUN: 設定予定の内容を表示します（実行するには APPLY=1） =='

    matcher = TrendVenueMatcher.new
    venue_names = Venue.kept.pluck(:id, :name).to_h
    counts = Hash.new(0)
    unmatched_names = Hash.new(0)
    ambiguous_names = Hash.new { |hash, key| hash[key] = { count: 0, venue_ids: [] } }
    # 現在の会場名と異なる名前（改名前の名前など）で書かれていたもの。name_logの日付の確認用
    renamed_names = Hash.new(0)

    File.open(output, 'w') do |tsv|
      tsv.puts %w[trend_id date title status source names venue_ids venue_names].join("\t")

      # venue_idが入っているTrendは手動で設定済みとみなし、上書きしない
      Trend.where(venue_id: nil).find_each do |trend|
        result = matcher.match(trend)
        key = result.status == :matched ? :"matched_#{result.source}" : result.status
        counts[key] += 1
        next if result.status == :none

        case result.status
        when :matched
          current_name = venue_names[result.venue_ids.first]
          renamed_names[[result.names.join(' / '), current_name]] += 1 unless result.names.include?(current_name)
        when :unmatched
          result.names.each { |name| unmatched_names[name] += 1 }
        when :ambiguous
          entry = ambiguous_names[result.names.join(' / ')]
          entry[:count] += 1
          entry[:venue_ids] |= result.venue_ids
        end

        row = [trend.id, trend.date, trend.title, result.status, result.source, result.names.join(' / '),
               result.venue_ids.join(' '), result.venue_ids.map { |id| venue_names[id] }.join(' / ')]
        tsv.puts row.map { |value| tsv_cell(value) }.join("\t")

        # タイトル・本文は変更しない。updated_atを変えると「最近の更新」に一斉に浮上するため、update_columnを使う
        trend.update_column(:venue_id, result.venue_ids.first) if apply && result.status == :matched
      end
    end

    matched = counts[:matched_title_trailing] + counts[:matched_title_parenthetical]
    with_names = matched + counts[:ambiguous] + counts[:review] + counts[:unmatched]
    rate = with_names.zero? ? 0 : (matched * 100.0 / with_names).round(1)

    puts "\n対象（venue_id未設定）: #{counts.values.sum}件"
    puts "  #{apply ? '自動紐付け' : '自動紐付け予定'}: #{matched}件" \
         "（タイトル末尾の括弧: #{counts[:matched_title_trailing]}件 / " \
         "タイトル中の括弧: #{counts[:matched_title_parenthetical]}件）"
    puts "  候補が複数（手作業で確認）: #{counts[:ambiguous]}件"
    puts "  括弧外・本文にのみ会場リンクあり（手作業で確認）: #{counts[:review]}件"
    puts "  一致なし（手作業で確認）: #{counts[:unmatched]}件"
    puts "  会場名なし: #{counts[:none]}件"
    puts "  一致率（会場名を取り出せたもののうち）: #{rate}%"

    if ambiguous_names.any?
      puts "\n候補が複数の名前:"
      ambiguous_names.sort_by { |_, entry| -entry[:count] }.each do |names, entry|
        candidates = entry[:venue_ids].map { |id| "##{id} #{venue_names[id]}" }.join(', ')
        puts "  #{entry[:count]}件\t#{names}\t→ #{candidates}"
      end
    end

    if renamed_names.any?
      puts "\n現在の会場名と異なる名前で書かれていたもの（表示名はname_logの日付から決まるため、改名した会場は日付を確認）:"
      renamed_names.sort_by { |(names, _), count| [-count, names] }.each do |(names, current_name), count|
        puts "  #{count}件\t#{names}\t→ #{current_name}"
      end
    end

    if unmatched_names.any?
      puts "\n一致しなかった名前（件数の多い順、上位50件。全件はTSVを参照）:"
      unmatched_names.sort_by { |name, count| [-count, name] }.first(50).each do |name, count|
        puts "  #{count}件\t#{name}"
      end
    end

    puts "\nTSV: #{output}"
  end
end
