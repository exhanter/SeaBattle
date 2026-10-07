//
//  WalletScreen.swift
//  Sea Battle — кошелёк баллов (R4.1)
//
//  Спека 4.10, кадры `screen12Wallet` и `screen13EmptyWallet`. Открывается
//  строкой «Баллы» со страницы статистики; своего таба у кошелька нет.
//
//  Отступления от кадров — решения R4.1:
//  - **Цена подсказки не одна.** В кадре «5 баллов за ход, это 25 подсказок»,
//    а в игре подсказка стоит столько же, сколько победа на уровне партии
//    (1 / 3 / 5 / 10, по сети — 10); цену заказчик ещё не выбрал (раздел про
//    R2.3 в `docs/STATUS.md`). Поэтому под балансом честное правило, а не
//    число подсказок.
//  - **Достижений нет** (решение 01.10) — их строки и источника «за
//    достижения» нет.
//  - Витрины и обещаний «магазин будет позже» нет (решение заказчика 07.10:
//    это внутренние планы, а не информация для игрока).
//  - **«За деньги не купить» не пишем** (спека 4.10 и кадр 13a говорят
//    обратное): у заказчика в плане покупка баллов отдельно от Pro (решение
//    01.10, `docs/REDESIGN_PLAN.md`). Пока её нет, пустой кошелёк просто
//    говорит, откуда баллы.
//  - Баллы, заработанные до R4.1, истории не имеют: тогда кошелёк был одним
//    числом. Такой баланс показывается со строкой «История начинается с
//    этой версии» вместо списка движений.
//

import SwiftUI

enum WalletMetrics {
    static let blockGap: CGFloat = 12
    // Баланс
    static let balanceRadius: CGFloat = 22
    static let balancePaddingV: CGFloat = 18
    static let balancePaddingH: CGFloat = 16
    static let balanceIcon: CGFloat = 30
    static let balanceValue: CGFloat = 36
    static let balanceUnit: CGFloat = 14
    static let ruleIcon: CGFloat = 20
    static let ruleText: CGFloat = 12.5
    // Движение (`walletRow`)
    static let entryIcon: CGFloat = 24
    static let entryName: CGFloat = 14
    static let entryWhen: CGFloat = 11.5
    static let entryValue: CGFloat = 15
    static let entryPaddingV: CGFloat = 9
}

