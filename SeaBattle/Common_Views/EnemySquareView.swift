//
//  EnemySquareView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 07/02/2025.
//

import SwiftUI

struct EnemySquareView: View {
    
    @EnvironmentObject var appState: AppState
    @ObservedObject var enemy: PlayerData
    var gameLogicViewModel: GameLogicViewModel
    let width: CGFloat
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(1...10, id:\.self) { row in
                HStack(spacing: 0) {
                    ForEach(1...10, id: \.self) { column in
                        let status = enemy.cells[row - 1][column - 1].cellStatus
                        Button {
                            enemy.fireStrokeArray[row - 1][column - 1] = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    enemy.fireStrokeArray[row - 1][column - 1] = false
                            }
                            gameLogicViewModel.checkShipOnFire(row: row, column: column, target: enemy)
                            if appState.soundOn {
                                gameLogicViewModel.chooseSound(row: row - 1, column: column - 1)
                            }
                            if appState.enemysTurn && !AppState.isPad {
                               DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                   appState.selectedTab = .playerView
                                   DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                       gameLogicViewModel.computerTurn()
                                   }
                               }
                            } else if appState.enemysTurn && AppState.isPad {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    gameLogicViewModel.computerTurn()
                                }
                            }
                        } label: {
                            CellView(fireStrokeIsOn: enemy.fireStrokeArray[row - 1][column - 1], cellStatus: status, cellWidth: width)
                        }
                        .buttonStyle(NoPressEffect())
                        .disabled(!appState.gameIsActive)
                        .disabled(appState.enemysTurn)
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
    EnemySquareView(enemy: PlayerData(name: "Enemy"), gameLogicViewModel: GameLogicViewModel(appState: AppState(tempInstance: true), enemy: PlayerData(name: "testEnemy"), player: PlayerData(name: "testPlayer")), width: 600)
}
