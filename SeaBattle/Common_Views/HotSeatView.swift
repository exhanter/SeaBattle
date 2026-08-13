//
//  HotSeatView.swift
//  SeaBattle
//
//  Phase 5a: the premium two-players-on-one-device (hot-seat) flow, presented as
//  a full-screen cover so it never touches the vs-computer battle UI. Screens
//  follow HotSeatGame's phase machine: setup → secret placement (behind a PIN
//  handoff) → alternating fire (handoff on each miss) → result with the running
//  session score.
//

import SwiftUI

private let seaGradient = LinearGradient(
    gradient: Gradient(colors: [Color(red: 0.11, green: 0.77, blue: 0.56).opacity(0.60),
                                Color(red: 0.04, green: 0.10, blue: 0.25).opacity(0.80)]),
    startPoint: .bottom, endPoint: .top)
private let accent = Color(red: 248/255, green: 255/255, blue: 0/255)

private let avatarPalette: [Color] = [
    .yellow, .orange, .red, .pink, .green, .mint, .teal, .blue, .purple, .brown
]
private func avatarColor(_ symbol: String) -> Color {
    let index = HotSeatAvatars.symbols.firstIndex(of: symbol) ?? 0
    return avatarPalette[index % avatarPalette.count]
}

// MARK: - Container

struct HotSeatContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var game = HotSeatGame()

    var body: some View {
        ZStack {
            seaGradient.ignoresSafeArea()
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
                HotSeatResultView(game: game, onClose: { dismiss() })
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding()
            }
        }
        .onAppear {
            game.soundOn = appState.soundOn
            game.revealAroundSunk = appState.autoRevealAroundSunk
            appState.manualShipArrangement = false
        }
        .onDisappear {
            // Never leave manual-placement mode on for the vs-computer screens.
            appState.manualShipArrangement = false
        }
        .statusBar(hidden: true)
        .persistentSystemOverlays(.hidden)
    }
}

// MARK: - Reusable pieces

struct AvatarBadge: View {
    let symbol: String
    var size: CGFloat = 40
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.55))
            .foregroundStyle(avatarColor(symbol))
            .frame(width: size, height: size)
            .background(Circle().fill(.white.opacity(0.15)))
    }
}

struct AvatarPicker: View {
    @Binding var selection: String
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(HotSeatAvatars.symbols, id: \.self) { symbol in
                    Image(systemName: symbol)
                        .font(.title2)
                        .foregroundStyle(avatarColor(symbol))
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

/// A 4-digit PIN entry shown as large boxed, visible digits with a number pad.
/// Dismisses the keyboard automatically on the 4th digit and reports completion.
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
                        focused = false           // auto-hide the keyboard
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
    var onTap: ((Int, Int) -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            ForEach(1...10, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(1...10, id: \.self) { column in
                        let raw = board.cells[row - 1][column - 1].cellStatus
                        let shown: Cell.CurrentStatus = (hideShips && (raw == .showShip || raw == .showShipHalo)) ? .unknown : raw
                        CellView(fireStrokeIsOn: board.fireStrokeArray[row - 1][column - 1],
                                 cellStatus: shown, cellWidth: cellWidth)
                            .onTapGesture { onTap?(row, column) }
                    }
                }
            }
        }
    }
}

// MARK: - Setup

struct HotSeatSetupView: View {
    let game: HotSeatGame
    private var profiles = ProfileStore.shared

    @State private var name0 = ""
    @State private var pin0 = ""
    @State private var avatar0 = HotSeatAvatars.symbols[0]
    @State private var name1 = ""
    @State private var pin1 = ""
    @State private var avatar1 = HotSeatAvatars.symbols[1]

    init(game: HotSeatGame) { self.game = game }

    private var canStart: Bool {
        let n0 = name0.trimmingCharacters(in: .whitespaces)
        let n1 = name1.trimmingCharacters(in: .whitespaces)
        return !n0.isEmpty && !n1.isEmpty && n0.caseInsensitiveCompare(n1) != .orderedSame
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Two players")
                    .font(.custom("Dorsa", size: 60))
                    .foregroundStyle(accent)

                slot(title: "Player 1", name: $name0, pin: $pin0, avatar: $avatar0)
                slot(title: "Player 2", name: $name1, pin: $pin1, avatar: $avatar1)

                Button("Start") {
                    game.begin(name0: name0, avatar0: avatar0, pin0: pin0,
                               name1: name1, avatar1: avatar1, pin1: pin1)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .foregroundStyle(.black)
                .disabled(!canStart)
                .opacity(canStart ? 1 : 0.5)
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func slot(title: LocalizedStringKey, name: Binding<String>, pin: Binding<String>, avatar: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).foregroundColor(.white)
            TextField("Name", text: name)
                .textFieldStyle(.roundedBorder)
            AvatarPicker(selection: avatar)
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
                                    Image(systemName: profile.avatar).foregroundStyle(avatarColor(profile.avatar))
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
    let game: HotSeatGame
    let player: Int
    let purpose: Purpose

    @State private var pin = ""
    @State private var wrong = false

    private var needsPin: Bool { game.players[player].pinHash != nil }

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 50))
                .foregroundStyle(accent)
            Text("Pass the device to")
                .foregroundColor(.white)
            AvatarBadge(symbol: game.players[player].avatar, size: 64)
            Text(game.players[player].name)
                .font(.custom("Dorsa", size: 56))
                .foregroundStyle(accent)
            Text(purpose == .arrange ? "Time to place your fleet" : "Your turn to fire")
                .foregroundColor(.white.opacity(0.85))

