//
//  ResultsScreen.swift
//  Sea Battle — итоги партии (R2.5, шаг 9 порядка сборки)
//
//  Спека 4.9, кадр `screen10Result` (тур 10, поправлен в 11.2; пары на 375
//  у него нет). Один экран на победу и поражение: меняются слово, цвет рамки
//  результата и состав начисления. Порядок блоков жёсткий: результат и счёт
//  по флотам → начисление баллов чеком → «Как шла партия». Снизу главная
//  кнопка и «В меню» — второстепенной кнопкой, как в кадре, а не `NavRow`.
//
//  Экран ложится поверх боя: поля уходят в размытие (`Motion.toResults`,
//  этим управляет `BattleScreen`), затем здесь карточки поднимаются
//  (`resultsFill`) и баллы досчитываются счётчиком (`pointsCounter`).
//
//  Времени партии в подзаголовке нет — правило 9 спеки: времени в игре нет
//  нигде. Строк за достижения нет: достижений в игре пока нет (R4.1).
//

import SwiftUI

// MARK: - Числа экрана

/// Из кадра `screen10Result` и его помощников (`card10`, `pointRow`,
/// `metric10`, `capLabel`). В пакете токенов этих чисел нет.
enum ResultMetrics {
    /// Верх карточки результата: 78 pt от края экрана в кадре минус полоса
    /// состояния (≈ 59 pt).
    static let top: CGFloat = 19
    static let cardGap: CGFloat = 14

    // Карточка результата
    static let frameRadius: CGFloat = 24
    static let framePadding = EdgeInsets(top: 20, leading: 18, bottom: 16, trailing: 18)
    static let frameGap: CGFloat = 14
    /// Свечение рамки 0 0 24 по спеке 4.9 (раунд 6). В коде кадра осталось
    /// `0 0 30` — спека позднее и главнее.
    static let frameGlow: CGFloat = 12
    static let word: CGFloat = 34
    static let wordTracking: CGFloat = -0.34      // −.01 em
    static let subtitle: CGFloat = 13
    static let scoreTop: CGFloat = 12
    static let scoreColumnsGap: CGFloat = 10
    static let scoreValue: CGFloat = 22
    static let scoreLabel: CGFloat = 11.5
    static let scoreLabelGap: CGFloat = 4

    // Карточки чека и показателей
    static let cardRadius: CGFloat = 20
    static let cardPadding = EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
    static let cardInnerGap: CGFloat = 10
    static let pointsIcon: CGFloat = 24
    static let pointsHeaderGap: CGFloat = 9
    static let pointsValue: CGFloat = 24
    static let rowsTop: CGFloat = 10
    static let rowGap: CGFloat = 6
    static let rowText: CGFloat = 13
    static let totalTop: CGFloat = 9
    static let totalGap: CGFloat = 7
    static let totalIcon: CGFloat = 18
    static let totalText: CGFloat = 12.5
    static let capLabel: CGFloat = 10.5
    static let capTracking: CGFloat = 10.5 * 0.11   // .11 em
    static let metricsGap: CGFloat = 12
    static let metricValue: CGFloat = 19
    static let metricLabel: CGFloat = 11.5
    static let metricLabelGap: CGFloat = 3

    // Движение
    /// На сколько поднимается карточка при появлении.
    static let rise: CGFloat = 24
    /// Размытие полей боя под итогами.
    static let fieldsBlur: CGFloat = 14
}

// MARK: - Экран

struct ResultsScreen: View {

