# frozen_string_literal: true

namespace :search_text do
  desc '表記ゆれを吸収した検索用の search_text を全件作り直す（正規化のルールを変えたときに使う。issue #1842）'
  task rebuild: :environment do
    [Unit, Person, Venue].each do |model|
      model.rebuild_search_text!
      puts "#{model.name}: rebuilt"
    end
  end
end