struct WalletScreen: View {
    let points: Int
    let entries: [PointsEntry]
    var onBack: () -> Void = {}
    var onHistory: () -> Void = {}

    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isEmpty: Bool { points == 0 && entries.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            ScreenTitle(title: "Points", back: "Statistics", onBack: onBack)
                .padding(.top, NavMetrics.titleTopBelowSafeArea)

            // Баланс закреплён под заголовком, прокручивается только история
            // (заказчик, 07.10): раньше всё уезжало под заголовок, и число
            // баллов пропадало с экрана первым.
            if !isEmpty {
                balance
                    .padding(.horizontal, Geometry.Nav.stackInset)
                    .padding(.top, Geometry.Nav.titleGap * 2)
            }

            ScrollView {
                VStack(spacing: WalletMetrics.blockGap) {
                    if isEmpty {
                        EmptyStateCard(icon: PointsSymbol.name, title: "Nothing yet",
                                       text: "Points are earned for wins in the game and spent on hints.")
                        sources
                    } else {
                        ListGroup("Latest entries") {
                            if entries.isEmpty {
                                ListRow(title: "No entries yet",
                                        subtitle: "The history starts with this version; points earned earlier are in the balance.")
                            } else {
                                ForEach(Array(entries.prefix(5))) { PointsEntryRow(entry: $0) }
                            }
                        }
                        if !entries.isEmpty {
                            ListGroup {
                                ListRow(title: "All entries", action: onHistory)
                                    .accessibilityIdentifier("walletHistory")
                            }
                        }
                    }
                }
                .padding(.horizontal, Geometry.Nav.stackInset)
                .padding(.top, isEmpty ? Geometry.Nav.titleGap * 2 : WalletMetrics.blockGap)
                .padding(.bottom, WalletMetrics.blockGap)
            }
            .seaScroll()
        }
    }

    // MARK: Баланс

    /// «126 баллов» одной строкой каталога — слово склоняется по числу, — а
    /// число крупнее: его кусок строка помечает сама (`localizedNumericArgument`).
    private var balanceLine: AttributedString {
        var resource: LocalizedStringResource = "\(points) points"
        resource.locale = locale
        var line = AttributedString(localized: resource)
        line.font = .scalable(size: WalletMetrics.balanceUnit)
        line.foregroundColor = Color.inkSecondary
        for run in line.runs where run.localizedNumericArgument != nil {
            line[run.range].font = .scalable(size: WalletMetrics.balanceValue, weight: .bold,
                                           design: .rounded).monospacedDigit()
            line[run.range].foregroundColor = Color.inkPrimary
        }
        return line
    }

    private var balance: some View {
        VStack(alignment: .leading, spacing: 12) {
            // На AX1–AX5 строка переносится («126 / баллов»): значок держится
            // первой строки, а не последней.
            HStack(alignment: dynamicTypeSize.isAccessibilitySize ? .firstTextBaseline
                                                                  : .lastTextBaseline,
                   spacing: 10) {
                Image(systemName: PointsSymbol.name)
                    .font(.scalable(size: symbolFontSize(inBox: WalletMetrics.balanceIcon)))
                    .foregroundStyle(Color.roleYou)
                    .alignmentGuide(.lastTextBaseline) { $0[.bottom] - 3 }
                Text(balanceLine)
            }
            .accessibilityElement(children: .combine)

            Rectangle()
                .fill(Color.glassStroke)
                .frame(height: 1)

            HStack(alignment: .top, spacing: 9) {
                ScaledSymbol(name: "lightbulb.max", box: WalletMetrics.ruleIcon)
                    .foregroundStyle(Color.inkPrimary)
                    .accessibilityHidden(true)
                Text("For now points are spent on hints: a hint costs as much as a win at the level of the match, from 1 to 10 points.")
                    .font(.scalable(size: WalletMetrics.ruleText))
                    .lineSpacing(WalletMetrics.ruleText * 0.4)
                    .foregroundStyle(Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, WalletMetrics.balancePaddingV)
        .padding(.horizontal, WalletMetrics.balancePaddingH)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(.g2, radius: WalletMetrics.balanceRadius, highlight: .selected)
    }

    // MARK: Пустой кошелёк

    /// Откуда берутся баллы — ставки из `StatKey.pointsForWin`, а не из текста.
    private var sources: some View {
        let levels = AppState.DifficultyLevel.allCases.map(\.pointsValue)
        let computer = "+\(levels.min() ?? 0) … +\(levels.max() ?? 0)"
        let person = "+\(StatKey.online.pointsForWin)"
        return ListGroup("Where they come from") {
            sourceRow(icon: "cpu", title: "A win over the computer", value: computer)
            sourceRow(icon: "globe", title: "A win over a person, nearby or online", value: person)
        }
    }

    private func sourceRow(icon: String, title: LocalizedStringKey, value: String) -> some View {
        // На AX1–AX5 — столбцом, как все строки «текст · число» (R4.5d).
        AdaptiveRow(spacing: 12) {
            ScaledSymbol(name: icon, box: WalletMetrics.entryIcon)
                .foregroundStyle(Color.inkPrimary)
            Text(title)
                .font(.scalable(size: WalletMetrics.entryName))
                .foregroundStyle(Color.inkPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: value)
                .font(.scalable(size: WalletMetrics.entryValue, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.roleYou)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, ListMetrics.rowPaddingH)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Все начисления

struct PointsHistoryScreen: View {
    let entries: [PointsEntry]
    var onBack: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            ScreenTitle(title: "All entries", back: "Points", onBack: onBack)
                .padding(.top, NavMetrics.titleTopBelowSafeArea)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(entries) { entry in
                        if entry.id != entries.first?.id { ListDivider() }
                        PointsEntryRow(entry: entry)
                    }
                }
                .glassPanel(.g2, radius: ListMetrics.groupRadius)
                .padding(.horizontal, Geometry.Nav.stackInset)
                .padding(.top, Geometry.Nav.titleGap * 2)
                .padding(.bottom, WalletMetrics.blockGap)
            }
            .seaScroll()
        }
    }
}

// MARK: - Строка движения

