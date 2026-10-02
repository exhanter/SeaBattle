//
//  DuelSetupScreen.swift
//  Sea Battle — вдвоём на устройстве: настройка (R3.2, шаг 12)
//
//  Спека 4.7, кадр `screen4TwoSetup` (тур 4 — старше системы компонентов,
//  поэтому верх и низ — `ScreenTitle` и `BottomStack`, как на всех экранах
//  партии, 3.1). Две `PlayerCard`, «Закрывать экран кодом», «Первый ход»:
//  жребий / имя / имя. Главная кнопка называет следующего: «Аня расставляет
//  флот».
//

import SwiftUI

// MARK: - Числа

/// Кадр `screen4TwoSetup`.
enum DuelSetupMetrics {
    static let blockGap: CGFloat = 12
    static let cardRadius: CGFloat = 20
    static let cardPadding = EdgeInsets(top: 12, leading: 13, bottom: 12, trailing: 13)
    /// Подпись «Игроки» — 11 pt, разрядка .1 em, поле слева 3.
    static let sectionLabel: CGFloat = 11
    static let labelInset: CGFloat = 3
    static let optionsPadding = EdgeInsets(top: 4, leading: 15, bottom: 12, trailing: 15)
    static let optionTitle: CGFloat = 14.5
    static let optionSubtitle: CGFloat = 11.5
    static let optionRowPadding: CGFloat = 11
    static let firstMoveGap: CGFloat = 9
    static let note: CGFloat = 11.5
}

// MARK: - Экран

struct DuelSetupScreen: View {

    @Binding var setup: DuelSetup
    /// «Играли раньше» — последние игроки, новые первыми.
    var recent: [RecentPlayer] = []
    var onStart: () -> Void = {}
    var onBack: () -> Void = {}

    @Environment(\.usesPadLayout) private var usesPadLayout
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 0) {
            ScreenTitle(title: "Two players on one device",
                        back: "Play",
                        // На iPad «телефон» неверен — «устройство» (решение заказчика 30.09).
                        subtitle: usesPadLayout ? "Two players, one device in turns"
                                                : "Two players, one phone in turns",
                        onBack: onBack)
                .padding(.top, NavMetrics.titleTopBelowSafeArea)

            ScrollView {
                VStack(alignment: .leading, spacing: DuelSetupMetrics.blockGap) {
                    sectionLabel("Players")
                    card(0)
                    card(1)
                    options
                    Text("The colour shows in the avatar, the name and on the handoff screen. The boards look the same for both: warm is yours, cool is your opponent’s.")
                        .font(.system(size: DuelSetupMetrics.note))
                        .lineSpacing(DuelSetupMetrics.note * 0.5)
                        .foregroundStyle(Color.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, DuelSetupMetrics.labelInset)
                }
                .padding(.horizontal, Geometry.Nav.stackInset)
                .padding(.vertical, DuelSetupMetrics.blockGap)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)

            BottomStack(onMenu: onBack) {
                Button(action: onStart) {
                    startTitle
                }
                .primaryButton(enabled: setup.namesDiffer)
                .accessibilityIdentifier("duelStart")
            }
        }
    }

    /// Вынесено из кнопки: интерполяция внутри `Text` в `Button` ломает
    /// инструментирование превью (сборка при этом проходит).
    private var startTitle: some View {
        Text("\(setup.displayName(0)) places the fleet")
            .lineLimit(1)
    }

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: DuelSetupMetrics.sectionLabel, weight: .bold))
            .tracking(DuelSetupMetrics.sectionLabel * 0.1)
            .textCase(.uppercase)
            .foregroundStyle(Color.inkSecondary)
            .padding(.leading, DuelSetupMetrics.labelInset)
    }

    // MARK: Игроки

    private func card(_ index: Int) -> some View {
        PlayerCard(name: $setup.players[index].name,
                   glyph: $setup.players[index].glyph,
                   colorIndex: $setup.players[index].colorIndex,
                   recent: recentChips(for: index),
                   placeholder: "Player \(index + 1)")
            .padding(DuelSetupMetrics.cardPadding)
            .glassPanel(.g2, radius: DuelSetupMetrics.cardRadius)
            .accessibilityIdentifier("duelPlayer\(index)")
    }

    /// Три последних игрока — кроме тех, кто уже сидит в одной из карточек:
    /// подставить Бориса второй раз некуда.
    private func recentChips(for index: Int) -> [RecentPlayer] {
        let taken = Set(setup.players.map { $0.name.lowercased() })
        return Array(recent.filter { !taken.contains($0.name.lowercased()) }.prefix(3))
    }

    // MARK: Код и первый ход

    private var options: some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle(isOn: $setup.locksWithCode) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lock the screen with a code")
                        .font(.system(size: DuelSetupMetrics.optionTitle, weight: .semibold,
                                      design: .rounded))
                        .foregroundStyle(Color.inkPrimary)
                    (usesPadLayout ? Text("Four digits when passing the device")
                                   : Text("Four digits when passing the phone"))
                        .font(.system(size: DuelSetupMetrics.optionSubtitle))
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            .seaToggleStyle()
            .padding(.vertical, DuelSetupMetrics.optionRowPadding)
            .accessibilityIdentifier("duelLocks")

            Rectangle()
                .fill(Color.glassStroke)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: DuelSetupMetrics.firstMoveGap) {
                Text("First move")
                    .font(.system(size: DuelSetupMetrics.optionTitle, weight: .semibold,
                                  design: .rounded))
                    .foregroundStyle(Color.inkPrimary)
                SegmentedPick(options: [(DuelFirstMove.coinToss, String(game: "Coin toss", locale: locale)),
                                        (.player(0), setup.displayName(0)),
                                        (.player(1), setup.displayName(1))],
                              selection: $setup.firstMove)
                    .accessibilityIdentifier("duelFirstMove")
            }
            .padding(.top, DuelSetupMetrics.optionRowPadding)
        }
        .padding(DuelSetupMetrics.optionsPadding)
        .glassPanel(.g2, radius: DuelSetupMetrics.cardRadius)
    }
}

// MARK: - Превью

private struct DuelSetupDemo: View {
    @State private var setup = DuelSetup(players: [
        DuelPlayer(name: "Аня", glyph: "sailboat.fill", colorIndex: 0),
        DuelPlayer(name: "Борис", glyph: "helm", colorIndex: 8)])

    var body: some View {
        ZStack {
            SeaBackground()
                .ignoresSafeArea()
            DuelSetupScreen(setup: $setup,
                            recent: [RecentPlayer(name: "Ксюша", glyph: "fish.fill", colorIndex: 13),
                                     RecentPlayer(name: "Мама", glyph: "star.fill", colorIndex: 10),
                                     RecentPlayer(name: "Гость", glyph: "flag.fill", colorIndex: 15)])
        }
    }
}

#Preview("Вдвоём · настройка") {
    DuelSetupDemo()
        .preferredColorScheme(.dark)
}

#Preview("Вдвоём · настройка · светлая") {
    DuelSetupDemo()
        .preferredColorScheme(.light)
}

#Preview("Вдвоём · настройка · 375", traits: .fixedLayout(width: 375, height: 667)) {
    DuelSetupDemo()
        .preferredColorScheme(.dark)
}
