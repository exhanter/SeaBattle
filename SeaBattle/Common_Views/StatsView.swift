//
//  StatsView.swift
//  SeaBattle
//
//  Phase 6: player statistics — wins and losses per mode (tracked for ALL
//  users) and the points balance, with a reset. Reads the shared ProgressStore.
//
//  R0.7: the modes are listed apart, in menu order, and the computer is split
//  by level. Network wins used to be shown on the "Expert" line (audit finding
//  A7). This is the pre-redesign screen; the designed one arrives with R3.
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
            VStack(spacing: 12) {
                Text("Statistics")
                    .font(.title)
                    .foregroundColor(.white)

                row("Points", value: progress.points)
                Divider().background(.white)
                // Summary: games, wins, share of games won.
                row("Games", value: progress.stats.totalGames)
                row("Total wins", value: progress.stats.totalWins)
                row("Losses", value: progress.stats.totalLosses)
                row("Win rate", text: winRateText)
                Divider().background(.white)
                // By mode, in menu order; wins–losses on each line.
                Text("Against computer")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .leading)
                row("Easy", record: progress.record(.computer(.easy)))
                row("Medium", record: progress.record(.computer(.medium)))
                row("Hard", record: progress.record(.computer(.hard)))
                row("Expert", record: progress.record(.computer(.expert)))
                row("Paper game", record: progress.record(.paper))
                row("Nearby", record: progress.record(.nearby))
                row("Online", record: progress.record(.online))

                Button("Reset statistics", role: .destructive) {
                    showResetConfirmation = true
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)
            }
            .padding(24)
        }
        .statusBar(hidden: true)
        .confirmationDialog("Reset all statistics and points?",
                            isPresented: $showResetConfirmation,
                            titleVisibility: .visible) {
            Button("Reset", role: .destructive) { progress.reset() }
            Button("Cancel", role: .cancel) {}
        }
    }

    /// An empty history shows a dash rather than 0% (spec 4.9).
    private var winRateText: String {
        guard let share = progress.stats.winShare else { return "—" }
        return "\(Int((share * 100).rounded()))%"
    }

    private func row(_ title: LocalizedStringKey, value: Int) -> some View {
        row(title, text: "\(value)")
    }

    /// A mode line: wins and losses, or a dash while the mode is unplayed.
    private func row(_ title: LocalizedStringKey, record: StatRecord) -> some View {
        row(title, text: record.played == 0 ? "—" : "\(record.wins) : \(record.losses)")
    }

    private func row(_ title: LocalizedStringKey, text: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.white)
            Spacer()
            Text(text)
                .foregroundColor(accent)
                .bold()
        }
        .font(.title3)
    }
}

#Preview {
    StatsView()
}
