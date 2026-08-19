//
//  NetworkGameView.swift
//  SeaBattle
//
//  Phase 5: UI for nearby (MultipeerConnectivity) networked play. A small lobby
//  (host / join + discovered peers), then the battle driven by NetworkGame,
//  reusing the wooden chrome, board grids and manual-placement components.
//

import SwiftUI
import MultipeerConnectivity

private let netAccent = Color(red: 248/255, green: 255/255, blue: 0/255)

private func netMenuButton(_ title: LocalizedStringKey, width: CGFloat, enabled: Bool = true, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.custom("Dorsa", size: width * 0.13))
            .foregroundColor(netAccent)
            .shadow(color: .white, radius: 1)
            .fixedSize(horizontal: true, vertical: true)
    }
    .disabled(!enabled)
    .opacity(enabled ? 1 : 0.4)
}

// MARK: - Lobby container

struct NearbyGameView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private enum Step { case setup, hosting, browsing, playing }
    @State private var step: Step = .setup
    @State private var name = ProfileStore.shared.profiles.first?.name ?? ""
    @State private var avatar = ProfileStore.shared.profiles.first?.avatar ?? HotSeatAvatars.symbols[0]
    @State private var transport: MultipeerTransport?
    @State private var game: NetworkGame?

    var body: some View {
        Group {
            switch step {
            case .setup:
                setupView
            case .hosting:
                waiting("Waiting for a nearby player…")
            case .browsing:
                browsingView
            case .playing:
                if let game { NetworkBattleView(game: game, onExit: leave) }
            }
        }
        .statusBar(hidden: true)
        .persistentSystemOverlays(.hidden)
        .onDisappear { appState.manualShipArrangement = false }
    }

    private var canStart: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    private var setupView: some View {
        HotSeatChrome(title: "Play nearby", onClose: leave) { _ in
            VStack(spacing: 14) {
                Text("You")
                    .font(.headline).foregroundColor(.white)
                TextField("Your name", text: $name).textFieldStyle(.roundedBorder).padding(.horizontal, 40)
                AvatarPicker(selection: $avatar).padding(.horizontal, 20)
                Text("Host a game, or join one nearby.")
                    .foregroundColor(.white.opacity(0.8))
            }
        } bottomBar: { size in
            HStack {
                Spacer()
                netMenuButton("Host", width: size.width, enabled: canStart) { host() }
                Spacer()
                netMenuButton("Join", width: size.width, enabled: canStart) { join() }
                Spacer()
            }
        }
    }

    private func waiting(_ text: LocalizedStringKey) -> some View {
        HotSeatChrome(title: "Play nearby", onClose: leave) { _ in
            VStack(spacing: 18) {
                ProgressView().tint(.white)
                Text(text).foregroundColor(.white)
            }
        } bottomBar: { size in
            netMenuButton("Cancel", width: size.width) { leave() }
        }
    }

    private var browsingView: some View {
        HotSeatChrome(title: "Nearby games", onClose: leave) { _ in
            VStack(spacing: 12) {
                if let transport, transport.discoveredPeers.isEmpty {
                    ProgressView().tint(.white)
                    Text("Searching for hosts…").foregroundColor(.white.opacity(0.85))
                } else if let transport {
                    ForEach(transport.discoveredPeers, id: \.self) { peer in
                        Button {
                            transport.invite(peer)
                        } label: {
                            Label(peer.displayName, systemImage: "dot.radiowaves.left.and.right")
                                .foregroundColor(netAccent)
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                    }
                }
            }
        } bottomBar: { size in
            netMenuButton("Cancel", width: size.width) { leave() }
        }
    }

    // MARK: - Actions

    private func host() {
        let t = MultipeerTransport(displayName: name)
        t.onConnectionChange = { connected in if connected { beginGame(isHost: true) } }
        t.startHosting()
        transport = t
        step = .hosting
    }

    private func join() {
        let t = MultipeerTransport(displayName: name)
        t.onConnectionChange = { connected in if connected { beginGame(isHost: false) } }
        t.startBrowsing()
        transport = t
        step = .browsing
    }

    private func beginGame(isHost: Bool) {
        guard let transport, game == nil else { return }
        let g = NetworkGame(transport: transport, name: name, avatar: avatar,
                            accountID: AccountID.current(), isHost: isHost)
        g.soundOn = appState.soundOn
        g.start()
        game = g
        step = .playing
    }

    private func leave() {
        transport?.disconnect()
        appState.manualShipArrangement = false
        dismiss()
    }
}

// MARK: - Battle

struct NetworkBattleView: View {
    @Environment(AppState.self) private var appState
    let game: NetworkGame
    let onExit: () -> Void

    @State private var topLeft: CGPoint = .zero
    @State private var showingOwnBoard = false

    private var isDragging: Bool { game.own.shipIsDragging.contains(true) }

