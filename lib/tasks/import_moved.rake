# frozen_string_literal: true

namespace :import do
  desc 'Import moved pages from WikiPageImports (page_type=moved)'
  task moved: :environment do
    dryrun = ENV['DRYRUN'] == '1'

    puts 'Starting moved page import...'
    puts 'Mode: DRYRUN (DB への書き込みは行いません)' if dryrun
    count = 0
    skipped_no_dest = 0
    skipped_not_moved = 0
    skipped_include = 0

    WIKI_LINK_RE = /\[\[(?:[^\|\]]+\|)?([^\]]+)\]\]/
    INCLUDE_RE   = /\{\{include\s+/i

    scope = WikiPageImport.where(status: 'skipped', page_type: 'moved').includes(:wikipage)
    total = scope.count
    puts "Target: #{total} records"

    scope.find_each do |wpi|
      wp = wpi.wikipage
      unless wp
        puts "[SKIP] WikiPageImport##{wpi.id}: wikipage not found"
        next
      end

      wiki = wp.wiki.to_s

      if (m = wiki.match(WIKI_LINK_RE))
        destination_name = m[1].strip
        destination = Unit.find_by(old_key: destination_name) ||
                      Person.find_by(old_key: destination_name)

        unless destination
          # URL エンコード済みの old_key でも検索
          encoded = URI.encode_www_form_component(destination_name.encode('EUC-JP'))
          destination = Unit.find_by(old_key: encoded) || Person.find_by(old_key: encoded)
        end

        unless destination
          wpi.update!(note: 'destination not found') unless dryrun
          puts "[NOT FOUND] #{wp.title} (ID: #{wp.id}) → '#{destination_name}'"
          skipped_no_dest += 1
          next
        end

        # moved Unit を作成 or 更新
        encoded_old_key = URI.encode_www_form_component(wp.name.encode('EUC-JP'))
        source_for_key = if wp.name.match?(/^[[:ascii:]\s-]+$/)
                           wp.name
                         else
                           encoded_old_key.gsub(/%/, '')
                         end
        unit_key = source_for_key.downcase.gsub(/[^a-z0-9-]+/, '-').gsub(/-+/, '-')

        unit = Unit.find_by(old_wiki_id: wp.id) || Unit.new
        unique_key = resolve_moved_key(unit_key, unit.id)

        unless dryrun
          unit.key             = unique_key
          unit.name            = wp.title
          unit.old_key         = encoded_old_key
          unit.old_wiki_id     = wp.id
          unit.unit_type       = :moved
          unit.destination_key = destination.key
          unit.status          = :active
          unit.save!

          wpi.update!(status: 'imported', import_target: unit)
        end

        puts "[IMPORTED] #{wp.title} (ID: #{wp.id}) → #{destination.key} (key: #{unique_key})"
        count += 1

      elsif wiki.match?(INCLUDE_RE)
        puts "[SKIP/INCLUDE] #{wp.title} (ID: #{wp.id})"
        skipped_include += 1

      else
        wpi.update!(status: 'skipped', note: 'not moved') unless dryrun
        puts "[NOT MOVED] #{wp.title} (ID: #{wp.id})"
        skipped_not_moved += 1
      end
    end

    puts dryrun ? 'Dryrun complete!' : 'Import complete!'
    puts "  Imported:              #{count}"
    puts "  Destination not found: #{skipped_no_dest}"
    puts "  Not moved:             #{skipped_not_moved}"
    puts "  Include (skipped):     #{skipped_include}"
  end
end

def resolve_moved_key(base_key, current_id = nil)
  return base_key unless Unit.where(key: base_key).where.not(id: current_id).exists?

  suffix = 2
  loop do
    candidate = "#{base_key}-#{suffix}"
    return candidate unless Unit.where(key: candidate).where.not(id: current_id).exists?

    suffix += 1
  end
end
