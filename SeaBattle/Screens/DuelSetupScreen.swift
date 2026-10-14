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

    // iPad (этап 1, 13.10): сетка экрана уровня.
    /// Вся раскладка не шире этого, по центру экрана.
    static let padMaxWidth: CGFloat = 1000
    static let padColumnGap: CGFloat = 24
    static let padRowGap: CGFloat = 18
    static let nextAvatar: CGFloat = 52
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
    /// iPad: высота прокрутки — блок стоит по центру неё.
    @State private var viewportHeight: CGFloat = 0

    var body: some View {
        if usesPadLayout {
            padBody
                // iPad: квадраты по углам, как на уровне и итогах.
                .environment(\.bottomChrome, .tiles)
        } else {
            phoneBody
        }
    }

    private var phoneBody: some View {
        VStack(spacing: 0) {
            ScreenTitle(title: "Two players on one device",
                        back: "Home",
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
                    Text("The color shows in the avatar, the name and on the handoff screen. The boards look the same for both: warm is yours, cool is your opponent’s.")
                        .font(.scalable(size: DuelSetupMetrics.note))
                        .lineSpacing(DuelSetupMetrics.note * 0.5)
                        .foregroundStyle(Color.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, DuelSetupMetrics.labelInset)
                }
                .padding(.horizontal, Geometry.Nav.stackInset)
                .padding(.vertical, DuelSetupMetrics.blockGap)
            }
            .seaScroll()
            .scrollDismissesKeyboard(.interactively)

            BottomStack(onMenu: onBack) {
                Button { onStart() } label: {
                    startTitle
                }
                .primaryButton(enabled: setup.namesDiffer)
                .accessibilityIdentifier("duelStart")
            }
        }
    }

    // MARK: iPad

    /// iPad: сетка 2 × 2 из блоков одной высоты, как экран уровня. Сверху
    /// карточки игроков рядом, под ними настройки партии и «кто расставляет
    /// первым». Имя ушло из главной кнопки в этот блок: в квадрат 104
    /// «Аня расставляет флот» не помещается, на кнопке — «Начать».
    private var padBody: some View {
        VStack(spacing: 0) {
            ScreenTitle(title: "Two players on one device", back: "Home",
                        subtitle: "Two players, one device in turns", onBack: onBack)
                .padding(.top, NavMetrics.titleTopBelowSafeArea)
                .frame(maxWidth: DuelSetupMetrics.padMaxWidth)
                .padding(.horizontal, Geometry.Inset.padFrame)

            ScrollView {
                VStack(alignment: .leading, spacing: DuelSetupMetrics.padRowGap) {
                    padRow {
                        column("Players") { card(0, stretches: true) }
                    } right: {
                        column(nil) { card(1, stretches: true) }
                    }
                    padRow {
                        column("Match") { options(stretches: true) }
                    } right: {
                        column(nil) { nextStep }
                    }
                }
                .frame(maxWidth: DuelSetupMetrics.padMaxWidth)
                .padding(.horizontal, Geometry.Inset.padFrame + Geometry.Nav.stackInset)
                .padding(.top, Geometry.Nav.titleGap * 2)
                .padding(.bottom, Geometry.Nav.titleGap)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                // Блок по центру высоты, как на экране уровня.
                .frame(minHeight: viewportHeight, alignment: .center)
            }
            .seaScroll()
            .scrollDismissesKeyboard(.interactively)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewportHeight = $0 }

            BottomStack(onMenu: onBack) {
                Button { onStart() } label: { Text("Start") }
                    .primaryButton(enabled: setup.namesDiffer)
                    .accessibilityIdentifier("duelStart")
            }
        }
    }

    /// Две колонки одной ширины, блоки в ряду одной высоты.
    private func padRow<Left: View, Right: View>(@ViewBuilder _ left: () -> Left,
                                                 @ViewBuilder right: () -> Right) -> some View {
        HStack(alignment: .top, spacing: DuelSetupMetrics.padColumnGap) {
            left().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            right().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Надзаголовок над колонкой; у правой его нет — место держится, чтобы
    /// блоки ряда начинались вровень.
    private func column<Content: View>(_ title: LocalizedStringKey?,
                                       @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DuelSetupMetrics.blockGap) {
            sectionLabel(title ?? "Players")
                .opacity(title == nil ? 0 : 1)
                .accessibilityHidden(title == nil)
            content()
                .frame(maxHeight: .infinity)
        }
    }

    /// Кто расставляет флот первым — то, что на iPhone написано на главной
    /// кнопке. Ниже — пояснение про цвета (на iPhone оно под настройками).
    private var nextStep: some View {
        let first = setup.players[0]
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                AvatarDot(glyph: first.glyph, colorIndex: first.colorIndex,
                          size: DuelSetupMetrics.nextAvatar)
                startTitle
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            Rectangle()
                .fill(Color.glassStroke)
                .frame(height: 1)
            Text("The color shows in the avatar, the name and on the handoff screen. The boards look the same for both: warm is yours, cool is your opponent’s.")
                .font(.scalable(size: DuelSetupMetrics.note))
                .lineSpacing(DuelSetupMetrics.note * 0.5)
                .foregroundStyle(Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassPanel(.g2, radius: DuelSetupMetrics.cardRadius, highlight: .selected)
    }

    /// Вынесено из кнопки: интерполяция внутри `Text` в `Button` ломает
    /// инструментирование превью (сборка при этом проходит).
    private var startTitle: some View {
        Text("\(setup.displayName(0)) places the fleet")
            .lineLimit(1)
    }

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.scalable(size: DuelSetupMetrics.sectionLabel, weight: .bold))
            .tracking(DuelSetupMetrics.sectionLabel * 0.1)
            .textCase(.uppercase)
            .foregroundStyle(Color.inkSecondary)
            .padding(.leading, DuelSetupMetrics.labelInset)
    }

    // MARK: Игроки

    /// `stretches` — iPad: карточка тянется до высоты соседней в ряду.
    private func card(_ index: Int, stretches: Bool = false) -> some View {
        PlayerCard(name: $setup.players[index].name,
                   glyph: $setup.players[index].glyph,
                   colorIndex: $setup.players[index].colorIndex,
                   recent: recentChips(for: index),
                   placeholder: "Player \(index + 1)")
            .padding(DuelSetupMetrics.cardPadding)
            .frame(maxHeight: stretches ? .infinity : nil, alignment: .top)
            .glassPanel(.g2, radius: DuelSetupMetrics.cardRadius)
            .accessibilityIdentifier("duelPlayer\(index)")
            // Карточек две и устроены одинаково — без имени VoiceOver не
            // скажет, в какую вошли.
            .accessibilityLabel(Text("Player \(index + 1)"))
    }

    /// Три последних игрока — кроме тех, кто уже сидит в одной из карточек:
    /// подставить Бориса второй раз некуда.
    private func recentChips(for index: Int) -> [RecentPlayer] {
        let taken = Set(setup.players.map { $0.name.lowercased() })
        return Array(recent.filter { !taken.contains($0.name.lowercased()) }.prefix(3))
    }

    // MARK: Код и первый ход

    private var options: some View { options(stretches: false) }

    private func options(stretches: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle(isOn: $setup.locksWithCode) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lock the screen with a code")
                        .font(.scalable(size: DuelSetupMetrics.optionTitle, weight: .semibold,
                                      design: .rounded))
                        .foregroundStyle(Color.inkPrimary)
                    (usesPadLayout ? Text("Four digits when passing the device")
                                   : Text("Four digits when passing the phone"))
                        .font(.scalable(size: DuelSetupMetrics.optionSubtitle))
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
                    .font(.scalable(size: DuelSetupMetrics.optionTitle, weight: .semibold,
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
        .frame(maxHeight: stretches ? .infinity : nil, alignment: .top)
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

// MARK: - Превью iPad

private struct DuelSetupPadDemo: View {
    var mirrored = false
    @State private var appState = AppState()

    var body: some View {
        DuelSetupDemo()
            .environment(appState)
            .environment(\.usesPadLayout, true)
            .environment(\.mirrorsBottomTiles, mirrored)
            .preferredColorScheme(.dark)
    }
}

struct DuelSetupPadPreview1: PreviewProvider {
    static var previews: some View {
        DuelSetupPadDemo()
            .padPreview(.portrait, "Вдвоём · настройка · iPad · вертикально")
    }
}

struct DuelSetupPadPreview2: PreviewProvider {
    static var previews: some View {
        DuelSetupPadDemo()
            .padPreview(.landscapeLeft, "Вдвоём · настройка · iPad · горизонтально")
    }
}

struct DuelSetupPadPreview3: PreviewProvider {
    static var previews: some View {
        DuelSetupPadDemo(mirrored: true)
            .padPreview(.landscapeLeft, "Вдвоём · настройка · iPad · своё поле справа")
    }
}
