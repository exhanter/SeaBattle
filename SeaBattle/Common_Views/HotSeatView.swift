//
//  HotSeatView.swift
//  SeaBattle
//
//  Phase 5a: the premium two-players-on-one-device (hot-seat) flow. Wrapped in
//  the app's wooden chrome (top title bar + bottom menu bar over the sea
//  gradient) so it matches the vs-computer screens. Follows HotSeatGame's phase
//  machine: setup → secret placement (PIN handoff) → alternating fire (handoff
//  on each miss) → result with the running session score.
//

import SwiftUI

private let seaGradient = LinearGradient(
    gradient: Gradient(colors: [Color(red: 0.11, green: 0.77, blue: 0.56).opacity(0.60),
                                Color(red: 0.04, green: 0.10, blue: 0.25).opacity(0.80)]),
    startPoint: .bottom, endPoint: .top)
private let accent = Color(red: 248/255, green: 255/255, blue: 0/255)

/// Colours a player can pick for their avatar. The avatar SYMBOL is always shown
/// in a neutral tint in the pickers; the chosen colour only appears on the badge
/// next to the player's name.
private let avatarPalette: [Color] = [
    .yellow, .orange, .red, .pink, .green, .mint, .teal, .blue, .purple, .brown
]
private let avatarTint = Color(red: 102/255, green: 240/255, blue: 255/255) // interface teal
private func paletteColor(_ index: Int) -> Color { avatarPalette[index % avatarPalette.count] }

// MARK: - Wooden chrome

/// Shared wooden frame: a top bar with the screen title and a bottom "menu" bar
/// with a persistent "Menu" item (exit to the app's main menu) on the left plus
/// the screen's phase actions on the right — matching the vs-computer chrome.
struct HotSeatChrome<Content: View, Bar: View>: View {
    let title: LocalizedStringKey
    /// Legacy top-right close (X) — used by the network screens. Hot-seat screens
    /// instead put a persistent "Menu" item in their own bottom bar.
    var onClose: (() -> Void)?
    @ViewBuilder var content: (CGSize) -> Content
    @ViewBuilder var bottomBar: (CGSize) -> Bar

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Opaque base: the sea gradient is translucent (matches the
                // vs-computer look over the black window), so without this the
                // presenting menu shows through the fullScreenCover.
                Color.black.ignoresSafeArea()
                seaGradient.ignoresSafeArea()
                VStack(spacing: 0) {
                    ZStack(alignment: .top) {
                        // Wood fills under the notch/Dynamic Island; the title is
                        // pinned just below the safe-area top so it sits high and
                        // wastes no space (rather than floating far below).
                        Image("wood").resizable().renderingMode(.original)
                            .frame(height: geo.safeAreaInsets.top + geo.size.height * 0.085)
                        Text(title)
                            .font(.custom("Dorsa", size: geo.size.width * 0.16))
                            .foregroundColor(accent)
                            .shadow(color: .white, radius: 1)
                            .padding(.top, geo.safeAreaInsets.top)
                    }
                    .overlay(alignment: .topTrailing) {
                        if let onClose {
                            Button(action: onClose) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(accent)
                            }
                            .padding(.trailing, 16)
                            .padding(.top, geo.safeAreaInsets.top + 4)
                        }
                    }
                    Spacer(minLength: 0)
                    content(geo.size)
                    Spacer(minLength: 0)
                    ZStack {
                        Image("wood").resizable().renderingMode(.original)
                            .frame(height: geo.size.height * 0.14)
                        bottomBar(geo.size)
                    }
                }
                .ignoresSafeArea()
            }
        }
    }
}

/// A hot-seat bottom bar: a persistent "Menu" item pinned to the leading edge
/// (exit to the app's main menu) plus a single, SCREEN-centred action.
private func centeredMenuBar<Center: View>(width: CGFloat, onMenu: @escaping () -> Void,
                                           @ViewBuilder center: () -> Center) -> some View {
    ZStack {
        center() // centred in the full width, unaffected by the Menu item
        HStack {
            menuButton("Menu", width: width, action: onMenu)
                .padding(.leading, width * 0.06)
            Spacer()
        }
    }
}

/// A Dorsa-font text button, matching the app's bottom menu.
private func menuButton(_ title: LocalizedStringKey, width: CGFloat, enabled: Bool = true, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.custom("Dorsa", size: width * 0.13))
            .foregroundColor(accent)
            .shadow(color: .white, radius: 1)
            .fixedSize(horizontal: true, vertical: true)
    }
    .disabled(!enabled)
    .opacity(enabled ? 1 : 0.4)
}

