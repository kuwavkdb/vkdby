# frozen_string_literal: true

# issue #1215: ruby-vips導入前にアップロードされた画像blobは、Active Storageの画像解析
# （ActiveStorage::Analyzer::ImageAnalyzer）が実質機能しておらず（ImageMagick CLI/vipsの
# いずれも未インストールだったため）、metadataにwidth/heightが記録されていない
# （analyzed: trueにはなっているため、放置すると自動では再解析されない）。
# ruby-vips導入後に本タスクを一度実行し、既存blobのメタデータを補完する。
namespace :active_storage do
  desc '画像blobのメタデータ(width/height)を再解析して補完する（issue #1215）'
  task analyze_images: :environment do
    scope = ActiveStorage::Blob.where('content_type LIKE ?', 'image/%')

    total = scope.count
    updated = 0
    failed = 0

    puts "Target: #{total} image blobs"

    scope.find_each do |blob|
      next if blob.metadata['width'].present? && blob.metadata['height'].present?

      blob.analyze
      if blob.metadata['width'].present? && blob.metadata['height'].present?
        updated += 1
      else
        failed += 1
        puts "[SKIP] blob##{blob.id} (#{blob.filename}): width/heightを取得できませんでした"
      end
    rescue StandardError => e
      failed += 1
      puts "[ERROR] blob##{blob.id} (#{blob.filename}): #{e.class}: #{e.message}"
    end

    puts 'Done!'
    puts "  Updated: #{updated}"
    puts "  Failed:  #{failed}"
  end
end
