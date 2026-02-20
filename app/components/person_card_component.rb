# frozen_string_literal: true

class PersonCardComponent < ViewComponent::Base
  def initialize(person:, size: :sm)
    super()
    @person = person
    @size = size
  end

  private

  def card_classes
    base = 'group block bg-slate-50 dark:bg-slate-900/50 border border-slate-100 dark:border-slate-700 ' \
           'hover:border-person transition-all relative overflow-hidden'
    if @size == :lg
      "#{base} p-6 rounded-2xl hover:scale-[1.02]"
    else
      "#{base} p-4 rounded-lg"
    end
  end

  def icon_padding_classes
    @size == :lg ? 'p-3' : 'p-2'
  end

  def icon_size_classes
    @size == :lg ? 'w-16 h-16' : 'w-10 h-10'
  end

  def name_classes
    if @size == :lg
      'text-lg font-black text-slate-800 dark:text-slate-200 group-hover:text-person transition-colors truncate'
    else
      'font-bold text-slate-800 dark:text-slate-200 group-hover:text-person transition-colors'
    end
  end

  def kana_classes
    if @size == :lg
      'text-xs font-bold text-slate-400 dark:text-slate-500 mt-1'
    else
      'text-xs text-slate-400 dark:text-slate-500 mt-0.5'
    end
  end
end
