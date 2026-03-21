# frozen_string_literal: true

# 年表CSVを解析し、DBと照合してrakeタスク用エントリを出力する
#
# 使い方:
#   bundle exec rails runner script/analyze_major_debut_csv.rb
#
# CSV_DATA に解析対象のCSVを貼り付けて実行する。
# フォーマット: ,年月日,メジャー列,インディーズ列
# 対象マーク: × ★ ● ○ △ ▲ □

CSV_DATA = <<~CSV.freeze
  ,年月日,メジャー,インディーズ
  ,1994/12/**,,☆ [[FANATIC◇CRISIS]]/1st.MiniALBUM
  ,1994/12/10,,☆ [[SIAM SHADE]]/1st.ALBUM
  ,1994/11/22,◇ [[AION]]/メジャーLast ALBUM
  ,1994/11/**,,● [[LAREINE]]
  ,1994/09/21,★ [[Valentine D.C.]]/1st.SINGLE、ALBUM
  ,1994/09/**,★ nuvc:gu/1st.SINGLE,□ vogue → nuvc:gu
  ,1994/08/**,,● [[Romance for~]]
  ,1994/07/24,,☆ [[MALICE MIZER]]
  ,1994/07/13,× [[BODY]]
  ,1994/07/01,★ [[L'Arc~en~Ciel]]/1st.VIDEO
  ,1994/05/**,× ZI:KILL
  ,1994/05/**,★ [[GLAY]]
  ,1994/04/**,★ [[GUNIW TOOLS]]
  ,1994/04/01,★ [[BODY]]
  ,1994/02/09,★ [[黒夢]]
  ,1994/01/**,,● [[HYPERM∀NIA]]
  ,1994/**/**,,● [[ILLUMINA]]
  ,1994/**/**,★ [[幻覚アレルギー]]
  ,1994/**/**,,● FIR～REFORLE
  ,1993/12/**,,● [[ROUAGE]]
  ,1993/12/**,,● [[Plastic Tree]]
  ,1993/09/25,× [[Strawberry Fields]]
  ,1993/09/**,,● [[cali+gari|cali≠gari]]
  ,1993/08/**,,● [[CASCADE]]
  ,1993/07/**,,● [[Laputa]]
  ,1993/06/18,★ [[Gilles de Rais]]
  ,1993/05/**,,● [[SIAM SHADE]]
  ,1993/04/**,★ Gargoyle/1st.VIDEO
  ,1993/03/**,,● vogue
  ,1993/**/**,,● [[SHAZNA]]
  ,1993/**/**,× [[AURA]]
  ,1992/11/25,,☆ [[L'Arc~en~Ciel]]/1st.SINGLE
  ,1992/11/**,,● [[FANATIC◇CRISIS]]
  ,1992/10/**,□ X→[[X JAPAN]]
  ,1992/09/**,,● [[KneuKlid Romance]]#{' '}
  ,1992/08/**,,● [[MALICE MIZER]]
  ,1992/07/**,,☆ [[黒夢]]/1st.ALUBM
  ,1992/07/**,,● [[BODY]]
  ,1992/05/21,★ [[LUNA SEA]]/1st.ALUBM
  ,1992/02/14,,● penicillin
  ,1992/02/05,★ [[Die In Cries|DIE IN CRIES]]
  ,1992/**/**,,● [[MASCHERA]]
  ,1992/**/**,,☆ [[幻覚アレルギー]]
  ,1991/10/02,★ [[AION]]
  ,1991/07/05,,● [[DIE IN CRIES]]
  ,1991/06/**,,● [[黒夢]]
  ,1991/06/**,,● [[Kill=slayd]]
  ,1991/05/**,,● [[BAISER]]
  ,1991/04/21,,☆ [[LUNASEA]]/1st.ALBUM
  ,1991/03/30,★ [[Strawberry Fields]]/1st.ALBUM
  ,1991/03/06,★ ZI:KILL
  ,1991/02/**,,● [[L'Arc~en~Ciel]]
  ,1991/**/**,× [[かまいたち]]
  ,1991/**/**,,● [[Sleep My Dear]]
  ,1990/11/19,× [[D'ERLANGER]]
  ,1990/08/15,, [[Midgardsormr]]/1st.ALBUM
  ,1990/02/21,★ [[BY-SEXUAL|BY-SEX]]
  ,1990/01/24,★ [[D'ERLANGER]]/1st.SINGLE
  ,1990/01/**,,● Eins:Vier
  ,1990/01/**,,● [[GUNIW TOOLS]]
  ,1990/**/**,× [[DEAD END]]
  ,1990/**/**,★ [[かまいたち]]
  ,2004/12/25,× [[baroque]]
  ,2004/12/23,× [[JURASSIC]]
  ,2004/10/20,★ [[雅-miyavi-]]/1st.SINGLE オリコン初登場10位
  ,2004/09/22,★ [[Vogus Image]]
  ,2004/09/05,× [[Laputa]]
  ,2004/08/25,★ [[ATTACK HAUS]]
  ,2004/08/**,,● [[lynch.]]
  ,2004/07/22,★ [[Shulla]]/1st.SINGLE
  ,2004/06/23,★ [[ドレミ團]]/1st.MiniAlbum
  ,2004/05/08,,● [[彩冷える|彩冷える-ayabie-]]
  ,2004/01/**,,● [[Wizard]]
  ,2004/01/07,× [[DASEIN]]
  ,2004/01/01,★ [[Kagrra，]]/1st.SINGLE,□ Kagrra → [[Kagrra，]]
  ,2003/12/**,△ [[SOFT BALLET]]
  ,2003/10/29,★ [[犬神サーカス団]]/1st.SINGLE
  ,2003/08/21,★ [[ナイトメア]]/1st.SINGLE オリコン初登場24位
  ,2003/07/24,★ [[baroque]]/1st.SINGLE オリコン初登場14位,
  ,2003/07/18,× [[e.mu]]
  ,2003/07/**,★ [[紫苑]]/1st.VIDEO
  ,2003/06/22,△ [[cali≠gari]]
  ,2003/06/15,,● [[exist†trace]]
  ,2003/05/21,★ [[ムック]]/1st.SINGLE
  ,2003/05/**,,● [[アンティック-珈琲店-]]
  ,2003/05/**,,● [[シド]]
  ,2003/03/**,,● [[D|D（ディー）]]
  ,2003/02/28,△ [[Dope HEADz]]
  ,2003/01/10,× Λucifer
  ,2003/**/**,,□ +D'espairs Ray+ → [[D'espairsRay]]
  ,2002/12/31,,× [[CLOUD]]
  ,2002/11/**,,○ [[LAREINE]]
  ,2002/10/23,★ [[rice]]
  ,2002/10/02,★ [[Psycho le Cemu]]
  ,2002/08/30,× [[CASCADE]]
  ,2002/08/17,○ [[SOFT BALLET]]
  ,2002/07/03,★ [[JURASSIC]]/1st.SINGLE
  ,2002/05/30,,× [[ILLUMINA]]
  ,2002/05/22,★ [[CUNE]]/1st.SINGLE
  ,2002/04/04,★ [[cali≠gari]]/1st.SINGLE オリコン初登場25位
  ,2002/03/31,× [[Blue]]
  ,2002/03/10,× [[SIAM SHADE]]
  ,2002/03/16,× [[ZIGZO]]
  ,2002/02/**,,● [[ヴィドール]]
  ,2002/01/01,,● [[ドレミ團]]
  ,2002/**/**,,● [[ガゼット]]
  ,2002/**/**,,● [[ATTACK HAUS]]
  ,2001/12/31,× [[MALICE MIZER]]
  ,2001/12/16,★ [[陰陽座]]/1st.SINGLE
  ,2001/12/16,× [[∧ucifer]]
  ,2001/12/**,,● [[ホタル]]
  ,2001/11/10,,◇ [[CLOUD]]/インデーズ復帰SINGLE
  ,2001/10/21,,☆ [[ナイトメア]]/1st.SINGLE
  ,2001/10/**,,● [[メリー]]
  ,2001/08/22,★ [[FAIRY FORE]]
  ,2001/08/**,,● [[Kra]]
  ,2001/06/20,,× [[kannivalism]]
  ,2001/06/21,,☆ [[Shulla]]/1st.SINGLE
  ,2001/06/**,,● バロック
  ,2001/05/15,,☆ [[CUNE]]/1st.SINGLE
  ,2001/05/**,× [[BAISER]]
  ,2001/05/03,× [[Lastier]]
  ,2001/03/23,★ [[CLOUD]]/1st.LAST ALBUM
  ,2001/03/23,★ [[S.Q.F]]/1st.SINGLE
  ,2001/03/**,× [[Raphael]]
  ,2001/02/21,★ [[Dope HEADz]]/1st.SINGLE
  ,2001/01/14,× [[CLOSE]]
  ,2001/01/**,,● [[Shulla]]
  ,2001/**/**,× [[LAREINE]]
  ,2000/12/**,,● [[しゃるろっと]]
  ,2000/12/27,× [[LUNASEA]]
  ,2000/12/15,× [[HybriD]]
  ,2000/12/12,★ [[wyse]]/1st.ALBUM
  ,2000/12/06,★ [[Suzzy&Caroline]]/1st.ALBUM
  ,2000/12/01,,☆ Kagrra/1st.ALBUM
  ,2000/11/28,,× [[ALL I NEED]]
  ,2000/11/26,△ [[GUNIW TOOLS]]
  ,2000/10/**,△ [[SHAZNA]]
  ,2000/10/25,,☆ [[S.Q.F]]/1st.MiniALBUM
  ,2000/10/15,× [[BLue-B]]
  ,2000/09/01,,☆ [[wyse]]/1st.MiniALBUM#{' '}
  ,2000/08/23,★ [[CLOUD]]/1st.SINGLE
  ,2000/07/25,× [[賛美歌]]
  ,2000/06/09,,☆ [[ムック]]/1st.SINGLE
  ,2000/06/**,,□ FIR～REFORLE → [[FAIRY FORE]]
  ,2000/06/**,,□ CROW → [[Kagrra]]
  ,2000/05/22,× [[KneuKlid Romance]]
  ,2000/05/**,,● [[Suzzy&Caroline]]
  ,2000/05/**,△ [[L'luvia]]
  ,2000/04/19,★ [[e.mu]]/1st.SINGLE オリコン初登場14位
  ,2000/03/29,× [[MASCHERA]]
  ,2000/03/**,,☆ [[Psycho le Cemu]]
  ,2000/01/16,× [[MIRAGE]]
  ,2000/01/**,,● [[ナイトメア]]
  ,2000/01/**,,● [[宇宙戦隊NOIZ]]
  ,2000/**/**,× [[D-SHADE]]
  ,2000/**/**,,● [[S.Q.F]]
CSV

MARK_MAP = {
  '×' => { phenomenon: :finish,      title: '解散' },
  '★' => { phenomenon: :major_debut, title: 'メジャーデビュー' },
  '●' => { phenomenon: :formation,   title: '結成' },
  '○' => { phenomenon: :restart,     title: '再結成' },
  '△' => { phenomenon: :suspend,     title: '活動休止' },
  '▲' => { phenomenon: :restart,     title: '活動再開' },
  '□' => { phenomenon: :rename,      title: '改名' }
}.freeze

# セルテキストを解析して { old_key:, phenomenon:, title: } を返す。
# 対象マークがなければ nil。
def parse_cell(text)
  return nil if text.blank?

  text = text.strip
  mark = MARK_MAP.keys.find { |m| text.start_with?(m) }
  return nil unless mark

  content = text.sub(/\A./, '').strip # 先頭マーク1文字を除去

  # □（改名）は "旧名 → 新名" のうち新名を対象にする
  content = content.split('→').last.strip if mark == '□' && content.include?('→')

  # /以降のサフィックスを除去（1st.SINGLE 等）
  content = content.sub(%r{/.*$}, '').strip

  # wiki記法パース: [[Link|Display]] → Link, [[Link]] → Link
  old_key = if content =~ /\[\[([^|\]]+)\|[^\]]+\]\]/
              Regexp.last_match(1).strip
            elsif content =~ /\[\[([^\]]+)\]\]/
              Regexp.last_match(1).strip
            else
              content
            end

  { old_key:, **MARK_MAP[mark] }
end

def parse_date(date_str)
  month_unknown = date_str.match?(%r{\*\*/\*\*$})
  day_unknown   = date_str.end_with?('**')
  clean         = date_str.gsub('**', '01')
  [Date.parse(clean), day_unknown, month_unknown]
rescue Date::Error
  nil
end

def find_unit(old_key)
  Unit.find_by(old_key:) || Unit.where('name ILIKE ?', old_key).first
end

def already_exists?(unit, phenomenon, date)
  q = Trend.where(unit_phenomenon: phenomenon, active: true)
           .where('units @> ?', [{ unit_id: unit.id }].to_json)
  # major_debut はユニット単位で重複チェック（1バンド1回のみ）
  # その他は同日・同現象で重複チェック
  phenomenon == :major_debut ? q.exists? : q.where(date:).exists?
end

entries = []
CSV_DATA.each_line do |line|
  line = line.strip
  next if line.start_with?('#') || line.start_with?('//')

  parts    = line.split(',')
  date_str = parts[1]&.strip
  next if date_str.blank?

  parsed = parse_date(date_str)
  next unless parsed

  date, day_unknown, month_unknown = parsed

  # メジャー列（col2）とインディーズ列（col3）の両方を処理
  [parts[2], parts[3]].each do |col|
    cell = parse_cell(col)
    next unless cell

    entries << { date_str:, date:, day_unknown:, month_unknown:, **cell }
  end
end

puts "=== 解析結果: #{entries.size}件 ===\n\n"

found     = []
not_found = []
already   = []

entries.each do |e|
  unit = find_unit(e[:old_key])

  unless unit
    not_found << e
    puts "[NOT FOUND] #{e[:date_str]} #{e[:phenomenon]} #{e[:old_key]}"
    next
  end

  if already_exists?(unit, e[:phenomenon], e[:date])
    already << { **e, unit: }
    puts "[ALREADY]   #{e[:date_str]} #{e[:phenomenon]} #{e[:old_key]} → #{unit.name} [#{unit.key}]"
  else
    found << { **e, unit: }
    puts "[ADD]       #{e[:date_str]} #{e[:phenomenon]} #{e[:old_key]} → #{unit.name} [#{unit.key}]"
  end
end

puts "\n=== 集計 ==="
puts "追加対象: #{found.size}件"
puts "登録済み: #{already.size}件"
puts "未照合:   #{not_found.size}件"

puts "\n=== rake タスク用エントリ（追加対象のみ） ==="
found.each do |e|
  puts "{ date: '#{e[:date_str]}', unit_key: '#{e[:unit].key}', phenomenon: :#{e[:phenomenon]}, title: '#{e[:title]}' },"
end