// MARK: - Container

struct HotSeatContainerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var game = HotSeatGame()
    @State private var showResume = HotSeatStore.hasSession

    var body: some View {
        Group {
            if showResume {
                resumeChooser
            } else {
                phaseView
            }
        }
        .onAppear {
            game.soundOn = appState.soundOn
            game.revealAroundSunk = appState.autoRevealAroundSunk
            appState.manualShipArrangement = false
        }
        .onDisappear { appState.manualShipArrangement = false }
        .statusBar(hidden: true)
        .persistentSystemOverlays(.hidden)
    }

    @ViewBuilder private var phaseView: some View {
        switch game.phase {
        case .setup:
            HotSeatSetupView(game: game)
        case .arrangeHandoff(let player):
            HotSeatHandoffView(game: game, player: player, purpose: .arrange)
        case .arrange(let player):
            HotSeatArrangeView(game: game, player: player)
        case .turnHandoff(let player):
            HotSeatHandoffView(game: game, player: player, purpose: .shoot)
        case .shooting:
            HotSeatShootingView(game: game)
        case .finished:
            HotSeatResultView(game: game)
        }
    }

    private var resumeChooser: some View {
        HotSeatChrome(title: "Two players") { _ in
            VStack(spacing: 16) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 56)).foregroundStyle(accent)
                Text("You have a game in progress.").foregroundColor(.white)
                if let s = HotSeatStore.load(), s.players.count == 2 {
                    HStack(spacing: 24) {
                        ForEach(0..<2, id: \.self) { i in
                            VStack {
                                AvatarBadge(symbol: s.players[i].avatar, size: 44, color: paletteColor(s.players[i].colorIndex))
                                Text(s.players[i].name).foregroundColor(.white).lineLimit(1)
                                Text("\(s.players[i].sessionWins)").font(.title2).bold().foregroundColor(accent)
                            }
                        }
                    }
                }
            }
        } bottomBar: { size in
            HStack {
                Spacer()
                menuButton("Menu", width: size.width) { dismiss() }
                Spacer()
                menuButton("Continue", width: size.width) {
                    if let s = HotSeatStore.load() { game.restore(from: s) }
                    showResume = false
                }
                Spacer()
                menuButton("New", width: size.width) {
                    HotSeatStore.clear()
                    showResume = false
                }
                Spacer()
                menuButton("Delete", width: size.width) {
                    HotSeatStore.clear()
                    dismiss()
                }
                Spacer()
            }
        }
    }
}

// MARK: - Reusable pieces

struct AvatarBadge: View {
    let symbol: String
    var size: CGFloat = 40
    var color: Color = avatarTint
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.55))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(Circle().fill(.white.opacity(0.15)))
    }
}

/// Picks the avatar SYMBOL. All symbols are shown in one neutral tint — the
/// colour is chosen separately (see AvatarColorPicker).
struct AvatarPicker: View {
    @Binding var selection: String
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(HotSeatAvatars.symbols, id: \.self) { symbol in
                    Image(systemName: symbol)
                        .font(.title2)
                        .foregroundStyle(avatarTint)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(selection == symbol ? .white.opacity(0.3) : .white.opacity(0.08)))
                        .overlay(Circle().stroke(selection == symbol ? accent : .clear, lineWidth: 2))
                        .onTapGesture { selection = symbol }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

/// Picks the avatar COLOUR (a swatch row); the chosen colour is shown on the
/// badge next to the player's name.
struct AvatarColorPicker: View {
    @Binding var selection: Int
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(avatarPalette.indices, id: \.self) { index in
                    Circle()
                        .fill(avatarPalette[index])
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(selection == index ? .white : .clear, lineWidth: 2.5))
                        .onTapGesture { selection = index }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

/// A visual tally of an opponent's fleet: `total` marks, the first `sunk` shown
/// crossed-out in `color` (destroyed), the rest hollow (still afloat) — so it's
/// clear the number means ships SUNK, not ships remaining. `perRow` wraps the
/// marks into rows (e.g. 5 → a compact 5×2 grid for the narrow iPad columns).
struct FleetTally: View {
    let sunk: Int
    var total: Int = 10
    var color: Color
    var markSize: CGFloat = 13
    var perRow: Int = 10

