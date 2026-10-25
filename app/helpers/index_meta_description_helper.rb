# frozen_string_literal: true

# 索引ページ（バンド索引 /units・個人索引 /people）の meta description を組み立てる（issue #1957, #1959）。
# ページの見出しの下にも同じ文を表示する（件数もこの文で示す）。
# 一覧ページはサイトの方向性の説明なので「ヴィジュアル系」と書く。索引ページの説明にならないため、
# バンド・個人のページのような「〜の経歴や…を掲載」は付けない。
# 一覧の検索はひらがなのよみがなに対応していないため、「よみがなで探せる」とは書かない。
# 絞り込んだときは、条件を先に書き、検索語を最後に加えて「絞り込み後の件数/全体の件数」を添える。
# 検索語は利用者の入力なので INDEX_QUERY_MAX_LENGTH 字で切る（検索語付きのページは noindex にしている）。
# 2ページ目以降はページ番号を添える。
module IndexMetaDescriptionHelper
  INDEX_QUERY_MAX_LENGTH = 30
  UNITS_INDEX_SUBJECT = 'ヴィジュアル系バンド'
  PEOPLE_INDEX_SUBJECT = 'ヴィジュアル系バンドマン'

  # バンド索引。索引に載るのはバンド（ユニット）だけで個人は載らないため「アーティスト」とは書かない。例:
  #   絞り込みなし「ヴィジュアル系バンドの索引。登録数は3,456組。名前やタグで絞り込めます。」
  #   絞り込みあり「「活動中」「2000年代」のヴィジュアル系バンドのうち、「〇〇」で探した一覧（3/3,456件）。」
  # filtered_count は絞り込み後の件数（絞り込んでいなければ nil）
  def units_index_meta_description(total:, filtered_count: nil, query: nil, tag_names: [], page: 1)
    if filtered_count.nil?
      return "#{UNITS_INDEX_SUBJECT}の索引。登録数は#{number_with_delimiter(total)}組#{index_page_note(page)}。" \
             '名前やタグで絞り込めます。'
    end

    index_filtered_meta_description(UNITS_INDEX_SUBJECT, index_counts_note(filtered_count, total, page), query, tag_names)
  end

  # 個人索引。例:
  #   絞り込みなし「ヴィジュアル系バンドマンの索引。登録数は12,345人。名前やパート・出身地などで絞り込めます。」
  #   絞り込みあり「「ボーカル」「東京都」のヴィジュアル系バンドマンのうち、「〇〇」で探した一覧（3/12,345件）。」
  # condition_names は絞り込みの条件の表示名（people_index_filter_names の結果のあとに選んだタグの名前を続ける）。
  # 件数は個人ページのある人だけで、検索したときに出る「個人ページのないメンバー」は含めない
  def people_index_meta_description(total:, filtered_count: nil, query: nil, condition_names: [], page: 1)
    if filtered_count.nil?
      return "#{PEOPLE_INDEX_SUBJECT}の索引。登録数は#{number_with_delimiter(total)}人#{index_page_note(page)}。" \
             '名前やパート・出身地などで絞り込めます。'
    end

    index_filtered_meta_description(PEOPLE_INDEX_SUBJECT, index_counts_note(filtered_count, total, page), query, condition_names)
  end

  # 個人索引の、個人の項目での絞り込みの表示名。パート→出身地→状況→血液型の順。
  # 状況・血液型の「不明」は、どちらの不明か分かるよう「状況不明」「血液型不明」と書く。
  # hometown は登録されている出身地（絞り込みの候補）にあるものだけを渡す。自由に入れられる値をそのまま
  # 説明文や見出しの下に出さないため（PeopleController#index の @described_hometown）
  def people_index_filter_names(part: nil, hometown: nil, status: nil, blood: nil)
    status_name = status == 'unknown' ? '状況不明' : Person::STATUS_TRANSLATIONS[status]
    blood_name = blood == 'Unknown' ? '血液型不明' : "#{blood}型" if blood.present?
    [MetaDescriptionHelper::PART_NAMES[part], hometown.presence, status_name, blood_name].compact
  end

  # 選んだタグの表示名。絞り込みグループの順→グループ内の順に並べる。コントローラは tag_ids のキーに関係なく値で
  # 絞り込むので、値（タグの id）で探す。絞り込みグループに無いタグ（手で作った URL など）は、その後ろに id から引いて並べる
  def index_selected_tag_names(filter_groups, selected_tag_ids)
    ids = selected_tag_ids.values.map(&:to_s)
    grouped = filter_groups.flat_map do |group|
      group.tag_indices.select { |tag| ids.include?(tag.id.to_s) }.sort_by { |tag| tag.order_in_group.to_i }
    end
    rest_ids = ids - grouped.map { |tag| tag.id.to_s }
    rest = rest_ids.any? ? TagIndex.where(id: rest_ids).order(:id).to_a : []
    (grouped + rest).map(&:short_name)
  end

  private

  # 「（2ページ目）」。1ページ目は空
  def index_page_note(page)
    "（#{page}ページ目）" if page > 1
  end

  # 「3/3,456件」「3/3,456件・2ページ目」
  def index_counts_note(filtered_count, total, page)
    ["#{number_with_delimiter(filtered_count)}/#{number_with_delimiter(total)}件", ("#{page}ページ目" if page > 1)]
      .compact.join('・')
  end

  # 絞り込んだ索引ページの説明文。「「活動中」のヴィジュアル系バンドのうち、「〇〇」で探した一覧（3/3,456件）。」など
  def index_filtered_meta_description(subject, counts_note, query, condition_names)
    conditions = condition_names.map { |name| "「#{name}」" }.join.presence
    keyword = "「#{query.to_s.strip.truncate(INDEX_QUERY_MAX_LENGTH)}」" if query.to_s.strip.present?
    lead = if conditions && keyword
             "#{conditions}の#{subject}のうち、#{keyword}で探した一覧"
           elsif conditions
             "#{conditions}の#{subject}の一覧"
           elsif keyword
             "#{keyword}で探した#{subject}の一覧"
           else
             "#{subject}の一覧"
           end
    "#{lead}（#{counts_note}）。"
  end
end
