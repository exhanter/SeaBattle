//
//  HintButton.swift
//  SeaBattle
//
//  Phase 6: a premium button that spends points to reveal a cell that
//  definitely contains an enemy ship. Shown only to subscribers during an
//  active battle; disabled when it isn't the player's turn or there aren't
//  enough points. Shared by the iPhone and iPad battle screens.
//

import SwiftUI

struct HintButton: View {
    @Environment(AppState.self) private var appState
    @Environment(PremiumManager.self) private var premiumManager
    let gameLogicViewModel: GameLogicViewModel

    var body: some View {
        if premiumManager.isPremium && appState.gameIsActive {
            Button {
                gameLogicViewModel.requestHint()
            } label: {
                Label("Hint (\(gameLogicViewModel.hintCost))  ·  \(ProgressStore.shared.points) pts",
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