    var body: some View {
        let rowCount = Int(ceil(Double(total) / Double(perRow)))
        VStack(spacing: markSize * 0.2) {
            ForEach(0..<rowCount, id: \.self) { row in
                HStack(spacing: markSize * 0.2) {
                    ForEach(0..<perRow, id: \.self) { column in
                        let index = row * perRow + column
                        if index < total {
                            Image(systemName: index < sunk ? "xmark.circle.fill" : "circle")
                                .font(.system(size: markSize))
                                .foregroundStyle(index < sunk ? color : color.opacity(0.3))
                        }
                    }
                }
            }
        }
    }
}

/// A 4-digit PIN entry: large boxed, visible digits with a number pad.
/// Auto-hides the keyboard on the 4th digit and reports completion.
struct PinBoxField: View {
    @Binding var pin: String
    var autoFocus: Bool = false
    var onComplete: ((String) -> Void)? = nil
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            TextField("", text: $pin)
                .keyboardType(.numberPad)
                .focused($focused)
                .foregroundColor(.clear)
                .tint(.clear)
                .opacity(0.02)
                .onChange(of: pin) { _, value in
                    let cleaned = String(value.filter(\.isNumber).prefix(4))
                    if cleaned != value { pin = cleaned }
                    if cleaned.count == 4 {
                        focused = false
                        onComplete?(cleaned)
                    }
                }
            HStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { index in
                    let chars = Array(pin)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.12))
                        .frame(width: 46, height: 58)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(focused ? accent : .white.opacity(0.4), lineWidth: 1.5))
                        .overlay(
                            Text(index < chars.count ? String(chars[index]) : "")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        )
                }
            }
            .allowsHitTesting(false)
        }
        .frame(height: 58)
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .onAppear { if autoFocus { focused = true } }
    }
}

struct HotSeatBoardGrid: View {
    let board: PlayerData
    let hideShips: Bool
    let cellWidth: CGFloat
    var hintedCells: Set<Coordinate> = []
    var onTap: ((Int, Int) -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            ForEach(1...10, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(1...10, id: \.self) { column in
                        let raw = board.cells[row - 1][column - 1].cellStatus
                        let shown: Cell.CurrentStatus = (hideShips && (raw == .showShip || raw == .showShipHalo)) ? .unknown : raw
                        // A Button with NoPressEffect (same as the vs-computer
                        // EnemySquareView) so taps register immediately — an
                        // .onTapGesture here felt laggier / less smooth.
                        Button {
                            onTap?(row, column)
                        } label: {
                            CellView(fireStrokeIsOn: board.fireStrokeArray[row - 1][column - 1],
                                     cellStatus: shown, cellWidth: cellWidth)
                                .overlay {
                                    if shown == .unknown && hintedCells.contains(Coordinate(row: row, column: column)) {
                                        let hintNudge = cellWidth * 0.025
                                        Image(systemName: "target")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: cellWidth * 0.6, height: cellWidth * 0.6)
                                            .foregroundStyle(Color(red: 248/255, green: 1, blue: 0))
                                            .shadow(color: .black, radius: 1)
                                            .offset(x: -hintNudge, y: -hintNudge)
                                    }
                                }
                        }
                        .buttonStyle(NoPressEffect())
                        .disabled(onTap == nil)
                    }
                }
            }
        }
    }
}

// MARK: - Setup

struct HotSeatSetupView: View {
    @Environment(\.dismiss) private var dismiss
    let game: HotSeatGame
    private var profiles = ProfileStore.shared

    @State private var name0 = ""
    @State private var pin0 = ""
    @State private var avatar0 = HotSeatAvatars.symbols[0]
    @State private var color0 = 0
    @State private var name1 = ""
    @State private var pin1 = ""
    @State private var avatar1 = HotSeatAvatars.symbols[1]
    @State private var color1 = 1

    init(game: HotSeatGame) { self.game = game }

    private var canStart: Bool {
        let n0 = name0.trimmingCharacters(in: .whitespaces)
        let n1 = name1.trimmingCharacters(in: .whitespaces)
        // Blank names default to "Player 1" / "Player 2", so allow starting;
        // only block when both names are typed and identical.
        guard !n0.isEmpty, !n1.isEmpty else { return true }
        return n0.caseInsensitiveCompare(n1) != .orderedSame
    }

