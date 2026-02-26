# frozen_string_literal: true

ActiveRecord::Base.transaction do
  # 名前が一致するUnitとWikipageを探す
  target = nil

  # 特定のユニット（データ量が多いものやパターン網羅性が高いもの）を優先
  priority_units = ['SHAZNA', 'LUNA SEA', 'GLAY', 'Dir en grey']

  priority_units.each do |name|
    u = Unit.find_by(name: name)
    w = Wikipage.find_by(name: name)
    if u && w
      target = { unit: u, wikipage: w }
      break
    end
  end

  unless target
    # 優先リストで見つからなければ、最初に見つかったペアを使用
    Unit.find_each do |u|
      w = Wikipage.find_by(name: u.name)
      if w
        target = { unit: u, wikipage: w }
        break
      end
    end
  end

  unless target
    puts 'No matching unit and wikipage found'
    exit
  end

  unit = target[:unit]
  wikipage = target[:wikipage]

  puts "Testing import for #{unit.name} (ID: #{unit.id})"

  # 既存のスナップショットをクリアして再インポートを試す
  # 注意: 実際には削除せず、インポート処理がエラーなく走るか、
  # または特定のスナップショットが期待通りにパースされるかを確認するだけでも良いが
  # ここでは実際にインポート処理を呼んでみる

  # V2インポーターのインスタンス化
  importer = WikipageImporterV2.new(wikipage)

  # パースメソッドを直接呼んでみる（privateでなければ）
  # しかし import メソッドは delete_all を含むかもしれないので、
  # ここでは単に既存データを確認するだけにするか、
  # 実際に import を走らせて Rollback する

  puts 'Running import...'
  importer.import

  puts 'Import finished. Checking snapshots...'

  snapshots = unit.unit_snapshots.order(:snapshot_index)
  puts "Created #{snapshots.count} snapshots"

  snapshots.each do |s|
    puts "Snapshot ID: #{s.id}"
    puts "  Label: #{s.display_label.inspect}"
    puts "  Date: #{s.snapshot_date}"
    puts "  Index: #{s.snapshot_index}"
    puts "  Current: #{s.current}"

    members = s.snapshot_people.order(:sort_order)
    puts "  Members: #{members.count}"
    members.each do |sp|
      name = sp.person&.name || sp.person_name
      puts "    - [#{sp.sort_order}] #{sp.part_alias}: #{name} (Key: #{sp.old_person_key})"
    end
    puts '---'
  end

  raise ActiveRecord::Rollback
end
puts 'Rollback successful'
