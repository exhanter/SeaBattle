//
//  HotSeatView.swift
//  SeaBattle
//
//  Phase 5a: the premium two-players-on-one-device (hot-seat) flow, presented
//  as a full-screen cover so it never touches the vs-computer battle UI. Screens
//  cover the phase machine in HotSeatGame: setup → secret placement (behind a
//  PIN handoff) → alternating fire (with a handoff whenever the turn passes).
//

import SwiftUI

private let seaGradient = LinearGradient(
    gradient: Gradient(colors: [Color(red: 0.11, green: 0.77, blue: 0.56).opacity(0.60),
                                Color(red: 0.04, green: 0.10, blue: 0.25).opacity(0.80)]),
    startPoint: .bottom, endPoint: .top)
private let accent = Color(red: 248/255, green: 255/255, blue: 0/255)

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
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding()
            }
        }
        .onAppear { game.soundOn = appState.soundOn }
    }
}

// MARK: - Setup

struct HotSeatSetupView: View {
    let game: HotSeatGame
    private var profiles = ProfileStore.shared

    @State private var name0 = ""
    @State private var pin0 = ""
    @State private var name1 = ""
    @State private var pin1 = ""

    init(game: HotSeatGame) { self.game = game }

    private var canStart: Bool {
        !name0.trimmingCharacters(in: .whitespaces).isEmpty
            && !name1.trimmingCharacters(in: .whitespaces).isEmpty
            && name0.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(name1.trimmingCharacters(in: .whitespaces)) != .orderedSame
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Two players")
                    .font(.custom("Dorsa", size: 60))
                    .foregroundStyle(accent)

                playerSlot(title: "Player 1", name: $name0, pin: $pin0)
                playerSlot(title: "Player 2", name: $name1, pin: $pin1)

                Button("Start") { game.begin(name0: name0, pin0: pin0, name1: name1, pin1: pin1) }
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

    private func playerSlot(title: LocalizedStringKey, name: Binding<String>, pin: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).foregroundColor(.white)
            TextField("Name", text: name)
                .textFieldStyle(.roundedBorder)
            SecureField("PIN (optional)", text: pin)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
            if !profiles.profiles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(profiles.profiles) { profile in
                            Button(profile.name) { name.wrappedValue = profile.name }
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

// MARK: - Handoff (privacy screen with optional PIN)

struct HotSeatHandoffView: View {
    enum Purpose { case arrange, shoot }
    let game: HotSeatGame
    let player: Int
    let purpose: Purpose

    @State private var pin = ""
    @State private var wrong = false

    private var needsPin: Bool { game.pinHashes[player] != nil }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 60))
                .foregroundStyle(accent)
            Text("Pass the device to")
                .foregroundColor(.white)
            Text(game.names[player])
                .font(.custom("Dorsa", size: 56))
                .foregroundStyle(accent)
            Text(purpose == .arrange ? "Time to place your fleet" : "Your turn to fire")
                .foregroundColor(.white.opacity(0.85))

            if needsPin {
                SecureField("Enter PIN", text: $pin)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 200)
                if wrong {
                    Text("Wrong PIN").foregroundColor(.red)
                }
            }

            Button(needsPin ? "Unlock" : "I'm ready") {
                if game.verify(player: player, pin: pin) {
                    unlock()
                } else {
                    wrong = true
                    pin = ""
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .foregroundStyle(.black)
        }
        .padding()
    }

    private func unlock() {
        switch purpose {
        case .arrange: game.unlockArrange(player: player)
        case .shoot: game.startShooting()
        }
    }
}

// MARK: - Secret placement

struct HotSeatArrangeView: View {
    let game: HotSeatGame
    let player: Int

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 16) {
                Text(game.names[player])
                    .font(.custom("Dorsa", size: 48))
                    .foregroundStyle(accent)
                Text("Your fleet — hidden from your opponent")
                    .foregroundColor(.white.opacity(0.85))
                HotSeatBoardGrid(board: game.boards[player], hideShips: false,
                                 cellWidth: min(geo.size.width, geo.size.height) * 0.075)
                HStack(spacing: 16) {
                    Button("Shuffle") { game.randomize(player: player) }
                        .buttonStyle(.bordered)
                        .tint(.white)
                    Button("Ready") { game.finishArrangement(player: player) }
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                        .foregroundStyle(.black)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }
}

// MARK: - Shooting

struct HotSeatShootingView: View {
    let game: HotSeatGame

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 16) {
                Text("\(game.names[game.attacker]) → \(game.names[game.defender])")
                    .font(.title2)
                    .foregroundStyle(accent)
                Text("Sunk: \(game.boards[game.defender].numberShipsDestroyed) / 10")
                    .foregroundColor(.white.opacity(0.85))
                HotSeatBoardGrid(board: game.boards[game.defender], hideShips: true,
                                 cellWidth: min(geo.size.width, geo.size.height) * 0.075) { row, col in
                    game.fire(row: row, column: col)
                }
                Text("Hit again to keep firing — a miss passes the device")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }
}

// MARK: - Result

struct HotSeatResultView: View {
    let game: HotSeatGame
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 70))
                .foregroundStyle(accent)
            Text("\(game.names[game.winner ?? 0]) wins!")
                .font(.custom("Dorsa", size: 60))
                .foregroundStyle(accent)
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

// MARK: - Board grid

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
                        CellView(fireStrokeIsOn: false, cellStatus: shown, cellWidth: cellWidth)
                            .onTapGesture { onTap?(row, column) }
                    }
                }
            }
        }
    }
}

#Preview {
    HotSeatContainerView()
        .environment(AppState())
}
