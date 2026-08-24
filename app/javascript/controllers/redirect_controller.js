// Redirect controller — triggered by Turbo Stream when tournament ends.
// When this controller connects (element inserted into DOM via broadcast),
// it navigates all connected browsers to the results page.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  connect() {
    if (this.urlValue) {
      Turbo.visit(this.urlValue)
    }
  }
}
