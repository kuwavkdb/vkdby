# frozen_string_literal: true

# issue #1281: #1268/#1271 でOGP画像生成にCJK対応フォントを追加し文字化けを修正したが、
# OgpImageAttachable（app/models/concerns/ogp_image_attachable.rb）はogp_image添付を
# 一度生成すると使い回す実装のため、修正前に生成済みの画像は再生成のトリガー
# （name/titleカラムの変更）がない限り文字化けしたまま残ってしまう。
#
# 本タスクは対象の添付をpurgeし、次回アクセス時（ensure_ogp_image!）に新フォントで
# オンデマンド再生成させる。本番で一度だけ実行すればよく、cron化等は不要。
#
# 文字化けが発生するのは日本語（ひらがな・カタカナ・漢字）を含むname/titleのみ
# （英数字のみの名前はもともとASCIIグリフで文字化けしないため対象外にできる）。
namespace :ogp_image do
  desc '文字化けしたogp_image添付をpurgeし、次回アクセス時に再生成させる（issue #1281）'
  task purge_garbled: :environment do
    jp_char_regex = '[ぁ-んァ-ヶ一-龠]'
    dryrun = ENV['DRYRUN'] == '1'

    puts 'Mode: DRYRUN (purgeは行いません)' if dryrun

    targets = {
      Unit => :name,
      Person => :name,
      CustomPage => :title
    }

    targets.each do |klass, column|
      scope = klass.with_discarded.where("#{column} ~ ?", jp_char_regex).with_attached_ogp_image
      purged = 0

      scope.find_each do |record|
        next unless record.ogp_image.attached?

        purged += 1
        puts "  [#{klass.name}##{record.id}] #{record.public_send(column)}"
        record.ogp_image.purge_later unless dryrun
      end

      puts "#{klass.name}: #{purged}件のogp_imageを#{dryrun ? '検出しました（未purge）' : 'purgeしました'}"
    end

    puts 'Done!'
  end
end
