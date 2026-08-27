//
//  EnemySquareView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 07/02/2025.
//

import SwiftUI

struct EnemySquareView: View {
    
    @Environment(AppState.self) private var appState
    var enemy: PlayerData
    var gameLogicViewModel: GameLogicViewModel
    let width: CGFloat
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(1...10, id:\.self) { row in
                HStack(spacing: 0) {
                    ForEach(1...10, id: \.self) { column in
                        let status = enemy.cells[row - 1][column - 1].cellStatus
                        //let buttonName = "cell-\(row - 1)x\(column - 1)"
                        let buttonName = row == 1 && column == 1 ? "testCell" : ""
                        Button {
                            enemy.fireStrokeArray[row - 1][column - 1] = true
                            Task { @MainActor in
                                try? await Task.sleep(for: .seconds(0.3))
                                enemy.fireStrokeArray[row - 1][column - 1] = false
                            }
                            gameLogicViewModel.checkShipOnFire(row: row, column: column, target: enemy)
                            if appState.soundOn {
                                gameLogicViewModel.chooseSound(row: row - 1, column: column - 1)
                            }
                            if appState.enemysTurn && !AppState.isPad {
                                Task { @MainActor in
                                    try? await Task.sleep(for: .seconds(1.0))
                                    appState.selectedTab = .playerView
                                    try? await Task.sleep(for: .seconds(1.5))
                                    gameLogicViewModel.computerTurn()
                                }
                            } else if appState.enemysTurn && AppState.isPad {
                                Task { @MainActor in
                                    try? await Task.sleep(for: .seconds(1.5))
                                    gameLogicViewModel.computerTurn()
                                }
                            }
                        } label: {
                            CellView(fireStrokeIsOn: enemy.fireStrokeArray[row - 1][column - 1], cellStatus: status, cellWidth: width)
                                .overlay {
                                    if status == .unknown && appState.revealedHintCells.contains(where: { $0 == (row, column) }) {
                                        // Rendered as a sized image (not via .font) so it
                                        // sits on the cell's geometric centre — an SF Symbol
                                        // drawn as text is offset by the font baseline.
                                        // The cell's bevel (light top-left, thick dark
                                        // bottom-right) pulls the perceived centre up-left, so
                                        // nudge the marker up-left to look centred. Tune here.
                                        let hintNudge = width * 0.025
                                        Image(systemName: "target")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: width * 0.6, height: width * 0.6)
                                            .foregroundStyle(Color(red: 248/255, green: 1, blue: 0))
                                            .shadow(color: .black, radius: 1)
                                            .offset(x: -hintNudge, y: -hintNudge)
                                    }
                                }
                        }
                        .buttonStyle(NoPressEffect())
                        .disabled(!appState.gameIsActive)
                        .disabled(appState.enemysTurn)
                        .accessibility(identifier: buttonName)
                    }
                }
            }
        }
    }
    init(enemy: PlayerData, gameLogicViewModel: GameLogicViewModel, width: CGFloat) {
        self.enemy = enemy
        self.gameLogicViewModel = gameLogicViewModel
        self.width = width
    }
}

#Preview {
    EnemySquareView(enemy: PlayerData(name: "Enemy"), gameLogicViewModel: GameLogicViewModel(), width: 600)
}
