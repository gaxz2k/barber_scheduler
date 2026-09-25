import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["date", "slots"]

  connect() {
    if (this.hasDateTarget) {
      this.dateTarget.addEventListener("change", this.refreshSlots)
    }
  }

  disconnect() {
    if (this.hasDateTarget) {
      this.dateTarget.removeEventListener("change", this.refreshSlots)
    }

    this.request?.abort()
  }

  refreshSlots = async () => {
    const date = this.dateTarget?.value
    const serviceId = this.element.querySelector("[name='appointment[service_id]']")?.value
    const professionalId = this.element.querySelector("[name='appointment[professional_id]']")?.value

    if (!date || !serviceId || !professionalId) return

    this.request?.abort()
    this.request = new AbortController()
    this.slotsTarget.setAttribute("aria-busy", "true")

    try {
      const response = await fetch(
        `/appointments/availability?service_id=${encodeURIComponent(serviceId)}&professional_id=${encodeURIComponent(professionalId)}&date=${encodeURIComponent(date)}`,
        { headers: { Accept: "application/json" }, signal: this.request.signal }
      )

      if (!response.ok) throw new Error("Não foi possível carregar os horários.")

      const payload = await response.json()
      this.renderSlots(payload.slots || [])
    } catch (error) {
      if (error.name !== "AbortError") {
        this.renderMessage("Não foi possível atualizar os horários. Tente novamente.")
      }
    } finally {
      this.slotsTarget.removeAttribute("aria-busy")
    }
  }

  renderSlots(slots) {
    if (slots.length === 0) {
      this.renderMessage("Não há horários disponíveis para esta data. Escolha outro dia.")
      return
    }

    this.slotsTarget.innerHTML = `
      <div class="slot-grid" role="radiogroup" aria-label="Horários disponíveis">
        ${slots.map((slot) => `
          <label class="slot-card">
            <input class="choice-input" type="radio" name="appointment[start_at]" value="${this.escape(slot.value)}" required>
            <span>${this.escape(slot.label)}</span>
          </label>
        `).join("")}
      </div>
    `
  }

  renderMessage(message) {
    this.slotsTarget.innerHTML = `<div class="form-alert" role="status">${this.escape(message)}</div>`
  }

  escape(value) {
    const element = document.createElement("span")
    element.textContent = value
    return element.innerHTML
  }
}
