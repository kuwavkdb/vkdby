# frozen_string_literal: true

namespace :on_this_day do
  desc '「今日はなんの日？」投稿文を表示する（送信はしない、issue #1742）。DATE=YYYY-MM-DD で日付指定（既定はJSTの当日）'
  task preview: :environment do
    date = ENV['DATE'].present? ? Date.iso8601(ENV['DATE']) : Time.find_zone('Asia/Tokyo').today
    result = OnThisDayPostBuilder.new(date).build
    if result
      puts result.text
      puts '----------'
      puts "文字数（X換算）: #{result.weighted_length} / #{XPostLength::MAX}"
    else
      puts "#{date}: 動向も誕生日もないため送信対象外です"
    end
  end
end