    var body: some View {
        HotSeatChrome(title: "Two players") { _ in
            ScrollView {
                VStack(spacing: 16) {
                    slot(title: "Player 1", name: $name0, pin: $pin0, avatar: $avatar0, colorIndex: $color0)
                    slot(title: "Player 2", name: $name1, pin: $pin1, avatar: $avatar1, colorIndex: $color1)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.interactively)
        } bottomBar: { size in
            centeredMenuBar(width: size.width, onMenu: { dismiss() }) {
                menuButton("Start", width: size.width, enabled: canStart) {
                    game.begin(name0: name0, avatar0: avatar0, color0: color0, pin0: pin0,
                               name1: name1, avatar1: avatar1, color1: color1, pin1: pin1)
                }
            }
        }
    }

    private func slot(title: LocalizedStringKey, name: Binding<String>, pin: Binding<String>,
                      avatar: Binding<String>, colorIndex: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline).foregroundColor(.white)
                Spacer()
                // Live preview: the chosen symbol in the chosen colour.
                AvatarBadge(symbol: avatar.wrappedValue, size: 40, color: paletteColor(colorIndex.wrappedValue))
            }
            TextField("Name", text: name).textFieldStyle(.roundedBorder)
            AvatarPicker(selection: avatar)
            AvatarColorPicker(selection: colorIndex)
            Text("PIN (optional)").font(.caption).foregroundColor(.white.opacity(0.8))
            PinBoxField(pin: pin)
            if !profiles.profiles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(profiles.profiles) { profile in
                            Button {
                                name.wrappedValue = profile.name
                                avatar.wrappedValue = profile.avatar
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: profile.avatar).foregroundStyle(avatarTint)
                                    Text(profile.name)
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(.white)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Handoff

struct HotSeatHandoffView: View {
    enum Purpose { case arrange, shoot }
    @Environment(\.dismiss) private var dismiss
    let game: HotSeatGame
    let player: Int
    let purpose: Purpose

    @State private var pin = ""
    @State private var wrong = false

    private var needsPin: Bool { game.players[player].pinHash != nil }

    var body: some View {
        HotSeatChrome(title: "Pass the device") { size in
            VStack(spacing: 18) {
                AvatarBadge(symbol: game.players[player].avatar, size: 80,
                            color: paletteColor(game.players[player].colorIndex))
                Text(game.players[player].name)
                    .font(.custom("Dorsa", size: size.width * 0.19))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(purpose == .arrange ? "Time to place your fleet" : "Your turn to fire")
                    .font(.custom("Aldrich", size: size.width * 0.06))
                    .foregroundColor(.white.opacity(0.85))
                if needsPin {
                    Text("Enter your PIN").foregroundColor(.white.opacity(0.85))
                    PinBoxField(pin: $pin, autoFocus: true) { entered in attempt(entered) }
                    if wrong { Text("Wrong PIN").foregroundColor(.red) }
                }
            }
            .padding(.horizontal, 20)
        } bottomBar: { size in
            centeredMenuBar(width: size.width, onMenu: { dismiss() }) {
                if needsPin {
                    Text("Enter PIN to continue")
                        .font(.custom("Dorsa", size: size.width * 0.07))
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    menuButton("I'm ready", width: size.width) { proceed() }
                }
            }
        }
    }

    private func attempt(_ pin: String) {
        if game.verify(player: player, pin: pin) { proceed() }
        else { wrong = true; self.pin = "" }
    }

    private func proceed() {
        switch purpose {
        case .arrange: game.unlockArrange(player: player)
        case .shoot: game.startShooting()
        }
    }
}

// MARK: - Secret placement

struct HotSeatArrangeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let game: HotSeatGame
    let player: Int
    @State private var topLeft: CGPoint = .zero

    private var isDragging: Bool { game.boards[player].shipIsDragging.contains(true) }

    var body: some View {
        GeometryReader { geo in
            let cell = min(geo.size.width, geo.size.height) * 0.09
            ZStack {
                HotSeatChrome(title: "\(game.players[player].name)") { _ in
                    VStack(spacing: 10) {
                        Text(appState.manualShipArrangement
                             ? "Drag to move · long-press to rotate"
                             : "Your fleet — hidden from your opponent")
                            .foregroundColor(.white.opacity(0.85))
                        VStack(spacing: 0) {
                            PlayerSquareView(player: game.boards[player],
                                             leftTopPointOfGameField: $topLeft,
                                             width: cell)
                        }
                    }
                } bottomBar: { size in
                    HStack {
                        Spacer()
                        menuButton("Menu", width: size.width) { dismiss() }
                        Spacer()
                        menuButton("Shuffle", width: size.width, enabled: !appState.manualShipArrangement) {
                            game.randomize(player: player)
                        }
                        Spacer()
                        menuButton(appState.manualShipArrangement ? "Save" : "Change", width: size.width, enabled: !isDragging) {
                            if appState.soundOn { AppState.playSound(sound: "click_sound.wav") }
                            appState.manualShipArrangement.toggle()
                        }
                        Spacer()
                        menuButton("Ready", width: size.width, enabled: !appState.manualShipArrangement && !isDragging) {
                            game.finishArrangement(player: player)
                        }
                        Spacer()
                    }
                }

                if appState.manualShipArrangement {
                    ShipReplacementView(leftTopPointOfGameField: topLeft, cellSize: cell, player: game.boards[player])
                        .ignoresSafeArea()
                }
            }
        }
    }
}

// MARK: - Shooting

struct HotSeatShootingView: View {
    @Environment(\.dismiss) private var dismiss
    let game: HotSeatGame
    @State private var showingOwnBoard = false
    @State private var busy = false

