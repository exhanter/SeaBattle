//
//  StatsView.swift
//  SeaBattle
//
//  Phase 6: player statistics — wins per difficulty (tracked for ALL users),
//  losses and the points balance, with a reset. Reads the shared ProgressStore.
//

import SwiftUI

struct StatsView: View {

    private let progress = ProgressStore.shared
    @State private var showResetConfirmation = false

    private let accent = Color(red: 248/255, green: 255/255, blue: 0/255)

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.11, green: 0.77, blue: 0.56).opacity(0.60), Color(red: 0.04, green: 0.10, blue: 0.25).opacity(0.80)]), startPoint: .bottom, endPoint: .top)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Statistics")
                    .font(.title)
                    .foregroundColor(.white)

                row("Points", value: progress.points)
                Divider().background(.white)
                row("Easy", value: progress.wins(for: .easy))
                row("Medium", value: progress.wins(for: .medium))
                row("Hard", value: progress.wins(for: .hard))
                row("Expert", value: progress.wins(for: .expert))
                Divider().background(.white)
                row("Total wins", value: progress.stats.totalWins)
                row("Losses", value: progress.stats.losses)

                Button("Reset statistics", role: .destructive) {
                    showResetConfirmation = true
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)
            }
            .padding(30)
        }
        .statusBar(hidden: true)
        .confirmationDialog("Reset all statistics and points?",
                            isPresented: $showResetConfirmation,
                            titleVisibility: .visible) {
            Button("Reset", role: .destructive) { progress.reset() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func row(_ title: LocalizedStringKey, value: Int) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.white)
            Spacer()
            Text("\(value)")
                .foregroundColor(accent)
                .bold()
        }
        .font(.title3)
    }
}

#Preview {
    StatsView()
}
