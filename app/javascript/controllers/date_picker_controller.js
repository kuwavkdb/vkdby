import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["input", "picker"]

    connect() {
        // Optionally set picker value if input has valid date on load
        this.syncPickerFromInput()
    }

    // Called when a custom trigger (e.g. an icon button) should open the native date picker.
    // The native picker input itself may be visually hidden (e.g. via sr-only), so a plain
    // click/focus on it isn't available to the user; showPicker() opens it programmatically.
    open() {
        if (this.pickerTarget.showPicker) {
            try {
                this.pickerTarget.showPicker()
                return
            } catch {
                // fall through to focus() below (e.g. not called from a user gesture)
            }
        }
        this.pickerTarget.focus()
    }

    // Called when value is picked from the date picker
    apply(event) {
        const pickedDate = event.target.value
        if (pickedDate) {
            // date input value is always YYYY-MM-DD
            // Convert to YYYY/MM/DD
            this.inputTarget.value = pickedDate.replace(/-/g, '/')
        }
    }

    // Not strictly necessary but nice: try to sync picker if user types a valid date
    syncPickerFromInput() {
        const val = this.inputTarget.value
        // Check if matches YYYY/MM/DD
        if (/^\d{4}\/\d{2}\/\d{2}$/.test(val)) {
            this.pickerTarget.value = val.replace(/\//g, '-')
        }
    }
}
