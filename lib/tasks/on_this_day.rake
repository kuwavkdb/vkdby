# frozen_string_literal: true

namespace :on_this_day do
  desc '「今日はなんの日？」投稿文を表示する（送信はしない、issue #1742）。DATE=MM-DD で日付指定（既定はJSTの当日）'
  task preview: :environment do
    date = ENV['DATE'].present? ? OnThisDayPostBuilder.parse_month_day(ENV['DATE']) : OnThisDayPostBuilder.today
    abort "DATE は MM-DD 形式で指定してください（例: DATE=05-30）: #{ENV.fetch('DATE', nil)}" unless date

    result = OnThisDayPostBuilder.new(date).build
    if result
      puts result.text
      puts '----------'
      puts "文字数（X換算）: #{result.weighted_length} / #{XPostLength::MAX}"
    else
      puts "#{date.month}/#{date.day}: 載せる内容がないため、その旨のメールになります"
    end
  end
end
