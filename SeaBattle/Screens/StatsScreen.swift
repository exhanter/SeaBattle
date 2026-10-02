//
//  StatsScreen.swift
//  Sea Battle — таб «Статистика» и экран сброса (R4.1)
//
//  Спека 4.10, кадры `screen10Stats`, `screen13EmptyStats`, `screen10Reset`.
//  Одна страница: сводка полосой, «По режимам» в порядке меню, «Против
//  компьютера» на четыре уровня, строка «Баллы» и мелкая строка сброса.
//
//  Отступления от кадров — решения R4.1:
//  - **«Игры на бумаге» нет** ни в режимах, ни в сводке, ни в сбросе (решение
//    заказчика 01.10); запись в хранилище идёт как прежде (`StatsSummary`).
//  - **Достижений нет** (решение 01.10: после приложения) — строки «Достижения
//    7 из 18» нет, место под неё не держится.
//  - «Вдвоём на устройстве» — только счёт серии сохранённой партии; сбросить
//    его отсюда нельзя: серия идёт, пока играют, и умирает вместе с партией.
//  - «Общая сводка» в сбросе отмечает все режимы сразу: сводка — сумма
//    режимов, стереть её отдельно нечем (`StatsReset`). Сразу ничего не
//    отмечено — стирание должно быть выбором, а не согласием с подсказкой.
//

import SwiftUI

/// Экраны внутри таба «Статистика». Таб-бар остаётся на всех, кроме сброса:
/// там внизу свои две кнопки (кадр `screen10Reset`).
enum StatsPage: Hashable, Sendable {
    case wallet, history, reset

    var hidesTabBar: Bool { self == .reset }
}

enum StatsMetrics {
    static let blockGap: CGFloat = 8
    static let bodyTop: CGFloat = 8
    static let summaryRadius: CGFloat = 20
    static let summaryPaddingV: CGFloat = 12
    static let summaryPaddingH: CGFloat = 14
    // Строка режима (`statRow10`)
    static let modeIcon: CGFloat = 26
    static let modeName: CGFloat = 14.5
    static let modeDetail: CGFloat = 12.5
    static let modeValue: CGFloat = 15
    static let modeValueWidth: CGFloat = 46
    static let modeLock: CGFloat = 20
    static let modePaddingV: CGFloat = 4
    // Строка сброса (`resetLink`)
    static let resetText: CGFloat = 14
    static let resetChevron: CGFloat = 16
    static let resetPaddingH: CGFloat = 8
    // Сброс (`screen10Reset`)
    static let resetGroupGap: CGFloat = 14
    static let pickBox: CGFloat = 26
    static let pickRadius: CGFloat = 9
    static let pickCheck: CGFloat = 15
    static let noteText: CGFloat = 12
    static let noteRadius: CGFloat = 16
}

// MARK: - Страница статистики

struct StatsScreen: View {
    let stats: PlayerStats
    let isPremium: Bool
    /// Счёт серии сохранённой партии вдвоём; `nil` — серии нет.
    var duelSeries: [Int]?
    var onPlay: () -> Void = {}
    var onWallet: () -> Void = {}
    var onReset: () -> Void = {}

    @Environment(\.usesPadLayout) private var usesPadLayout

    private var summary: StatsSummary { StatsSummary(stats) }

