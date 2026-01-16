# Test data for links
puts "Seeding links..."

# People links
{
  "Leader A" => [
    { text: "Twitter", url: "https://twitter.com/leader_a_official" },
    { text: "Official Blog", url: "https://ameblo.jp/leader_a" }
  ],
  "Guitarist B" => [
    { text: "Instagram", url: "https://instagram.com/gt_b_vocal" }
  ],
  "Unified Person" => [
    { text: "Personal Site", url: "https://example.com/p_unified" },
    { text: "X", url: "https://x.com/unified_x" }
  ]
}.each do |name, links|
  person = Person.find_by(name: name)
  if person
    links.each do |link_data|
      person.links.find_or_create_by!(link_data)
    end
  end
end

# Unit links
{
  "月光花" => [
    { text: "Official Website", url: "https://example.com/gekkohana" },
    { text: "Old Music Video", url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ" },
    { text: "Latest Music Video", url: "https://www.youtube.com/watch?v=L_jWHffIx5E" }
  ],
  "Legend Band" => [
    { text: "Wiki", url: "https://ja.wikipedia.org/wiki/Legend_Band" }
  ],
  "Unified Unit" => [
    { text: "Portal", url: "https://example.com/u_unified" }
  ]
}.each do |name, links|
  unit = Unit.find_by(name: name)
  if unit
    links.each do |link_data|
      unit.links.find_or_create_by!(link_data)
    end
  end
end

# Unit logs
unit = Unit.find_by(name: "月光花")
if unit
  unit.unit_logs.find_or_create_by!(log_date: "2020/01/01", phenomenon: :announcement, text: "結成発表（公式Xにて）")
  unit.unit_logs.find_or_create_by!(log_date: "2020/02/01", phenomenon: :first_live, text: "渋谷公会堂にて初ライブを開催")
  
  # Existing PersonLogs for this unit's people will be integrated automatically
end

puts "Done seeding links and logs."
