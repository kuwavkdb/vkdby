# frozen_string_literal: true

# == Schema Information
#
# Table name: people
#
#  id            :bigint           not null, primary key
#  birth_year    :integer
#  birthday      :date
#  blood         :string
#  hometown      :string
#  key           :string
#  name          :string
#  name_kana     :string
#  old_history   :text
#  old_key       :string
#  old_wiki_text :text
#  parts         :json
#  status        :integer          default("active"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_people_on_key      (key) UNIQUE
#  index_people_on_name     (name)
#  index_people_on_old_key  (old_key) UNIQUE
#
require 'test_helper'

class PersonTest < ActiveSupport::TestCase
  test "parse_old_history parses simple history" do
    person = Person.new(old_history: "BandA → BandB")
    history = person.parse_old_history

    assert_equal 2, history.size
    assert_equal "BandA", history[0][0][:unit_name]
    assert_equal "BandB", history[1][0][:unit_name]
  end

  test "parse_old_history parses concurrent memberships" do
    person = Person.new(old_history: "BandA → BandB、BandC → BandD")
    history = person.parse_old_history

    assert_equal 3, history.size
    
    # First period
    assert_equal 1, history[0].size
    assert_equal "BandA", history[0][0][:unit_name]

    # Second period (concurrent)
    assert_equal 2, history[1].size
    assert_equal "BandB", history[1][0][:unit_name]
    assert_equal "BandC", history[1][1][:unit_name]

    # Third period
    assert_equal 1, history[2].size
    assert_equal "BandD", history[2][0][:unit_name]
  end

  test "parse_old_history parses complex formats with links and parens" do
    # [[Sadie]](Mao)、[[The THIRTEEN]](Mao)、[[Frantic EMIRY|Frantic EMIRY]](Rem.)
    # Note: Using escaped brackets for the test string as it would be in DB
    history_str = "[[Sadie]](Mao)、[[The THIRTEEN]](Mao)、[[Frantic EMIRY|Frantic EMIRY]](Rem.)"
    person = Person.new(old_history: history_str)
    history = person.parse_old_history

    assert_equal 1, history.size
    concurrent = history[0]
    assert_equal 3, concurrent.size

    assert_equal "Sadie", concurrent[0][:unit_name]
    assert_equal "Mao", concurrent[0][:part_and_name]
    
    assert_equal "The THIRTEEN", concurrent[1][:unit_name]
    assert_equal "Mao", concurrent[1][:part_and_name]

    assert_equal "Frantic EMIRY", concurrent[2][:unit_name]
    assert_equal "Rem.", concurrent[2][:part_and_name]
  end
  
  test "parse_old_history handles parens wrapping correctly" do
    person = Person.new(old_history: "(Solo) → (BandA)")
    history = person.parse_old_history
    
    assert_equal 2, history.size
    assert_equal "(Solo)", history[0][0][:unit_name]
    assert_equal "(BandA)", history[1][0][:unit_name] # Current logic keeps parens if not matching link pattern?
    # Let's check the implementation logic:
    # wrapped_in_parens = segment.start_with?('(') && segment.end_with?(')')
    # content = wrapped_in_parens ? segment[1..-2] : segment
    # Else block: concurrent_items << { unit_name: item_segment.strip } -> using ORIGINAL item_segment
    
    # Wait, the implementation says:
    # Pattern 3: Plain text - No link, display as-is (including parentheses)
    # else
    #   concurrent_items << {
    #     unit_name: item_segment.strip
    #   }
    
    # So (Solo) should result in unit_name: "(Solo)"
    assert_equal "(Solo)", history[0][0][:unit_name]
  end
end