    let result: MatchResult
    var onPlayAgain: () -> Void = {}
    var onMenu: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasRisen = false
    @State private var counted = 0.0

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: ResultMetrics.cardGap) {
                    outcomeCard
                    pointsCard
                    summaryCard
                }
                .padding(.horizontal, Geometry.Nav.stackInset)
                .padding(.top, ResultMetrics.top)
                .padding(.bottom, ResultMetrics.cardGap)
            }
            // На 393 всё помещается и ничего не должно пружинить; прокрутка
            // нужна только на малых экранах и при крупном шрифте.
            .scrollBounceBehavior(.basedOnSize)

            actions
        }
        // Карточки поднимаются; при Reduce Motion — только прозрачность.
        .offset(y: hasRisen || reduceMotion ? 0 : ResultMetrics.rise)
        .opacity(hasRisen ? 1 : 0)
        .onAppear(perform: rise)
    }

    private func rise() {
        let fill = Motion.scaled(Motion.resultsFill, reduceMotion: reduceMotion)
        withAnimation(.easeOut(duration: fill)) { hasRisen = true }
        // Баллы досчитываются, когда карточка уже на месте.
        withAnimation(.easeOut(duration: Motion.scaled(Motion.pointsCounter,
                                                       reduceMotion: reduceMotion))
                        .delay(fill)) {
            counted = Double(result.net)
        }
    }

    // MARK: Результат и счёт по флотам

    private var outcomeCard: some View {
        VStack(spacing: ResultMetrics.frameGap) {
            Text(result.didWin ? "Victory" : "Defeat")
                .font(.system(size: ResultMetrics.word, weight: .bold, design: .rounded))
                .tracking(ResultMetrics.wordTracking)
                .foregroundStyle(Color.inkPrimary)
                .accessibilityAddTraits(.isHeader)

            Text("\(Text("Single player")) · \(Text(LevelChoice.title(for: result.level)))")
                .font(.system(size: ResultMetrics.subtitle))
                .foregroundStyle(Color.inkSecondary)

            // Цвета как в бою: тёплое — ваш флот (сколько потеряли),
            // холодное — флот соперника (сколько потопили). Своё слева, как
            // в панели счёта (4.9; наоборот было ошибкой макета тура 10).
            HStack(spacing: ResultMetrics.scoreColumnsGap) {
                fleetScore(result.yourLosses, label: "you lost", color: .roleYou)
                Rectangle()
                    .fill(Color.glassStroke)
                    .frame(width: 1)
                fleetScore(result.foeLosses, label: "you sank", color: .roleFoe)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, ResultMetrics.scoreTop)
            .overlay(alignment: .top) { divider }
        }
        .frame(maxWidth: .infinity)
        .padding(ResultMetrics.framePadding)
        .glassPanel(.g2, radius: ResultMetrics.frameRadius,
                    highlight: .outcome(result.didWin ? .you : .foe))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("resultOutcome")
    }

    private func fleetScore(_ count: Int, label: LocalizedStringKey, color: Color) -> some View {
        VStack(spacing: ResultMetrics.scoreLabelGap) {
            Text(verbatim: "\(count) / \(result.fleetSize)")
                .font(.system(size: ResultMetrics.scoreValue, weight: .bold, design: .rounded)
                        .monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: ResultMetrics.scoreLabel))
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Начисление чеком

    private var pointsCard: some View {
        VStack(alignment: .leading, spacing: ResultMetrics.cardInnerGap) {
            HStack(spacing: ResultMetrics.pointsHeaderGap) {
                Image(systemName: PointsSymbol.name)
                    .font(.system(size: symbolFontSize(inBox: ResultMetrics.pointsIcon)))
                    .frame(width: ResultMetrics.pointsIcon, height: ResultMetrics.pointsIcon)
                    .foregroundStyle(Color.roleYou)
                PointsCounter(value: counted)
                    .foregroundStyle(Color.inkPrimary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(MatchResult.signed(result.net)) points"))

            // При поражении без подсказок строк нет вовсе — пустой блок с
            // линией сверху выглядел бы оборванным.
            if !result.lines.isEmpty {
                VStack(spacing: ResultMetrics.rowGap) {
                    ForEach(Array(result.lines.enumerated()), id: \.offset) { _, line in
                        pointRow(line)
                    }
                }
                .padding(.top, ResultMetrics.rowsTop)
                .overlay(alignment: .top) { divider }
            }

            HStack(spacing: ResultMetrics.totalGap) {
                Image(systemName: PointsSymbol.name)
                    .font(.system(size: symbolFontSize(inBox: ResultMetrics.totalIcon)))
                    .frame(width: ResultMetrics.totalIcon, height: ResultMetrics.totalIcon)
                Text("Balance now: \(result.balance) points")
                    .font(.system(size: ResultMetrics.totalText))
            }
            .foregroundStyle(Color.inkSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, ResultMetrics.totalTop)
            .overlay(alignment: .top) { divider }
            .accessibilityElement(children: .combine)
        }
        .padding(ResultMetrics.cardPadding)
        .glassPanel(.g2, radius: ResultMetrics.cardRadius)
        .accessibilityIdentifier("resultPoints")
    }

    private func pointRow(_ line: PointLine) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Group {
                switch line {
                case .victory: Text("Victory")
                case .hints(let count, _): Text("Hints used: \(count)")
                }
            }
            .foregroundStyle(Color.inkSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(verbatim: MatchResult.signed(line.amount))
                .fontWeight(.semibold)
                .monospacedDigit()
                // Начисление тёплое, списание приглушено (кадр `pointRow`).
                .foregroundStyle(line.amount < 0 ? Color.inkSecondary : Color.roleYou)
        }
        .font(.system(size: ResultMetrics.rowText))
        .accessibilityElement(children: .combine)
    }

    // MARK: Как шла партия

    private var summaryCard: some View {
        let tally = result.tally
        return VStack(alignment: .leading, spacing: ResultMetrics.cardInnerGap) {
            Text("How the match went")
                .font(.system(size: ResultMetrics.capLabel, weight: .bold))
                .tracking(ResultMetrics.capTracking)
                .textCase(.uppercase)
                .foregroundStyle(Color.inkSecondary)

            HStack(spacing: ResultMetrics.metricsGap) {
                metric("shots", value: Text(verbatim: "\(tally.shots)"))
                metric("accuracy", value: accuracyText(tally.accuracy))
            }
            HStack(spacing: ResultMetrics.metricsGap) {
                metric("best streak", value: Text(verbatim: "\(tally.bestStreak)"))
                metric("hints", value: Text(verbatim: "\(tally.hintsUsed)"))
            }
            .padding(.top, ResultMetrics.rowsTop)
            .overlay(alignment: .top) { divider }
        }
        .padding(ResultMetrics.cardPadding)
        .glassPanel(.g2, radius: ResultMetrics.cardRadius)
        .accessibilityIdentifier("resultSummary")
    }

    private func metric(_ label: LocalizedStringKey, value: Text) -> some View {
        VStack(alignment: .leading, spacing: ResultMetrics.metricLabelGap) {
            value
                .font(.system(size: ResultMetrics.metricValue, weight: .bold, design: .rounded)
                        .monospacedDigit())
                .foregroundStyle(Color.inkPrimary)
            Text(label)
                .font(.system(size: ResultMetrics.metricLabel))
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// Процент по правилам языка: «41 %» по-русски, «41%» по-английски.
    /// Прочерк — выстрелов не было.
    private func accuracyText(_ value: Double?) -> Text {
        guard let value else { return Text(verbatim: "—") }
        return Text(value, format: .percent.precision(.fractionLength(0)))
    }

    /// Линия между блоками карточки — кромка стекла, а не свой цвет: токена
    /// «разделитель» в пакете нет, а `.opacity()` от токена запрещён.
    private var divider: some View {
        Rectangle()
            .fill(Color.glassStroke)
            .frame(height: 1)
    }

    // MARK: Кнопки

    /// Колонка у нижнего края с числами `BottomStack`, но без `NavRow`: в
    /// кадре итогов «В меню» — второстепенная кнопка, и две строки «Меню»
    /// друг под другом были бы одним действием дважды.
    /// Вынесено из кнопки: тернарный оператор внутри `Text` в `Button`
    /// ломает инструментирование превью (сборка при этом проходит).
    private var playAgainTitle: LocalizedStringKey {
        result.didWin ? "Play again" : "Rematch"
    }

    private var actions: some View {
        VStack(spacing: Geometry.Nav.stackGap) {
            Button(action: onPlayAgain) {
                Text(playAgainTitle)
            }
            .primaryButton()
            .accessibilityIdentifier("resultPlayAgain")

            Button(action: onMenu) {
                Label("To menu", systemImage: "line.3.horizontal")
            }
            .secondaryButton()
            .accessibilityIdentifier("resultMenu")
        }
        .padding(.horizontal, Geometry.Nav.stackInset)
        .padding(.bottom, Geometry.Nav.stackBottom)
    }
}

// MARK: - Счётчик баллов

/// Баллы досчитываются от нуля за `Motion.pointsCounter`: анимируется само
/// число, а не смена цифр, поэтому это `Animatable`, а не `numericText`.
private struct PointsCounter: View, Animatable {
    var value: Double

    nonisolated var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text("\(MatchResult.signed(Int(value.rounded()))) points")
            .font(.system(size: ResultMetrics.pointsValue, weight: .bold, design: .rounded)
                    .monospacedDigit())
    }
}

// MARK: - Превью

private struct ResultsDemo: View {
    let result: MatchResult

    var body: some View {
        ZStack {
            SeaBackground()
                .ignoresSafeArea()
            ResultsScreen(result: result)
        }
    }

    /// Серия из `streak` попаданий, остальные попадания поодиночке между
    /// промахами — чтобы лучшая серия была ровно `streak`.
    static func tally(hits: Int, misses: Int, streak: Int, hints: Int, cost: Int) -> MatchTally {
        var tally = MatchTally()
        for _ in 0..<streak { tally.record(.hit(shipID: nil)) }
        for _ in 0..<(hits - streak) {
            tally.record(.miss)
            tally.record(.hit(shipID: nil))
        }
        for _ in 0..<(misses - (hits - streak)) { tally.record(.miss) }
        for _ in 0..<hints { tally.recordHint(cost: cost) }
        return tally
    }
}

#Preview("Итоги · победа") {
    ResultsDemo(result: MatchResult(
        didWin: true, level: .hard, yourLosses: 2, foeLosses: 10,
        tally: ResultsDemo.tally(hits: 20, misses: 43, streak: 4, hints: 1, cost: 6),
        balance: 126))
        .preferredColorScheme(.dark)
}

#Preview("Итоги · поражение") {
    ResultsDemo(result: MatchResult(
        didWin: false, level: .medium, yourLosses: 10, foeLosses: 7,
        tally: ResultsDemo.tally(hits: 17, misses: 41, streak: 3, hints: 1, cost: 3),
        balance: 76))
        .preferredColorScheme(.dark)
}

#Preview("Итоги · победа · светлая") {
    ResultsDemo(result: MatchResult(
        didWin: true, level: .expert, yourLosses: 6, foeLosses: 10,
        tally: ResultsDemo.tally(hits: 20, misses: 29, streak: 5, hints: 0, cost: 10),
        balance: 240))
        .preferredColorScheme(.light)
}
