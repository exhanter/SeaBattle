//
//  HintButton.swift
//  SeaBattle
//
//  Phase 6: a button that spends points to reveal a cell that definitely
//  contains an enemy ship. Shown to everyone during an active battle (Pro-only
//  until R2.3); disabled when it isn't the player's turn or there aren't
//  enough points. Shared by the iPhone and iPad battle screens.
//

import SwiftUI

struct HintButton: View {
    @Environment(AppState.self) private var appState
    let gameLogicViewModel: GameLogicViewModel

    var body: some View {
        // С R2.3 подсказка доступна без Pro (решение заказчика 29.09): Pro
        // открывает режимы, а не ход партии. Старая кнопка живёт на iPad до R2.6.
        if appState.gameIsActive {
            Button {
                gameLogicViewModel.requestHint()
            } label: {
                Label("Hint (\(appState.difficultyLevel.pointsValue))  ·  \(ProgressStore.shared.points) pts",
                      systemImage: "lightbulb.max.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 248/255, green: 200/255, blue: 0))
            .foregroundStyle(.black)
            .disabled(!gameLogicViewModel.canUseHint)
            .opacity(gameLogicViewModel.canUseHint ? 1 : 0.5)
        }
    }
}

#Preview {
    HintButton(gameLogicViewModel: GameLogicViewModel())
        .environment(AppState())
        .environment(PremiumManager())
}