            if needsPin {
                Text("Enter your PIN").foregroundColor(.white.opacity(0.85))
                PinBoxField(pin: $pin, autoFocus: true) { entered in
                    attempt(entered)   // auto-proceed once 4 digits are in
                }
                if wrong { Text("Wrong PIN").foregroundColor(.red) }
            } else {
                Button("I'm ready") { proceed() }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .foregroundStyle(.black)
            }
        }
        .padding()
    }

    private func attempt(_ pin: String) {
        if game.verify(player: player, pin: pin) {
            proceed()
        } else {
            wrong = true
            self.pin = ""
        }
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
    let game: HotSeatGame
    let player: Int
    @State private var topLeft: CGPoint = .zero

    private var isDragging: Bool { game.boards[player].shipIsDragging.contains(true) }

    var body: some View {
        GeometryReader { geo in
            let cell = min(geo.size.width, geo.size.height) * 0.09
            ZStack {
                VStack(spacing: 12) {
                    HStack {
                        AvatarBadge(symbol: game.players[player].avatar, size: 40)
                        Text(game.players[player].name)
                            .font(.custom("Dorsa", size: 44))
                            .foregroundStyle(accent)
                    }
                    Text(appState.manualShipArrangement
                         ? "Drag to move · long-press to rotate"
                         : "Your fleet — hidden from your opponent")
                        .foregroundColor(.white.opacity(0.85))

                    VStack(spacing: 0) {
                        PlayerSquareView(player: game.boards[player],
                                         leftTopPointOfGameField: $topLeft,
                                         width: cell)
                    }

                    HStack(spacing: 14) {
                        Button("Shuffle") { game.randomize(player: player) }
                            .buttonStyle(.bordered)
                            .tint(.white)
                            .disabled(appState.manualShipArrangement)
                        Button(appState.manualShipArrangement ? "Save" : "Change") {
                            if appState.soundOn { AppState.playSound(sound: "click_sound.wav") }
                            appState.manualShipArrangement.toggle()
                        }
                        .buttonStyle(.bordered)
                        .tint(accent)
                        .disabled(isDragging)
                        Button("Ready") { game.finishArrangement(player: player) }
                            .buttonStyle(.borderedProminent)
                            .tint(accent)
                            .foregroundStyle(.black)
                            .disabled(appState.manualShipArrangement || isDragging)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Draggable ship overlay (same component as the vs-computer game).
                if appState.manualShipArrangement {
                    ShipReplacementView(leftTopPointOfGameField: topLeft, cellSize: cell, player: game.boards[player])
                }
            }
        }
    }
}

// MARK: - Shooting

struct HotSeatShootingView: View {
    let game: HotSeatGame
    @State private var showingOwnBoard = false
    @State private var busy = false

    var body: some View {
        GeometryReader { geo in
            let cell = min(geo.size.width, geo.size.height) * 0.09
            VStack(spacing: 12) {
                HStack {
                    AvatarBadge(symbol: game.players[game.attacker].avatar, size: 40)
                    Text(game.players[game.attacker].name)
                        .font(.custom("Dorsa", size: 44))
                        .foregroundStyle(accent)
                }

                // Live scoreboard so players can compare progress.
                HStack(spacing: 20) {
                    scoreTag(name: game.players[game.attacker].name,
                             sunk: game.boards[game.defender].numberShipsDestroyed)
                    scoreTag(name: game.players[game.defender].name,
                             sunk: game.boards[game.attacker].numberShipsDestroyed)
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

                Button {
                    showingOwnBoard.toggle()
                } label: {
                    Label(showingOwnBoard ? "Back to attack" : "Show my fleet",
                          systemImage: showingOwnBoard ? "scope" : "shield.lefthalf.filled")
                }
                .buttonStyle(.bordered)
                .tint(.white)

                Text("Hit again to keep firing — a miss passes the device")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }

    /// Plays the shot animation (fire-stroke flash), then drives the turn/match
    /// transition after a short delay so the result is visible — mirrors the
    /// vs-computer timing.
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

    private func scoreTag(name: String, sunk: Int) -> some View {
        VStack {
            Text(name).lineLimit(1)
            Text("\(sunk) / 10").bold().foregroundColor(accent)
        }
    }
}

// MARK: - Result

struct HotSeatResultView: View {
    let game: HotSeatGame
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 60))
                .foregroundStyle(accent)
            if let winner = game.winner {
                HStack {
                    AvatarBadge(symbol: game.players[winner].avatar, size: 50)
                    Text("\(game.players[winner].name) wins!")
                        .font(.custom("Dorsa", size: 52))
                        .foregroundStyle(accent)
                }
            }

            // Running session score.
            VStack(spacing: 8) {
                Text("This session").foregroundColor(.white.opacity(0.8))
                HStack(spacing: 28) {
                    ForEach(0..<2, id: \.self) { i in
                        VStack {
                            AvatarBadge(symbol: game.players[i].avatar, size: 44)
                            Text(game.players[i].name).foregroundColor(.white).lineLimit(1)
                            Text("\(game.players[i].sessionWins)")
                                .font(.title).bold()
                                .foregroundColor(accent)
                        }
                    }
                }
            }
            .padding()
            .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 14))

            HStack(spacing: 16) {
                Button("Play again") { game.restart() }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .foregroundStyle(.black)
                Button("Done") { onClose() }
                    .buttonStyle(.bordered)
                    .tint(.white)
            }
        }
        .padding()
    }
}

#Preview {
    HotSeatContainerView()
        .environment(AppState())
}
