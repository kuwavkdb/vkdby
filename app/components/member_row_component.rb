class MemberRowComponent < ViewComponent::Base
  def initialize(member:, hide_active: false)
    @member = member
    @hide_active = hide_active
  end

  private

  def status_classes
    base_classes = "text-[0.65rem] font-black uppercase px-2 py-0.5 rounded-md"
    color_classes = case @member.status
                    when "active"
                      "bg-emerald-100 dark:bg-emerald-900/40 text-emerald-700 dark:text-emerald-400"
                    when "left"
                      "bg-rose-100 dark:bg-rose-900/40 text-rose-700 dark:text-rose-400"
                    when "pre"
                      "bg-amber-100 dark:bg-amber-900/40 text-amber-700 dark:text-amber-400"
                    when "pending"
                      "bg-sky-100 dark:bg-sky-900/40 text-sky-700 dark:text-sky-400"
                    else
                      "bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300"
                    end
    "#{base_classes} #{color_classes}"
  end

  def show_status?
    !(@hide_active && @member.status == "active")
  end

  def sorted_person_logs
    @member.person.person_logs.sort_by { |l| [ l.log_date.to_s, l.sort_order || 0 ] }
  end
end