    var body: some View {
        HotSeatChrome(title: "\(game.players[game.attacker].name)") { size in
            let cell = min(size.width, size.height) * 0.09
            VStack(spacing: 12) {
                HStack(spacing: 20) {
                    scoreTag(name: game.players[game.attacker].name,
                             sunk: game.boards[game.defender].numberShipsDestroyed,
                             color: paletteColor(game.players[game.attacker].colorIndex))
                    scoreTag(name: game.players[game.defender].name,
                             sunk: game.boards[game.attacker].numberShipsDestroyed,
                             color: paletteColor(game.players[game.defender].colorIndex))
                }
                .font(.subheadline)
                .foregroundColor(.white)

                if showingOwnBoard {
                    Text("Your fleet (incoming fire)").foregroundColor(.white.opacity(0.85))
                    HotSeatBoardGrid(board: game.boards[game.attacker], hideShips: false, cellWidth: cell)
                } else {
                    Text("Fire at \(game.players[game.defender].name)").foregroundColor(.white.opacity(0.85))
                    HotSeatBoardGrid(board: game.boards[game.defender], hideShips: true, cellWidth: cell) { row, col in
                        fire(row: row, column: col)
                    }
                }
            }
        } bottomBar: { size in
            centeredMenuBar(width: size.width, onMenu: { dismiss() }) {
                menuButton(showingOwnBoard ? "Attack" : "My fleet", width: size.width) {
                    showingOwnBoard.toggle()
                }
            }
        }
    }

    /// Fire-stroke flash + delayed transition, mirroring the vs-computer timing.
    private func fire(row: Int, column: Int) {
        guard !busy, game.canFire(row: row, column: column) else { return }
        busy = true
        let target = game.defender
        game.boards[target].fireStrokeArray[row - 1][column - 1] = true
        let result = game.fire(row: row, column: column)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.3))
            game.boards[target].fireStrokeArray[row - 1][column - 1] = false
            switch result {
            case .missed?:
                try? await Task.sleep(for: .seconds(0.8))
                game.passTurn()
            case .win?:
                try? await Task.sleep(for: .seconds(1.0))
                game.finishMatch()
            default:
                break
            }
            busy = false
        }
    }

    private func scoreTag(name: String, sunk: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(name).lineLimit(1)
            FleetTally(sunk: sunk, color: color, markSize: 11)
        }
    }
}

// MARK: - Result

struct HotSeatResultView: View {
    @Environment(\.dismiss) private var dismiss
    let game: HotSeatGame

    var body: some View {
        HotSeatChrome(title: "Result") { _ in
            VStack(spacing: 18) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(accent)
                if let winner = game.winner {
                    HStack {
                        AvatarBadge(symbol: game.players[winner].avatar, size: 50, color: paletteColor(game.players[winner].colorIndex))
                        Text("\(game.players[winner].name) wins!")
                            .font(.custom("Dorsa", size: 48))
                            .foregroundStyle(accent)
                    }
                }
                VStack(spacing: 8) {
                    Text("This session").foregroundColor(.white.opacity(0.8))
                    HStack(spacing: 28) {
                        ForEach(0..<2, id: \.self) { i in
                            VStack {
                                AvatarBadge(symbol: game.players[i].avatar, size: 44, color: paletteColor(game.players[i].colorIndex))
                                Text(game.players[i].name).foregroundColor(.white).lineLimit(1)
                                Text("\(game.players[i].sessionWins)")
                                    .font(.title).bold().foregroundColor(accent)
                            }
                        }
                    }
                }
                .padding()
                .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 14))
            }
        } bottomBar: { size in
            HStack {
                Spacer()
                menuButton("Menu", width: size.width) { dismiss() }
                Spacer()
                menuButton("Play again", width: size.width) { game.restart() }
                Spacer()
                menuButton("Done", width: size.width) {
                    HotSeatStore.clear() // Done ends the session
                    dismiss()
                }
                Spacer()
            }
        }
    }
}

#Preview {
    HotSeatContainerView()
        .environment(AppState())
}
