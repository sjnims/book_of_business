import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="order-form"
export default class extends Controller {
  static targets = ["orderType", "originalOrderSelect"]

  connect() {
    this.updateOriginalOrderRequirement()
  }

  updateOriginalOrderRequirement() {
    const orderType = this.orderTypeTarget.value
    const requiresOriginalOrder = ['renewal', 'de_book'].includes(orderType)
    
    if (requiresOriginalOrder) {
      this.originalOrderSelectTarget.setAttribute('required', 'required')
    } else {
      this.originalOrderSelectTarget.removeAttribute('required')
    }
  }
}