    var body: some View {
        VStack(spacing: 0) {
            ScreenTitle(title: "Statistics")
                .padding(.top, NavMetrics.titleTopBelowSafeArea)

            ScrollView {
                VStack(spacing: StatsMetrics.blockGap) {
                    if summary.isEmpty {
                        emptyCard
                        ListGroup("What will be counted") { modeRows }
                        pointsCard
                    } else {
                        summaryCard
                        ListGroup("By mode") { modeRows }
                        ListGroup("Against the computer") { levelRows }
                        pointsCard
                        // Пустой странице сброс не нужен — сбрасывать нечего.
                        resetLink
                    }
                }
                .padding(.horizontal, Geometry.Nav.stackInset)
                .padding(.top, StatsMetrics.bodyTop)
                .padding(.bottom, StatsMetrics.blockGap)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: Сводка

    private var summaryCard: some View {
        StatBar(wins: summary.wins, losses: summary.losses)
            .padding(.vertical, StatsMetrics.summaryPaddingV)
            .padding(.horizontal, StatsMetrics.summaryPaddingH)
            .glassPanel(.g2, radius: StatsMetrics.summaryRadius)
    }

    private var emptyCard: some View {
        EmptyStateCard(icon: "chart.bar", title: "No games yet",
                       text: "Play your first one — wins, the win rate and the split by mode will appear here.") {
            Button("Play", action: onPlay)
                .primaryButton()
                .padding(.top, 4)
                .accessibilityIdentifier("statsPlay")
        }
    }

    // MARK: Режимы и уровни

    @ViewBuilder
    private var modeRows: some View {
        ForEach(MenuMode.all(pad: usesPadLayout)) { item in
            switch item.mode {
            case .paper:
                EmptyView()
            case .hotSeat:
                if let duelSeries, duelSeries.count == 2 {
                    StatModeRow(icon: item.icon, title: item.title,
                                detail: Text("series"),
                                value: Text(verbatim: "\(duelSeries[0]) : \(duelSeries[1])"))
                } else {
                    StatModeRow(icon: item.icon, title: item.title,
                                detail: Text("no series"), value: Text(verbatim: "—"))
                }
            case .computer, .nearby, .online:
                StatModeRow(icon: item.icon, title: item.title, record: stats.record(for: item.mode))
            }
        }
    }

    @ViewBuilder
    private var levelRows: some View {
        ForEach(LevelChoice.all) { choice in
            if choice.isLocked(isPremium: isPremium) {
                StatModeRow(icon: choice.icon, title: choice.title, isLocked: true)
            } else {
                StatModeRow(icon: choice.icon, title: choice.title,
                            record: stats.record(.computer(choice.level)))
            }
        }
    }

    // MARK: Баллы и сброс

    private var pointsCard: some View {
        ListGroup {
            ListRow(title: "Points", value: Text(verbatim: "\(stats.points)"), action: onWallet)
                .accessibilityIdentifier("statsPoints")
        }
    }

    private var resetLink: some View {
        Button(action: onReset) {
            HStack(spacing: ListMetrics.valueGap) {
                Text("Reset statistics")
                    .font(.system(size: StatsMetrics.resetText, weight: .medium))
                Image(systemName: "chevron.right")
                    .font(.system(size: symbolFontSize(inBox: StatsMetrics.resetChevron), weight: .semibold))
            }
            .foregroundStyle(Color.inkPrimary)
            .padding(.horizontal, StatsMetrics.resetPaddingH)
            .frame(maxWidth: .infinity, minHeight: Geometry.Hit.minTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("statsReset")
    }
}

// MARK: - Строка режима

/// Значок, название, справа число партий и доля побед латунью — или только
/// замок у закрытого уровня (`statRow10`). Строка не нажимается.
struct StatModeRow: View {
    let icon: String
    let title: LocalizedStringKey
    var detail: Text?
    var value: Text?
    var isLocked = false

    init(icon: String, title: LocalizedStringKey, detail: Text? = nil, value: Text? = nil,
         isLocked: Bool = false) {
        self.icon = icon
        self.title = title
        self.detail = detail
        self.value = value
        self.isLocked = isLocked
    }

    /// Строка из записи режима: прочерк у непройденного, а не 0 %.
    init(icon: String, title: LocalizedStringKey, record: StatRecord) {
        if let share = record.winShare {
            self.init(icon: icon, title: title,
                      detail: Text("\(record.played) games"),
                      value: Text(verbatim: StatBar.percent(share)))
        } else {
            self.init(icon: icon, title: title, detail: Text("no games"), value: Text(verbatim: "—"))
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: symbolFontSize(inBox: StatsMetrics.modeIcon)))
                .foregroundStyle(Color.inkPrimary)
                .frame(width: StatsMetrics.modeIcon, height: StatsMetrics.modeIcon)
            Text(title)
                .font(.system(size: StatsMetrics.modeName, weight: .medium))
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: symbolFontSize(inBox: StatsMetrics.modeLock)))
                    .foregroundStyle(Color.inkSecondary)
                    .frame(width: StatsMetrics.modeLock, height: StatsMetrics.modeLock)
                    .accessibilityLabel("Locked")
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    detail?
                        .font(.system(size: StatsMetrics.modeDetail))
                        .foregroundStyle(Color.inkSecondary)
                    value?
                        .font(.system(size: StatsMetrics.modeValue, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.roleYou)
                        .frame(minWidth: StatsMetrics.modeValueWidth, alignment: .trailing)
                }
                .monospacedDigit()
            }
        }
        .padding(.vertical, StatsMetrics.modePaddingV)
        .padding(.horizontal, ListMetrics.rowPaddingH)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Сброс

struct ResetScreen: View {
    var onReset: (StatsReset) -> Void = { _ in }
    var onCancel: () -> Void = {}

    @State private var selection = StatsReset()
    @Environment(\.usesPadLayout) private var usesPadLayout
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            ScreenTitle(title: "Reset", back: "Statistics", onBack: onCancel)
                .padding(.top, NavMetrics.titleTopBelowSafeArea)

            ScrollView {
                VStack(spacing: StatsMetrics.resetGroupGap) {
                    ListGroup("Statistics") {
                        ResetPick(title: "Overall summary", subtitle: "Every mode at once",
                                  isOn: selection.isEverything) { selection.toggleEverything() }
                        ForEach(MenuMode.all(pad: usesPadLayout)) { item in
                            if StatsSummary.shownModes.contains(item.mode) {
                                ResetPick(title: item.title,
                                          subtitle: item.mode == .computer ? "Including the split by level" : nil,
                                          isOn: selection.modes.contains(item.mode)) {
                                    selection.toggle(item.mode)
                                }
                            }
                        }
                    }
                    Text("Points already earned are not taken away: the wallet stays as it is.")
                        .font(.system(size: StatsMetrics.noteText))
                        .lineSpacing(StatsMetrics.noteText * 0.5)
                        .foregroundStyle(Color.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 13)
                        .glassPanel(.g2, radius: StatsMetrics.noteRadius)
                }
                .padding(.horizontal, Geometry.Nav.stackInset)
                .padding(.top, Geometry.Nav.titleGap * 2)
                .animation(Motion.quick.reduced(reduceMotion), value: selection)
            }
            .scrollBounceBehavior(.basedOnSize)

            // Строки «Меню» нет: это не партия, а шаг внутри таба (спека 3.1).
            VStack(spacing: Geometry.Nav.stackGap) {
                Button("Reset selected") { onReset(selection) }
                    .primaryButton(enabled: !selection.isEmpty)
                    .accessibilityIdentifier("resetConfirm")
                Button(action: onCancel) {
                    Label("Cancel", systemImage: "xmark")
                }
                .secondaryButton()
            }
            .padding(.horizontal, Geometry.Nav.stackInset)
            .padBottomFrame()
        }
    }
}

