# frozen_string_literal: true

namespace :seed do # rubocop:disable Metrics/BlockLength
  desc '年表CSVから抽出した Trend レコードを登録する（未登録のもののみ）'
  task major_debut_trends: :environment do # rubocop:disable Metrics/BlockLength
    # date:       "YYYY/MM/DD" または "YYYY/MM/**"（日不明）または "YYYY/**/**"（月日不明）
    # unit_key:   Unit#key
    # phenomenon: unit_phenomenon の enum キー（省略時は :major_debut）
    # title:      Trend タイトル（省略時は "メジャーデビュー"）
    entries = [
      # ---- 1980年代 ----
      { date: '1987/09/**', unit_key: 'dead-end',    title: 'メジャーデビュー' },
      { date: '1987/11/21', unit_key: 'buck-tick',   title: 'メジャーデビュー' },
      { date: '1989/04/21', unit_key: 'x-japan',     title: 'メジャーデビュー' },
      { date: '1989/06/25', unit_key: 'justy-nasty', title: 'メジャーデビュー' },

      # ---- 1990年代（年表ページ「★」付き） ----
      # 未照合: LUCA（DB未登録）、FAME（DB未登録）
      { date: '1990/01/24', unit_key: 'd-erlanger',            title: 'メジャーデビュー' },
      { date: '1990/02/21', unit_key: 'by-sexual',             title: 'メジャーデビュー' },
      { date: '1990/**/**', unit_key: 'a4aba4dea4a4a4bfa4c1',  title: 'メジャーデビュー' },
      { date: '1991/03/30', unit_key: 'strawberry-fields',     title: 'メジャーデビュー' },
      { date: '1991/10/02', unit_key: 'aion',                  title: 'メジャーデビュー' },
      { date: '1992/02/05', unit_key: 'die-in-cries',          title: 'メジャーデビュー' },
      { date: '1992/05/21', unit_key: 'luna-sea',              title: 'メジャーデビュー' },
      { date: '1993/04/**', unit_key: 'gargoyle',              title: 'メジャーデビュー' },
      { date: '1993/06/18', unit_key: 'gilles-de-rais',        title: 'メジャーデビュー' },
      { date: '1994/**/**', unit_key: 'genkakuarerugi-',       title: 'メジャーデビュー' },
      { date: '1994/02/09', unit_key: 'kuroyume',              title: 'メジャーデビュー' },
      { date: '1994/04/01', unit_key: 'body',                  title: 'メジャーデビュー' },
      { date: '1994/04/**', unit_key: 'guniw-tools',           title: 'メジャーデビュー' },
      { date: '1994/05/**', unit_key: 'glay',                  title: 'メジャーデビュー' },
      { date: '1994/07/01', unit_key: 'l-arc-en-ciel',         title: 'メジャーデビュー' },
      { date: '1994/09/**', unit_key: 'vogue',                 title: 'メジャーデビュー' },
      { date: '1994/09/21', unit_key: 'valentine-d-c-',        title: 'メジャーデビュー' },
      { date: '1995/07/21', unit_key: 'ainsufia',              title: 'メジャーデビュー' },
      { date: '1995/07/25', unit_key: 'sleep-my-dear',         title: 'メジャーデビュー' },
      { date: '1995/10/**', unit_key: 'sophia',                title: 'メジャーデビュー' },
      { date: '1996/**/**', unit_key: 'kill-slayd',            title: 'メジャーデビュー' },
      { date: '1996/03/15', unit_key: 'penicillin',            title: 'メジャーデビュー' },
      { date: '1996/04/22', unit_key: 'rouage',                title: 'メジャーデビュー' },
      { date: '1996/09/30', unit_key: 'laputa',                title: 'メジャーデビュー' },
      { date: '1997/02/**', unit_key: 'merry-go-round',        title: 'メジャーデビュー' },
      { date: '1997/05/08', unit_key: 'la-cryma-christi',      title: 'メジャーデビュー' },
      { date: '1997/06/01', unit_key: 'zadeddopoppusuta-zu',   title: 'メジャーデビュー' },
      { date: '1997/06/25', unit_key: 'plastic-tree',          title: 'メジャーデビュー' },
      { date: '1997/07/19', unit_key: 'malice-mizer',          title: 'メジャーデビュー' },
      { date: '1997/08/06', unit_key: 'fanathikku-kuraishisu', title: 'メジャーデビュー' },
      { date: '1997/08/27', unit_key: 'shazna',                title: 'メジャーデビュー' },
      { date: '1997/11/**', unit_key: 'romance-for-',          title: 'メジャーデビュー' },
      { date: '1997/11/21', unit_key: 'sambika',               title: 'メジャーデビュー' },
      { date: '1997/12/03', unit_key: 'maschera',              title: 'メジャーデビュー' },
      { date: '1998/03/01', unit_key: 'kneuklid-romance',      title: 'メジャーデビュー' },
      { date: '1998/04/22', unit_key: 'd-shade',               title: 'メジャーデビュー' },
      { date: '1998/04/22', unit_key: 'sex-machineguns',       title: 'メジャーデビュー' },
      { date: '1998/05/20', unit_key: 'all-i-need',            title: 'メジャーデビュー' },
      { date: '1998/06/03', unit_key: 'ramar',                 title: 'メジャーデビュー' },
      { date: '1998/06/10', unit_key: 'blue',                  title: 'メジャーデビュー' },
      { date: '1998/07/01', unit_key: 'lastier',               title: 'メジャーデビュー' },
      { date: '1998/09/10', unit_key: 'pierrot',               title: 'メジャーデビュー' },
      { date: '1998/11/26', unit_key: 'l-luvia',               title: 'メジャーデビュー' },
      { date: '1999/01/20', unit_key: 'dir-en-grey',           title: 'メジャーデビュー' },
      { date: '1999/02/24', unit_key: 'close',                 title: 'メジャーデビュー' },
      { date: '1999/03/17', unit_key: 'transtic-nerve',        title: 'メジャーデビュー' },
      { date: '1999/05/19', unit_key: 'janne-da-arc',          title: 'メジャーデビュー' },
      { date: '1999/05/21', unit_key: 'baiser',                title: 'メジャーデビュー' },
      { date: '1999/05/21', unit_key: 'endless',               title: 'メジャーデビュー' },
      { date: '1999/05/26', unit_key: 'lareine',               title: 'メジャーデビュー' },
      { date: '1999/07/23', unit_key: 'raphael',               title: 'メジャーデビュー' },
      { date: '1999/08/04', unit_key: 'melody',                title: 'メジャーデビュー' },
      { date: '1999/08/25', unit_key: 'r-ose',                 title: 'メジャーデビュー' },
      { date: '1999/09/**', unit_key: 'ryushiferu',            title: 'メジャーデビュー' },
      { date: '1999/11/03', unit_key: 'blue-b',                title: 'メジャーデビュー' },
      { date: '1999/12/10', unit_key: 'neil',                  title: 'メジャーデビュー' },

      # ---- 2000年代（年表ページ「★」付き） ----
      # 未照合: 雅-miyavi-（DB未登録）
      { date: '2000/04/19', unit_key: 'e-mu',               title: 'メジャーデビュー' },
      { date: '2000/08/23', unit_key: 'cloud',              title: 'メジャーデビュー' },
      { date: '2000/12/06', unit_key: 'suzzy-caroline',     title: 'メジャーデビュー' },
      { date: '2001/02/21', unit_key: 'dope-headz',         title: 'メジャーデビュー' },
      { date: '2001/03/23', unit_key: 's-q-f',              title: 'メジャーデビュー' },
      { date: '2001/08/22', unit_key: 'fairy-fore',         title: 'メジャーデビュー' },
      { date: '2001/12/16', unit_key: 'ommyouza',           title: 'メジャーデビュー' },
      { date: '2002/07/03', unit_key: 'jurassic',           title: 'メジャーデビュー' },
      { date: '2002/10/23', unit_key: 'rice',               title: 'メジャーデビュー' },
      { date: '2002/10/02', unit_key: 'psycho-le-cemu',     title: 'メジャーデビュー' },
      { date: '2003/05/21', unit_key: 'mucc',               title: 'メジャーデビュー' },
      { date: '2003/07/**', unit_key: 'shion',              title: 'メジャーデビュー' },
      { date: '2003/07/24', unit_key: 'baroque',            title: 'メジャーデビュー' },
      { date: '2003/08/21', unit_key: 'nightmare',          title: 'メジャーデビュー' },
      { date: '2003/10/29', unit_key: 'inugamisa-kasudan',  title: 'メジャーデビュー' },
      { date: '2004/01/01', unit_key: 'kagura',             title: 'メジャーデビュー' },
      { date: '2004/07/22', unit_key: 'shulla',             title: 'メジャーデビュー' },
      { date: '2004/08/25', unit_key: 'attack-haus',        title: 'メジャーデビュー' },
      { date: '2004/09/22', unit_key: 'vogus-image',        title: 'メジャーデビュー' },

      # ---- 1990〜2004年代（全マーク、年表ページより） ----
      # 未照合: exist†trace, HYPERM∀NIA, SOFT BALLET, AURA, FIR～REFORLE（いずれもDB未登録）
      { date: '1990/01/**', unit_key: 'ainsufia',                    phenomenon: :formation, title: '結成' },
      { date: '1990/01/**', unit_key: 'guniw-tools',                 phenomenon: :formation, title: '結成' },
      { date: '1990/11/19', unit_key: 'd-erlanger',                  phenomenon: :finish,    title: '解散' },
      { date: '1990/**/**', unit_key: 'dead-end',                    phenomenon: :finish,    title: '解散' },
      { date: '1991/05/**', unit_key: 'baiser',                      phenomenon: :formation, title: '結成' },
      { date: '1991/06/**', unit_key: 'kill-slayd',                  phenomenon: :formation, title: '結成' },
      { date: '1991/06/**', unit_key: 'kuroyume',                    phenomenon: :formation, title: '結成' },
      { date: '1991/07/05', unit_key: 'die-in-cries', phenomenon: :formation, title: '結成' },
      { date: '1991/**/**', unit_key: 'a4aba4dea4a4a4bfa4c1',        phenomenon: :finish,    title: '解散' },
      { date: '1991/**/**', unit_key: 'sleep-my-dear',               phenomenon: :formation, title: '結成' },
      { date: '1991/02/**', unit_key: 'l-arc-en-ciel', phenomenon: :formation, title: '結成' },
      { date: '1992/02/14', unit_key: 'penicillin',                  phenomenon: :formation, title: '結成' },
      { date: '1992/07/**', unit_key: 'body',                        phenomenon: :formation, title: '結成' },
      { date: '1992/08/**', unit_key: 'malice-mizer',                phenomenon: :formation, title: '結成' },
      { date: '1992/**/**', unit_key: 'maschera',                    phenomenon: :formation, title: '結成' },
      { date: '1992/10/**', unit_key: 'x-japan',                     phenomenon: :rename,    title: '改名' },
      { date: '1992/11/**', unit_key: 'fanathikku-kuraishisu', phenomenon: :formation, title: '結成' },
      { date: '1993/03/**', unit_key: 'vogue',                       phenomenon: :formation, title: '結成' },
      { date: '1993/05/**', unit_key: 'siam-shade',                  phenomenon: :formation, title: '結成' },
      { date: '1993/07/**', unit_key: 'laputa',                      phenomenon: :formation, title: '結成' },
      { date: '1993/09/25', unit_key: 'strawberry-fields',           phenomenon: :finish,    title: '解散' },
      { date: '1993/09/**', unit_key: 'karigari',                    phenomenon: :formation, title: '結成' },
      { date: '1993/12/**', unit_key: 'plastic-tree',                phenomenon: :formation, title: '結成' },
      { date: '1993/12/**', unit_key: 'rouage',                      phenomenon: :formation, title: '結成' },
      { date: '1993/**/**', unit_key: 'shazna',                      phenomenon: :formation, title: '結成' },
      { date: '1994/05/**', unit_key: 'jikiru',                      phenomenon: :finish,    title: '解散' },
      { date: '1994/07/13', unit_key: 'body',                        phenomenon: :finish,    title: '解散' },
      { date: '1994/08/**', unit_key: 'romance-for-',                phenomenon: :formation, title: '結成' },
      { date: '1994/09/**', unit_key: 'vogue',                       phenomenon: :rename,    title: '改名' },
      { date: '1994/11/**', unit_key: 'lareine',                     phenomenon: :formation, title: '結成' },
      { date: '2000/01/**', unit_key: 'nightmare',                   phenomenon: :formation, title: '結成' },
      { date: '2000/01/**', unit_key: 'uchuusentainoizu',            phenomenon: :formation, title: '結成' },
      { date: '2000/05/**', unit_key: 'l-luvia',                     phenomenon: :suspend,   title: '活動休止' },
      { date: '2000/05/**', unit_key: 'suzzy-caroline',              phenomenon: :formation, title: '結成' },
      { date: '2000/06/**', unit_key: 'fairy-fore',                  phenomenon: :rename,    title: '改名' },
      { date: '2000/06/**', unit_key: 'kagura',                      phenomenon: :rename,    title: '改名' },
      { date: '2000/07/25', unit_key: 'sambika',                     phenomenon: :finish,    title: '解散' },
      { date: '2000/10/15', unit_key: 'blue-b',                      phenomenon: :finish,    title: '解散' },
      { date: '2000/11/28', unit_key: 'all-i-need',                  phenomenon: :finish,    title: '解散' },
      { date: '2000/12/**', unit_key: 'sharurotto',                  phenomenon: :formation, title: '結成' },
      { date: '2000/12/15', unit_key: 'hybrid',                      phenomenon: :finish,    title: '解散' },
      { date: '2000/12/27', unit_key: 'luna-sea',                    phenomenon: :finish,    title: '解散' },
      { date: '2000/**/**', unit_key: 'd-shade',                     phenomenon: :finish,    title: '解散' },
      { date: '2000/**/**', unit_key: 's-q-f',                       phenomenon: :formation, title: '結成' },
      { date: '2000/01/16', unit_key: 'mirage',                      phenomenon: :finish,    title: '解散' },
      { date: '2001/01/**', unit_key: 'shulla',                      phenomenon: :formation, title: '結成' },
      { date: '2001/01/14', unit_key: 'close',                       phenomenon: :finish,    title: '解散' },
      { date: '2001/03/**', unit_key: 'raphael',                     phenomenon: :finish,    title: '解散' },
      { date: '2001/05/**', unit_key: 'baiser',                      phenomenon: :finish,    title: '解散' },
      { date: '2001/06/**', unit_key: 'baroque',                     phenomenon: :formation, title: '結成' },
      { date: '2001/06/20', unit_key: 'kannivalism',                 phenomenon: :finish,    title: '解散' },
      { date: '2001/08/**', unit_key: 'kra',                         phenomenon: :formation, title: '結成' },
      { date: '2001/10/**', unit_key: 'merry',                       phenomenon: :formation, title: '結成' },
      { date: '2001/12/**', unit_key: 'a5dba5bfa5eb',                phenomenon: :formation, title: '結成' },
      { date: '2001/12/16', unit_key: 'ryushiferu',                  phenomenon: :finish,    title: '解散' },
      { date: '2001/12/31', unit_key: 'malice-mizer',                phenomenon: :finish,    title: '解散' },
      { date: '2001/**/**', unit_key: 'lareine',                     phenomenon: :finish,    title: '解散' },
      { date: '2002/02/**', unit_key: 'a5f4a5a3a5c9a1bca5eb',        phenomenon: :formation, title: '結成' },
      { date: '2002/03/31', unit_key: 'blue',                        phenomenon: :finish,    title: '解散' },
      { date: '2002/11/**', unit_key: 'lareine',                     phenomenon: :restart,   title: '再結成' },
      { date: '2002/12/31', unit_key: 'cloud',                       phenomenon: :finish,    title: '解散' },
      { date: '2002/**/**', unit_key: 'attack-haus',                 phenomenon: :formation, title: '結成' },
      { date: '2002/**/**', unit_key: 'the-gazette',                 phenomenon: :formation, title: '結成' },
      { date: '2003/01/10', unit_key: 'ryushiferu',                  phenomenon: :finish,    title: '解散' },
      { date: '2003/02/28', unit_key: 'dope-headz',                  phenomenon: :suspend,   title: '活動休止' },
      { date: '2003/03/**', unit_key: 'd',                           phenomenon: :formation, title: '結成' },
      { date: '2003/05/**', unit_key: 'a5b7a5c9',                    phenomenon: :formation, title: '結成' },
      { date: '2003/07/18', unit_key: 'e-mu',                        phenomenon: :finish,    title: '解散' },
      { date: '2003/**/**', unit_key: 'd-espairsray',                phenomenon: :rename,    title: '改名' },
      { date: '2004/01/**', unit_key: 'wizard',                      phenomenon: :formation, title: '結成' },
      { date: '2004/01/01', unit_key: 'kagura',                      phenomenon: :rename,    title: '改名' },
      { date: '2004/01/07', unit_key: 'dasein',                      phenomenon: :finish,    title: '解散' },
      { date: '2004/08/**', unit_key: 'lynch-',                      phenomenon: :formation, title: '結成' },
      { date: '2004/09/05', unit_key: 'laputa',                      phenomenon: :finish,    title: '解散' },
      { date: '2004/12/23', unit_key: 'jurassic',                    phenomenon: :finish,    title: '解散' }
    ]

    added = 0
    skipped = 0
    errors = 0

    entries.each do |entry|
      unit = Unit.find_by(key: entry[:unit_key])
      unless unit
        puts "  [SKIP] unit not found: #{entry[:unit_key]}"
        skipped += 1
        next
      end

      date_str = entry[:date]
      day_unknown   = date_str.end_with?('**')
      month_unknown = date_str.match?(%r{\*/\*\*$})

      clean = date_str.gsub('**', '01')
      begin
        parsed_date = Date.parse(clean)
      rescue Date::Error
        puts "  [ERROR] invalid date: #{date_str} (#{unit.name})"
        errors += 1
        next
      end

      phenomenon = entry[:phenomenon] || :major_debut

      # 重複チェック:
      #   major_debut はユニット単位（1バンド1回のみ）
      #   その他は同日・同現象で判定
      already_q = Trend.where(unit_phenomenon: phenomenon, active: true)
                       .where('units @> ?', [{ unit_id: unit.id }].to_json)
      already = phenomenon == :major_debut ? already_q.exists? : already_q.where(date: parsed_date).exists?

      if already
        puts "  [SKIP] already exists: #{unit.name} #{date_str} (#{phenomenon})"
        skipped += 1
        next
      end

      trend = Trend.new(
        date: parsed_date,
        day_unknown: day_unknown,
        month_unknown: month_unknown,
        title: entry[:title] || 'メジャーデビュー',
        units: [{ unit_id: unit.id, name: unit.name }],
        unit_phenomenon: phenomenon,
        active: true,
        publish_start_at: Time.current
      )

      if trend.save
        puts "  [ADD] #{unit.name} #{date_str} #{phenomenon} (trend id=#{trend.id})"
        added += 1
      else
        puts "  [ERROR] #{unit.name} #{date_str}: #{trend.errors.full_messages.join(', ')}"
        errors += 1
      end
    end

    puts "\nDone. added=#{added}, skipped=#{skipped}, errors=#{errors}"

    if added.positive?
      cache_key = TimelineController::CACHE_KEY
      Rails.cache.delete(cache_key)
      puts "Cache deleted: #{cache_key}"
    end
  end
end
