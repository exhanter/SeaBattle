# Sea Battle — Design Brief (for redesign)

> Purpose: give a designer (e.g. Claude) enough context to propose a modern, cohesive
> visual redesign. Pair this document with screenshots of the current build
> (see the checklist at the end).

## 1. What it is
A classic **Battleship (морской бой)** game for iOS. Single-player vs an AI opponent, plus
premium multiplayer modes. Built in SwiftUI. Bilingual (English / Russian / Dutch).
Casual, all-ages, offline-friendly.

## 2. Platforms & layouts
- **iPhone** (portrait only) and **iPad** (portrait **and** landscape — separate layouts).
- Must work from iPhone SE / 12-mini up to large iPads. Safe-area / notch / Dynamic Island aware.

## 3. Current visual language (what we're evolving)
- **Theme:** nautical, wooden, slightly skeuomorphic. Top and bottom bars are a
  **wood-plank texture**; background is a **sea gradient** (teal `#1CC48F`-ish at the
  bottom → deep navy `#0A1A40`-ish at the top).
- **Accents:** bright **yellow** `#F8FF00` (primary / titles / active),
  **cyan** `#66F0FF` (secondary / enemy).
- **Fonts:** `Dorsa` (tall decorative display font — titles, menu items, big numbers)
  and `Aldrich` (wide techy font — labels like "Opponent", "FIRE!").
- **Sound & music** throughout (nautical / battle).
- Tone today reads as "retro pirate". Open to a cleaner, more modern direction
  (the game mechanics / elements below must stay legible).

## 4. Core game board & cell states (the heart of the UI — keep it super readable)
- A **10×10 grid** of square cells. Two boards: **your fleet** and the **enemy board**.
- Fleet = **10 ships** (1×4-deck, 2×3-deck, 3×2-deck, 4×1-deck); ships never touch.
- **Cell states** to represent visually:
  - `unknown` (untouched water) — light-blue rounded tile with a subtle bevel.
  - `miss` — a crater / peg on water.
  - `ship` (own board only) — filled tile showing a ship segment.
  - `hit / on-fire` — an orange burning cross.
  - `sunk / destroyed` — dark tile.
  - transient **"fire stroke"** halo (orange glow) flashes ~0.3s on the targeted cell when a shot lands.
- **Hint marker** (premium): a yellow "target" reticle overlaid on a suggested cell.

## 5. Screen inventory
1. **Main menu** — app title "Sea Battle", a warship hero image, primary buttons
   **New game** and **Continue game** (Continue only if a save exists), and a **Settings**
   link. "New game" opens a chooser: *Play vs computer / Two players / Play online /
   Play nearby* (last three are premium).
2. **Settings** (sheet) — difficulty picker **Easy / Medium / Hard / Expert** (Expert =
   premium), sound & music toggles, a beginner "auto-reveal around sunk ships" toggle,
   **Statistics**, and **Go Premium / Premium active**.
3. **Fleet placement** — your 10×10 board; ships can be **shuffled**, or
   **dragged / long-press-rotated** manually. Actions: *Shuffle · Change/Save · Ready*.
4. **Battle** — the enemy board to fire at (tap a cell), a **"FIRE!"** cue, a **score
   readout at the top**, a persistent bottom **navigation bar** (Menu / Player / Enemy /
   About), and a **Hint** button for premium users. Switch between your board and the
   enemy board via the bottom bar.
5. **Score readout** — per side, "ships sunk out of 10". Currently shown as `N / 10` plus a
   **fleet tally** (a row of 10 marks; sunk = crossed-out in the side's colour, remaining =
   hollow). Player side = yellow, enemy side = cyan.
6. **Win / Defeat overlay** — result + **Play again** / **Menu**.
7. **Paywall** — auto-renewable **subscription** to unlock premium (Expert AI, Two players,
   online, nearby, hints). Needs price(s), Restore, Terms/Privacy links.
8. **Statistics** — wins by difficulty, losses, and a **points wallet** (points earned per
   win, spent on hints).
9. **Two players / hot-seat** (premium, single device) — *Setup* (two players enter
   **name**, pick an **avatar** = one of 10 SF-Symbol icons, pick an **avatar colour**,
   optional **PIN**), *Pass-the-device handoff* (big name + "Your turn to fire", optional
   PIN entry), *secret placement*, *shooting* (attacker fires; live scoreboard with fleet
   tallies; a "My fleet" peek), *Result* (winner + session win tally). Chrome: wooden top
   title bar + bottom bar with a persistent **Menu** item plus phase actions.
10. **Online / Nearby multiplayer** (premium) — a small lobby (Host / Join / discovered
    peers or Game Center matchmaking), then placement → battle → result, reusing the same
    board and chrome.

## 6. Reusable components to design a system around
- **Buttons:** currently a "wooden" 3D button style + plain yellow text links + a
  `Dorsa`-font bottom-menu item style.
- **Top bar** (title / score) and **bottom bar** (navigation or phase actions) as
  consistent chrome.
- **Board cell** (all states above) and the **10×10 grid**.
- **Avatar badge** (icon in a chosen colour on a translucent circle) + **avatar picker** +
  **colour picker**.
- **Fleet tally** (sunk-ships indicator).
- **Score chip**, **hint button**, **win/defeat card**, **paywall card**, **stat row**.

## 7. Hard constraints (please preserve)
- 10×10 grid readability and clear differentiation of the 6 cell states at small sizes
  (cells can be ~30–40pt on iPhone).
- Two distinct board contexts (mine vs enemy) must be visually distinguishable.
- Works in EN / RU / NL — **labels can be long**; avoid fixed-width text.
- iPad portrait & landscape variants.
- Nautical / battleship theme should remain recognizable (doesn't have to stay "wooden
  pirate", but should feel like sea / naval combat).

## 8. What we'd like from the redesign
A modern, cohesive visual system (colour palette, typography scale, button / chip
components, board styling) that keeps the game instantly readable and feels current on the
latest iOS — while honoring the nautical theme. Light / dark friendly a plus.

---

## Screenshot checklist (attach with this brief)
**iPhone (portrait):**
1. Main menu
2. "New game" mode chooser dialog
3. Settings
4. Fleet placement
5. Battle — own board
6. Battle — enemy board (with top score + bottom navigation)
7. Win / Defeat overlay
8. Paywall
9. Statistics
10. Hot-seat: setup / handoff / shooting / result

**iPad:** the same screens in **both portrait and landscape** (especially battle and
placement — those have their own layouts).
