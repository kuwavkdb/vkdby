import { Controller } from "@hotwired/stimulus"

// Unit簡単登録フォーム（quick_new）の各入力欄を、外部から（YAML貼り付け機能等から）
// まとめて設定するためのコントローラー（issue #1620）。
// フォームの送信そのものには関与しない。行が足りない場合はtemplateから複製して追加する。
export default class extends Controller {
  static targets = [
    "name", "key", "unitType", "status",
    "activityPeriodContainer", "activityPeriodRow", "activityPeriodTemplate",
    "linkContainer", "linkRow", "linkTemplate",
    "snapshotDate", "snapshotLabel",
    "memberContainer", "memberRow", "memberTemplate"
  ]
  static values = { partOptions: Array }

  // data: unit-url スキル等が出力するYAMLをパースした結果のプレーンオブジェクト
  // {name, key, unit_type, status, activity_periods: [...], links: [...], members: [...],
  //  snapshot_date, snapshot_label}
  applyData(data) {
    if (data.name != null) this.nameTarget.value = data.name
    if (data.key != null) this.keyTarget.value = data.key
    if (data.unit_type != null) this.setRadio(this.unitTypeTarget, data.unit_type)
    if (data.status != null) this.setRadio(this.statusTarget, data.status)
    if (data.snapshot_date != null && this.hasSnapshotDateTarget) this.snapshotDateTarget.value = data.snapshot_date
    if (data.snapshot_label != null && this.hasSnapshotLabelTarget) this.snapshotLabelTarget.value = data.snapshot_label

    if (Array.isArray(data.activity_periods)) {
      this.applyRows(
        data.activity_periods, this.activityPeriodContainerTarget, this.activityPeriodTemplateTarget,
        "activityPeriodRow",
        (row, period) => {
          this.setFieldValue(row, "[from]", period.from)
          this.setFieldValue(row, "[to]", period.to)
          this.setFieldValue(row, "[label]", period.label)
        }
      )
    }

    if (Array.isArray(data.links)) {
      this.applyRows(
        data.links, this.linkContainerTarget, this.linkTemplateTarget, "linkRow",
        (row, link) => {
          this.setFieldValue(row, "[text]", link.text)
          this.setFieldValue(row, "[url]", link.url)
        }
      )
    }

    if (Array.isArray(data.members)) {
      this.applyRows(
        data.members, this.memberContainerTarget, this.memberTemplateTarget, "memberRow",
        (row, member) => {
          this.setFieldValue(row, "[person_name]", member.person_name)
          if (member.part != null && this.partOptionsValue.includes(member.part)) {
            this.setFieldValue(row, "[part]", member.part)
          }
          const extraProfile = member.extra_profile || {}
          this.setFieldValue(row, "[extra_profile][birthday]", extraProfile.birthday)
          this.setFieldValue(row, "[extra_profile][birth_year]", extraProfile.birth_year)
          this.setFieldValue(row, "[extra_profile][blood]", extraProfile.blood)
          this.setFieldValue(row, "[extra_profile][hometown]", extraProfile.hometown)
          if (extraProfile.birthday || extraProfile.birth_year || extraProfile.blood || extraProfile.hometown) {
            const details = row.querySelector("details")
            if (details) details.open = true
          }
        }
      )
    }
  }

  // items（プレーンオブジェクトの配列）を、既存行に足りない分はtemplateから複製して追加しながら埋める
  applyRows(items, container, template, rowTargetName, fillRow) {
    const existingRows = Array.from(container.querySelectorAll(`[data-quick-unit-form-target~="${rowTargetName}"]`))
    // 追加した行数分だけインデックスをずらす。次に追加する行の名前属性は
    // 既存行数（テンプレート複製前の初期表示行数）を起点に連番を振ればよく、
    // 実際のフォーム送信時に Rails 側がどの数字かを解釈することはない
    // （params[:unit][:members] はハッシュとして values を辿るだけで、キーの連続性は問わない）。
    let nextIndex = existingRows.length

    items.forEach((item, index) => {
      let row = existingRows[index]
      if (!row) {
        row = this.appendRowFromTemplate(container, template, nextIndex)
        nextIndex += 1
      }
      fillRow(row, item || {})
    })
  }

  appendRowFromTemplate(container, template, index) {
    const html = template.innerHTML.replaceAll("__INDEX__", index)
    const wrapper = document.createElement("div")
    wrapper.innerHTML = html.trim()
    const row = wrapper.firstElementChild
    container.appendChild(row)
    return row
  }

  setFieldValue(row, nameSuffixPattern, value) {
    if (value == null || value === "") return
    const field = Array.from(row.querySelectorAll("input, select")).find((el) => el.name.includes(nameSuffixPattern))
    if (field) field.value = value
  }

  setRadio(container, value) {
    const radio = container.querySelector(`input[type="radio"][value="${CSS.escape(String(value))}"]`)
    if (radio) radio.checked = true
  }
}
