# frozen_string_literal: true

namespace :convert do
  desc 'Convert old_trends to trends'
  task old_trends: :environment do
    puts 'Start converting OldTrend to Trend...'
    Trend.delete_all

    count = 0
    skipped_count = 0

    OldTrend.where(publish: true).find_each do |old|
      # Handle date parsing
      target_date = old.target_date
      day_unknown = false
      month_unknown = false
      clean_date = target_date.dup

      case target_date
      when /^\d{4}$/
        # Format "YYYY"
        month_unknown = true
        day_unknown = true
        clean_date = "#{target_date}/01/01"
      when %r{/00/00$}
        # Format "YYYY/00/00" or "YYYY/MM/00/00" (though unlikely)
        month_unknown = true
        day_unknown = true
        clean_date = target_date.sub(%r{/00/00$}, '/01/01')
      when %r{/00$}
        # Format "YYYY/MM/00"
        day_unknown = true
        clean_date = target_date.sub(%r{/00$}, '/01')
      when %r{/\d{2}/00}
        # Catch other cases where day is 00 but maybe not at end? unlikely given strict format but good to be safe
        day_unknown = true
        clean_date = clean_date.gsub('/00', '/01')
      end

      begin
        date_obj = Date.parse(clean_date)
      rescue Date::Error
        date_obj = Date.new(1970, 1, 1) # Fallback
        puts "Invalid date found: OldTrend##{old.id} target_date=#{old.target_date}, defaulted to 1970-01-01"
      end

      # Base attributes
      trend = Trend.new(
        date: date_obj,
        day_unknown: day_unknown,
        month_unknown: month_unknown,
        title: old.content&.lines&.first&.chomp || old.target_name,
        content: old.content,
        quote: old.quote,
        quote_url: old.quote_url,
        via_name: old.via,
        via_url: old.via_url,
        active: old.publish,
        old_trend_id: old.id,
        old_wiki_id: old.wikipage_id
      )

      # Publish start date
      trend.publish_start_at = old.publish_plan_date || old.created_at || Time.current

      # Find associations
      unit = Unit.find_by(old_wiki_id: old.wikipage_id)
      person = Person.find_by(old_wiki_id: old.wikipage_id)

      if unit
        trend.units = [{ unit_id: unit.id, unit_name: unit.name }]
      elsif person
        trend.people = [{ person_id: person.id, person_name: person.name }]
      elsif old.target_name.present?
        trend.units = [{ name: old.target_name }]
      end

      # Map Phenomenon
      apply_phenomenon(trend, old)

      if trend.save
        count += 1
        print '.' if (count % 100).zero?
      else
        puts "\nFailed to save Trend (OldTrend ID: #{old.id}): #{trend.errors.full_messages.join(', ')}"
        skipped_count += 1
      end
    end

    puts "\nConversion completed. Imported: #{count}, Skipped: #{skipped_count}"
  end

  # rubocop:disable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
  def apply_phenomenon(trend, old)
    case old.trend_class
    when 1
      trend.unit_phenomenon = if old.content&.include?('メジャーデビュー')
                                :major_debut
                              elsif old.content&.include?('結成')
                                :formation
                              elsif old.content&.include?('始動') || old.content&.include?('1st.LIVE')
                                :first_live
                              elsif old.content&.include?('解禁')
                                :announcement
                              else
                                :formation
                              end
    when 2
      trend.unit_phenomenon = if old.content&.match?(/休止|停止/)
                                :suspend
                              else
                                :finish
                              end
    when 3
      trend.unit_phenomenon = :restart
    when 4
      trend.unit_phenomenon = :limited
    when 5
      trend.unit_phenomenon = if old.content&.match?(/解散/)
                                :finish
                              else
                                :limited
                              end
    when 8
      trend.unit_phenomenon = :other
    when 11
      trend.person_phenomenon = :join_member
    when 12
      trend.person_phenomenon = :leave_member
    when 19
      trend.person_phenomenon = :other
    else
      if old.content&.include?('メジャーデビュー')
        trend.unit_phenomenon = :major_debut
      elsif old.content&.match?(/再始動|再結成|活動再開/)
        trend.unit_phenomenon = :restart
      elsif old.content&.match?(/休止|停止/)
        trend.unit_phenomenon = :suspend
      elsif old.content&.match?(/改名|変更/)
        trend.unit_phenomenon = :rename
      elsif old.content&.match?(/ライブ|LIVE/)
        trend.unit_phenomenon = :live
      elsif old.content&.match?(/メディア|テレビ|ラジオ/)
        trend.unit_phenomenon = :media
      else
        trend.etc_phenomenon = :other
      end
    end
  end
  # rubocop:enable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
end