    var body: some View {
        switch game.phase {
        case .placing:
            placing
        case .waitingForOpponent:
            HotSeatChrome(title: "Play nearby", onClose: onExit) { _ in
                VStack(spacing: 16) {
                    ProgressView().tint(.white)
                    Text("Waiting for \(game.opponentName) to place ships…")
                        .foregroundColor(.white.opacity(0.85))
                }
            } bottomBar: { _ in EmptyView() }
        case .myTurn, .theirTurn:
            battle
        case .finished:
            result
        }
    }

    private var placing: some View {
        GeometryReader { geo in
            let cell = min(geo.size.width, geo.size.height) * 0.09
            ZStack {
                HotSeatChrome(title: "\(game.localName)", onClose: onExit) { _ in
                    VStack(spacing: 10) {
                        Text(appState.manualShipArrangement
                             ? "Drag to move · long-press to rotate"
                             : "Place your fleet")
                            .foregroundColor(.white.opacity(0.85))
                        VStack(spacing: 0) {
                            PlayerSquareView(player: game.own, leftTopPointOfGameField: $topLeft, width: cell)
                        }
                    }
                } bottomBar: { size in
                    HStack {
                        Spacer()
                        netMenuButton("Shuffle", width: size.width, enabled: !appState.manualShipArrangement) {
                            game.randomize()
                        }
                        Spacer()
                        netMenuButton(appState.manualShipArrangement ? "Save" : "Change", width: size.width, enabled: !isDragging) {
                            if appState.soundOn { AppState.playSound(sound: "click_sound.wav") }
                            appState.manualShipArrangement.toggle()
                        }
                        Spacer()
                        netMenuButton("Ready", width: size.width, enabled: !appState.manualShipArrangement && !isDragging) {
                            game.confirmReady()
                        }
                        Spacer()
                    }
                }
                if appState.manualShipArrangement {
                    ShipReplacementView(leftTopPointOfGameField: topLeft, cellSize: cell, player: game.own)
                        .ignoresSafeArea()
                }
            }
        }
    }

    private var battle: some View {
        let myTurn = game.phase == .myTurn
        return HotSeatChrome(title: myTurn ? "Your turn" : "\(game.opponentName)'s turn", onClose: onExit) { size in
            let cell = min(size.width, size.height) * 0.09
            VStack(spacing: 12) {
                HStack(spacing: 20) {
                    scoreTag(name: game.localName, sunk: game.opponentShipsSunk)
                    scoreTag(name: game.opponentName, sunk: game.own.numberShipsDestroyed)
                }
                .font(.subheadline).foregroundColor(.white)

                if showingOwnBoard || !myTurn {
                    Text(myTurn ? "Your fleet" : "Incoming fire").foregroundColor(.white.opacity(0.85))
                    HotSeatBoardGrid(board: game.own, hideShips: false, cellWidth: cell)
                } else {
                    Text("Fire at \(game.opponentName)").foregroundColor(.white.opacity(0.85))
                    HotSeatBoardGrid(board: game.tracking, hideShips: true, cellWidth: cell,
                                     hintedCells: Set(game.revealedHints)) { row, col in
                        fire(row: row, column: col)
                    }
                }
            }
        } bottomBar: { size in
            HStack {
                Spacer()
                netMenuButton(showingOwnBoard ? "Attack" : "My fleet", width: size.width, enabled: myTurn) {
                    showingOwnBoard.toggle()
                }
                if myTurn && !game.isSameAccount {
                    Spacer()
                    netMenuButton("Hint (\(game.hintCost))", width: size.width, enabled: game.canUseHint) {
                        game.useHint()
                    }
                }
                Spacer()
            }
        }
    }

    private var result: some View {
        HotSeatChrome(title: "Result", onClose: onExit) { _ in
            VStack(spacing: 18) {
                Image(systemName: game.iWon == true ? "trophy.fill" : "xmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(netAccent)
                Text(game.iWon == true ? "You win!" : "You lost")
                    .font(.custom("Dorsa", size: 52))
                    .foregroundStyle(netAccent)
                if !game.isSameAccount && game.iWon == true {
                    Text("+\(AppState.DifficultyLevel.expert.pointsValue) points")
                        .foregroundColor(.white.opacity(0.85))
                }
            }
        } bottomBar: { size in
            HStack {
                Spacer()
                netMenuButton("Play again", width: size.width) { game.requestRematch() }
                Spacer()
                netMenuButton("Done", width: size.width) { onExit() }
                Spacer()
            }
        }
    }

    private func fire(row: Int, column: Int) {
        guard game.canFire(row: row, column: column) else { return }
        game.tracking.fireStrokeArray[row - 1][column - 1] = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.3))
            game.tracking.fireStrokeArray[row - 1][column - 1] = false
        }
        game.fire(row: row, column: column)
    }

    private func scoreTag(name: String, sunk: Int) -> some View {
        VStack {
            Text(name).lineLimit(1)
            Text("\(sunk) / 10").bold().foregroundColor(netAccent)
        }
    }
}
