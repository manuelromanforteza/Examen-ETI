// Reveal controller — animates the leaderboard on /results.
// Entries are revealed from LAST place to FIRST (for suspense).
// A "skip" button lets users jump straight to the final state.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["entry", "skipButton"]
  static values  = { delay: { type: Number, default: 400 } }

  connect() {
    // entries in DOM order (1st place → last place)
    this._entries = [...this.entryTargets]
    // reveal order: last place first → first place last
    this._queue   = [...this._entries].reverse()
    this._index   = 0
    this._timer   = null

    // Hide everything initially
    this._entries.forEach(el => el.classList.add("reveal-hidden"))

    // Show the skip button
    if (this.hasSkipButtonTarget) {
      this.skipButtonTarget.classList.remove("hidden")
    }

    // Short pause before starting so the page layout settles
    this._timer = setTimeout(() => this._revealNext(), 600)
  }

  // Called by the "Ver todo de una vez" button
  showAll() {
    clearTimeout(this._timer)
    this._entries.forEach(el => {
      el.classList.remove("reveal-hidden")
      el.classList.add("reveal-shown")
    })
    this._finish()
  }

  // ── private ──────────────────────────────────────────────────────────────

  _revealNext() {
    if (this._index >= this._queue.length) {
      this._finish()
      return
    }

    const entry = this._queue[this._index]
    entry.classList.remove("reveal-hidden")
    entry.classList.add("reveal-shown")
    this._index++

    this._timer = setTimeout(() => this._revealNext(), this.delayValue)
  }

  _finish() {
    if (this.hasSkipButtonTarget) {
      this.skipButtonTarget.classList.add("hidden")
    }
    // Highlight the winner (first in DOM = first place)
    if (this._entries.length > 0) {
      this._entries[0].classList.add("winner-highlight")
    }
  }
}
