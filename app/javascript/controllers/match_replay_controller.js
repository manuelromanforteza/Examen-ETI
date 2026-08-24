// Match replay controller — animates rounds from MatchResult.rounds_json data.
// All data is server-rendered; nothing is recalculated here.
import { Controller } from "@hotwired/stimulus"

const ICONS = { cooperate: "🤝", defect: "🗡️" }

export default class extends Controller {
  static targets = ["myScore", "theirScore", "roundLabel", "roundsBody", "skipButton"]
  static values  = {
    rounds:  { type: Array,   default: [] },
    mySide:  { type: String,  default: "a" },   // "a" or "b"
    delay:   { type: Number,  default: 300 }
  }

  connect() {
    this._index     = 0
    this._myAcc     = 0
    this._theirAcc  = 0
    this._timer     = null

    if (this.hasSkipButtonTarget) {
      this.skipButtonTarget.classList.remove("hidden")
    }

    // Short pause so layout settles
    this._timer = setTimeout(() => this._revealNext(), 500)
  }

  skipAll() {
    clearTimeout(this._timer)
    while (this._index < this.roundsValue.length) {
      this._renderRound(this.roundsValue[this._index], this._index)
      this._index++
    }
    this._finish()
  }

  // ── private ──────────────────────────────────────────────────────────────

  _revealNext() {
    if (this._index >= this.roundsValue.length) {
      this._finish()
      return
    }
    this._renderRound(this.roundsValue[this._index], this._index)
    this._index++
    this._timer = setTimeout(() => this._revealNext(), this.delayValue)
  }

  _renderRound(round, index) {
    const side       = this.mySideValue          // "a" or "b"
    const otherSide  = side === "a" ? "b" : "a"

    const myMove     = round[side]               // "cooperate" | "defect"
    const theirMove  = round[otherSide]
    const myPts      = round[`score_${side}`]    // points THIS round
    const theirPts   = round[`score_${otherSide}`]

    this._myAcc    += myPts
    this._theirAcc += theirPts

    // Update scoreboard
    if (this.hasMyScoreTarget)    this.myScoreTarget.textContent    = this._myAcc
    if (this.hasTheirScoreTarget) this.theirScoreTarget.textContent = this._theirAcc
    if (this.hasRoundLabelTarget) this.roundLabelTarget.textContent  = index + 1

    // Build table row
    const myIcon    = ICONS[myMove]    || myMove
    const theirIcon = ICONS[theirMove] || theirMove

    const rowClass  = myPts > theirPts ? "bg-green-50"
                    : myPts < theirPts ? "bg-red-50"
                    : ""

    const row = document.createElement("tr")
    row.className = `${rowClass} transition-all`
    row.style.opacity = "0"
    row.innerHTML = `
      <td class="px-4 py-2 text-gray-400 text-xs">${index + 1}</td>
      <td class="px-4 py-2 text-center text-lg">${myIcon}
        <span class="text-xs text-gray-500 ml-1">${myPts > 0 ? "+" + myPts : myPts}</span>
      </td>
      <td class="px-4 py-2 text-center text-lg">${theirIcon}
        <span class="text-xs text-gray-500 ml-1">${theirPts > 0 ? "+" + theirPts : theirPts}</span>
      </td>
      <td class="px-4 py-2 text-right text-xs font-semibold ${myPts > theirPts ? "text-green-600" : myPts < theirPts ? "text-red-400" : "text-gray-400"}">
        ${myPts} – ${theirPts}
      </td>
      <td class="px-4 py-2 text-right font-bold text-indigo-700 text-sm">${this._myAcc}</td>
    `

    if (this.hasRoundsBodyTarget) this.roundsBodyTarget.prepend(row)

    // Fade in
    requestAnimationFrame(() => {
      row.style.transition = "opacity 0.3s ease"
      row.style.opacity    = "1"
    })
  }

  _finish() {
    if (this.hasSkipButtonTarget) {
      this.skipButtonTarget.classList.add("hidden")
    }
  }
}