/// Тот же чек, что на итогах партии, только одним списком (`walletRow`):
/// значок, что это было, когда, и сумма — начисление латунью, трата серым.
struct PointsEntryRow: View {
    let entry: PointsEntry
    var now: Date = .now

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        AdaptiveRow(spacing: 12) {
            ScaledSymbol(name: icon, box: WalletMetrics.entryIcon, variableValue: iconValue)
                .foregroundStyle(Color.inkPrimary)
            VStack(alignment: .leading, spacing: 2) {
                title
                    .font(.scalable(size: WalletMetrics.entryName, weight: .medium))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                when
                    .font(.scalable(size: WalletMetrics.entryWhen))
                    .foregroundStyle(Color.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: Self.signed(entry.amount))
                .font(.scalable(size: WalletMetrics.entryValue, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(entry.amount < 0 ? Color.inkSecondary : Color.roleYou)
        }
        .padding(.vertical, WalletMetrics.entryPaddingV)
        .padding(.horizontal, ListMetrics.rowPaddingH)
        .accessibilityElement(children: .combine)
    }

    /// «+40» и «−10» — настоящим минусом, как в кадре и на итогах.
    static func signed(_ amount: Int) -> String {
        amount < 0 ? "\u{2212}\(-amount)" : "+\(amount)"
    }

    private var icon: String {
        switch entry.kind {
        case .win:
            if entry.winRow?.difficulty != nil { return LevelChoice.icon }
            switch entry.winRow?.mode {
            case .nearby: return "iphone.radiowaves.left.and.right"
            case .online: return "globe"
            default: return "cpu"
            }
        case .hints: return "lightbulb.max"
        case .compensation: return "lightbulb"
        }
    }

    /// Деления шкалы у победы над компьютером — по уровню партии.
    private var iconValue: Double? {
        guard case .win = entry.kind, let level = entry.winRow?.difficulty else { return nil }
        return LevelChoice.iconValue(for: level)
    }

    private var title: Text {
        switch entry.kind {
        case .win:
            switch entry.winRow {
            case .computer(let level): return Text("Win · \(Text(LevelChoice.title(for: level)))")
            case .nearby: return Text("Win · nearby")
            case .online: return Text("Win · online")
            default: return Text("Win")
            }
        case .hints(let count):
            return count == 1 ? Text("Hint") : Text("Hints, \(count) times")
        case .compensation(let count):
            return count == 1 ? Text("Opponent's hint") : Text("Opponent's hints, \(count) times")
        }
    }

    private var when: Text {
        let calendar = Calendar.current
        if calendar.isDate(entry.date, inSameDayAs: now) { return Text("today") }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(entry.date, inSameDayAs: yesterday) { return Text("yesterday") }
        let sameYear = calendar.isDate(entry.date, equalTo: now, toGranularity: .year)
        return Text(entry.date, format: sameYear ? .dateTime.day().month(.wide)
                                                 : .dateTime.day().month(.wide).year())
    }
}

// MARK: - Превью

private extension Array where Element == PointsEntry {
    static var preview: [PointsEntry] {
        let now = Date.now
        let day: TimeInterval = 86_400
        var ledger = PointsLedger()
        ledger.addWin(.computer(.hard), points: 5, at: now.addingTimeInterval(-40 * day))
        ledger.addWin(.online, points: 10, at: now.addingTimeInterval(-day))
        ledger.addHint(cost: 5, at: now)
        ledger.addHint(cost: 5, at: now)
        ledger.addCompensation(10, at: now)
        ledger.addWin(.computer(.hard), points: 5, at: now)
        return ledger.entries
    }
}

private struct WalletPreview<Content: View>: View {
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

#Preview("Баллы") {
    WalletPreview { WalletScreen(points: 126, entries: .preview) }
        .preferredColorScheme(.dark)
}

#Preview("Баллы · светлая") {
    WalletPreview { WalletScreen(points: 126, entries: .preview) }
        .preferredColorScheme(.light)
}

#Preview("Баллы · пусто") {
    WalletPreview { WalletScreen(points: 0, entries: []) }
        .preferredColorScheme(.dark)
}

#Preview("Все начисления") {
    WalletPreview { PointsHistoryScreen(entries: .preview) }
        .preferredColorScheme(.dark)
}

/// iPhone 12 mini: баланс закреплён, история уходит под него и над таб-баром
/// растворяется, а не обрезается линией.
#Preview("Баллы · 375 × 812", traits: .fixedLayout(width: 375, height: 812)) {
    WalletPreview { WalletScreen(points: 126, entries: .preview) }
        .preferredColorScheme(.dark)
}