/// Строка с галочкой (`resetPick`): квадрат 26, отмеченный — латунный.
struct ResetPick: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    let isOn: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                let box = RoundedRectangle(cornerRadius: StatsMetrics.pickRadius, style: .continuous)
                ZStack {
                    box.fill(isOn ? Color.roleYouSoft : Color.glassFill2)
                    box.strokeBorder(isOn ? Color.roleYou : Color.glassStroke, lineWidth: 1)
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: symbolFontSize(inBox: StatsMetrics.pickCheck), weight: .bold))
                            .foregroundStyle(Color.inkPrimary)
                    }
                }
                .frame(width: StatsMetrics.pickBox, height: StatsMetrics.pickBox)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: ListMetrics.rowTitle, weight: .medium))
                        .foregroundStyle(Color.inkPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: ListMetrics.rowSubtitle))
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, ListMetrics.rowPaddingV)
            .padding(.horizontal, ListMetrics.rowPaddingH)
            .frame(minHeight: Geometry.Hit.minTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Превью

private extension PlayerStats {
    static var preview: PlayerStats {
        var stats = PlayerStats(points: 126)
        stats.records = [
            StatKey.computer(.easy).storageKey: StatRecord(wins: 19, losses: 3),
            StatKey.computer(.medium).storageKey: StatRecord(wins: 21, losses: 10),
            StatKey.computer(.hard).storageKey: StatRecord(wins: 8, losses: 13),
            StatKey.paper.storageKey: StatRecord(wins: 10, losses: 8),
            StatKey.nearby.storageKey: StatRecord(wins: 4, losses: 5),
            StatKey.online.storageKey: StatRecord(wins: 6, losses: 9),
        ]
        return stats
    }
}

private struct StatsPreview<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ZStack {
            SeaBackground()
                .ignoresSafeArea()
            VStack(spacing: 0) {
                content
                SeaTabBar(selection: .constant(.statistics))
            }
        }
    }
}

#Preview("Статистика") {
    StatsPreview {
        StatsScreen(stats: .preview, isPremium: false, duelSeries: [3, 2])
    }
    .preferredColorScheme(.dark)
}

#Preview("Статистика · светлая") {
    StatsPreview {
        StatsScreen(stats: .preview, isPremium: true)
    }
    .preferredColorScheme(.light)
}

#Preview("Статистика · пусто") {
    StatsPreview {
        StatsScreen(stats: PlayerStats(), isPremium: false)
    }
    .preferredColorScheme(.dark)
}

#Preview("Сброс") {
    ZStack {
        SeaBackground()
            .ignoresSafeArea()
        ResetScreen()
    }
    .preferredColorScheme(.dark)
}
