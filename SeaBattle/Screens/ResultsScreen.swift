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
    /// iPad: между карточками и полем.
    static let boardsGap: CGFloat = 24

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
    /// Вдвоём на устройстве: аватар победителя над словом и в счёте серии.
    static let duelAvatar: CGFloat = 44
    static let seriesAvatar: CGFloat = 32

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
    /// «Посмотреть поля»: итоги уходят, поля партии снова видны. `nil` —
    /// кнопки нет.
    var onReview: (() -> Void)?
    /// Поля партии — на iPad вместо «Посмотреть поля»: одно поле размером
    /// как на столе, под ним переключатель «Моё поле / Противник» (выбор
    /// заказчика 13.10). `nil` — полей нет.
    var boards: ResultBoards?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.bottomChrome) private var bottomChrome
    @Environment(\.usesPadLayout) private var usesPadLayout
    @State private var hasRisen = false
    @State private var counted = 0.0
    /// Размер экрана итогов и высота нижнего ряда — от них клетка полей и
    /// раскладка. Меряется снаружи (`GeometryReader`), а не по прокрутке:
    /// поля рядом с карточками шире прокрутки, и та начинала считать себя
    /// горизонтальной.
    @State private var screen: CGSize = .zero
    @State private var safeArea = EdgeInsets()
    @State private var actionsHeight: CGFloat = 0
    /// Какое поле видно на iPad: по умолчанию противника.
    @State private var shownBoard: Side = .foe

    /// Область прокрутки — экран без нижнего ряда.
    private var viewport: CGSize {
        CGSize(width: screen.width, height: max(0, screen.height - actionsHeight))
    }

    /// iPad горизонтально: карточки и поле одним рядом.
    private var boardsBeside: Bool { boards != nil && screen.width > screen.height }

    /// Низ: на iPad — квадраты по углам (выбор заказчика 13.10).
    private var chrome: Geometry.BottomChrome { usesPadLayout ? .tiles : bottomChrome }

    /// Поле по бокам: на iPad рамка 24, как у квадратов в углах.
    private var sideInset: CGFloat { usesPadLayout ? Geometry.Inset.padFrame : Geometry.Nav.stackInset }

    /// Колонка карточек на iPad без полей; iPhone — весь экран.
    private var cardsWidth: CGFloat {
        usesPadLayout ? Geometry.Nav.padColumn : .infinity
    }

    var body: some View {
        GeometryReader { proxy in
            content
                .frame(width: proxy.size.width, height: proxy.size.height)
                .onAppear {
                    screen = proxy.size
                    safeArea = proxy.safeAreaInsets
                }
                .onChange(of: proxy.size) { _, size in
                    screen = size
                    safeArea = proxy.safeAreaInsets
                }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                Group {
                    if usesPadLayout, let boards {
                        padLayout(boards)
                    } else {
                        cards
                            .frame(maxWidth: cardsWidth)
                    }
                }
                .padding(.horizontal, sideInset)
                .padding(.top, ResultMetrics.top)
                .padding(.bottom, ResultMetrics.cardGap)
                // Своя высота: рамка по центру не растягивает карточки.
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                // iPad: блок по центру высоты, а не прижат к верху.
                .frame(minHeight: usesPadLayout ? viewport.height : nil, alignment: .center)
            }
            // На 393 всё помещается и ничего не должно пружинить; прокрутка
            // нужна только на малых экранах и при крупном шрифте.
            .seaScroll()

            actions
                .environment(\.bottomChrome, chrome)
                // Квадраты — по углам экрана, док и колонка — под карточками.
                .frame(maxWidth: chrome == .tiles ? .infinity : cardsWidth)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { actionsHeight = $0 }
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

    private var cards: some View {
        VStack(spacing: ResultMetrics.cardGap) {
            outcomeCard
            // Вдвоём баллов нет — вместо чека счёт серии (4.9).
            if let duel = result.duel {
                seriesCard(duel)
            } else {
                pointsCard
            }
            summaryCard
            if let level = result.level, let record = result.levelRecord {
                levelCard(level, record)
            }
        }
    }

    // MARK: iPad — одно поле

    /// Карточки тянутся по высоте, чтобы их низ совпал с низом блока поля.
    private var stretchesCards: Bool { usesPadLayout && boards != nil }

    /// Поле того же размера, что на столе в этой ориентации: та же клетка и
    /// тот же зазор (заказчик 13.10).
    private var tableMetrics: BoardMetrics {
        let size = CGSize(width: screen.width,
                          height: screen.height + safeArea.top + safeArea.bottom)
        let g = PadTableGeometry(size: size, safeTop: safeArea.top, safeBottom: safeArea.bottom)
        return BoardMetrics(cell: g.cell, gap: PadTableGeometry.gap)
    }

    /// Одна композиция на обе ориентации, поле справа, низ всего вровень:
    /// вертикально результат во всю ширину, под ним карточки столбиком слева
    /// от поля; горизонтально слева результат, под ним баллы и «Как шла
    /// партия» парой, ниже уровень, справа поле. Карточки растягиваются до
    /// высоты блока «поле + переключатель».
    @ViewBuilder
    private func padLayout(_ boards: ResultBoards) -> some View {
        let gap = ResultMetrics.cardGap
        let boardBlock = singleBoardBlock(boards)
        if boardsBeside {
            HStack(alignment: .top, spacing: ResultMetrics.boardsGap) {
                StretchColumn(spacing: gap) {
                    outcomeCard
                    HStack(alignment: .top, spacing: gap) {
                        moneyCard
                        summaryCard
                    }
                    levelCardIfAny
                }
                boardBlock
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(spacing: ResultMetrics.boardsGap) {
                outcomeCard
                HStack(alignment: .top, spacing: ResultMetrics.boardsGap) {
                    StretchColumn(spacing: gap) {
                        moneyCard
                        summaryCard
                        levelCardIfAny
                    }
                    boardBlock
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func singleBoardBlock(_ boards: ResultBoards) -> some View {
        let metrics = tableMetrics
        // Переключатель под полем, шириной в поле, — там же, где он в бою на
        // iPhone (заказчик 13.10).
        return VStack(spacing: ResultBoards.captionGap + 4) {
            BoardView(cells: shownBoard == .you ? boards.own : boards.foe, role: shownBoard,
                      metrics: metrics)
                .allowsHitTesting(false)
                .id(shownBoard)
                .transition(.opacity)
            FieldSwitch(selection: shownBoard) { side in
                withAnimation(Motion.quick.reduced(reduceMotion)) { shownBoard = side }
            }
            .frame(width: metrics.boardSide)
        }
        .fixedSize()
    }

    /// Баллы, а вдвоём — счёт серии.
    @ViewBuilder
    private var moneyCard: some View {
        if let duel = result.duel {
            seriesCard(duel)
        } else {
            pointsCard
        }
    }

    @ViewBuilder
    private var levelCardIfAny: some View {
        if let level = result.level, let record = result.levelRecord {
            levelCard(level, record)
        }
    }

    // MARK: Результат и счёт по флотам

    /// «Режим · уровень» (4.9); у игры на бумаге и сетевых режимов уровня нет —
    /// только режим, вдвоём — имя победителя и режим.
    private var subtitle: Text {
        if let duel = result.duel {
            Text("\(duel.winnerPlayer.name) · \(Text("Two players on one device"))")
        } else if let level = result.level {
            Text("\(Text("Single player")) · \(Text(LevelChoice.title(for: level)))")
        } else {
            switch result.key {
            case .nearby: Text("Nearby, no internet")
            case .online: Text("Online")
            default: Text("Paper game")
            }
        }
    }

    private var outcomeCard: some View {
        VStack(spacing: ResultMetrics.frameGap) {
            if let duel = result.duel {
                AvatarDot(glyph: duel.winnerPlayer.glyph, colorIndex: duel.winnerPlayer.colorIndex,
                          size: ResultMetrics.duelAvatar)
            }
            Text(result.didWin ? "Victory" : "Defeat")
                .font(.scalable(size: ResultMetrics.word, weight: .bold, design: .rounded))
                .tracking(ResultMetrics.wordTracking)
                .foregroundStyle(Color.inkPrimary)
                .accessibilityAddTraits(.isHeader)

            subtitle
                .font(.scalable(size: ResultMetrics.subtitle))
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)

            // Цвета как в бою: тёплое — ваш флот (сколько потеряли),
            // холодное — флот соперника (сколько потопили). Своё слева, как
            // в панели счёта (4.9; наоборот было ошибкой макета тура 10).
            // На AX1–AX5 — друг под другом: «10 / 10» в половине ширины
            // переносилось посередине.
            AdaptiveRow(spacing: ResultMetrics.scoreColumnsGap,
                                  accessibilitySpacing: ResultMetrics.scoreTop) {
                fleetScore(result.yourLosses, label: "you lost", color: .roleYou)
                if !dynamicTypeSize.isAccessibilitySize {
                    Rectangle()
                        .fill(Color.glassStroke)
                        .frame(width: 1)
                }
                fleetScore(result.foeLosses, label: "you sank", color: .roleFoe)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, ResultMetrics.scoreTop)
            .overlay(alignment: .top) { divider }
        }
        .frame(maxWidth: .infinity)
        .padding(ResultMetrics.framePadding)
        .frame(maxHeight: stretchesCards ? .infinity : nil)
        .glassPanel(.g2, radius: ResultMetrics.frameRadius,
                    highlight: .outcome(result.didWin ? .you : .foe))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("resultOutcome")
    }

    private func fleetScore(_ count: Int, label: LocalizedStringKey, color: Color) -> some View {
        VStack(spacing: ResultMetrics.scoreLabelGap) {
            Text(verbatim: "\(count) / \(result.fleetSize)")
                .font(.scalable(size: ResultMetrics.scoreValue, weight: .bold, design: .rounded)
                        .monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.scalable(size: ResultMetrics.scoreLabel))
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Начисление чеком

    private var pointsCard: some View {
        VStack(alignment: .leading, spacing: ResultMetrics.cardInnerGap) {
            HStack(spacing: ResultMetrics.pointsHeaderGap) {
                ScaledSymbol(name: PointsSymbol.name, box: ResultMetrics.pointsIcon)
                    .foregroundStyle(Color.roleYou)
                PointsCounter(value: counted)
                    .foregroundStyle(Color.inkPrimary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text.signedPoints(result.net))

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
                ScaledSymbol(name: PointsSymbol.name, box: ResultMetrics.totalIcon)
                Text("Balance now: \(result.balance) points")
                    .font(.scalable(size: ResultMetrics.totalText))
            }
            .foregroundStyle(Color.inkSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, ResultMetrics.totalTop)
            .overlay(alignment: .top) { divider }
            .accessibilityElement(children: .combine)
        }
        .padding(ResultMetrics.cardPadding)
        .frame(maxHeight: stretchesCards ? .infinity : nil)
        .glassPanel(.g2, radius: ResultMetrics.cardRadius)
        .accessibilityIdentifier("resultPoints")
    }

    // MARK: Счёт серии

    /// Вдвоём на устройстве (R3.2): счёт серии вместо начисления — баллов в
    /// режиме нет, а серия живёт, пока играют «Ещё партию» (4.9).
    private func seriesCard(_ duel: DuelSummary) -> some View {
        VStack(alignment: .leading, spacing: ResultMetrics.cardInnerGap) {
            Text("This series")
                .font(.scalable(size: ResultMetrics.capLabel, weight: .bold))
                .tracking(ResultMetrics.capTracking)
                .textCase(.uppercase)
                .foregroundStyle(Color.inkSecondary)

            HStack(spacing: ResultMetrics.scoreColumnsGap) {
                seriesColumn(duel, 0)
                Rectangle()
                    .fill(Color.glassStroke)
                    .frame(width: 1)
                seriesColumn(duel, 1)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(ResultMetrics.cardPadding)
        .frame(maxHeight: stretchesCards ? .infinity : nil)
        .glassPanel(.g2, radius: ResultMetrics.cardRadius)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("resultSeries")
    }

    private func seriesColumn(_ duel: DuelSummary, _ index: Int) -> some View {
        let player = duel.players[index]
        return HStack(spacing: 10) {
            AvatarDot(glyph: player.glyph, colorIndex: player.colorIndex,
                      size: ResultMetrics.seriesAvatar)
            Text(player.name)
                .font(.scalable(size: ResultMetrics.rowText, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(verbatim: "\(duel.series[index])")
                .font(.scalable(size: ResultMetrics.scoreValue, weight: .bold, design: .rounded)
                        .monospacedDigit())
                .foregroundStyle(PlayerAvatar.color(player.colorIndex))
        }
        .frame(maxWidth: .infinity)
    }

    private func pointRow(_ line: PointLine) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Group {
                switch line {
                case .victory: Text("Victory")
                case .quickWin: Text("Under \(StatKey.quickWinShots) shots ×2")
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
        .font(.scalable(size: ResultMetrics.rowText))
        .accessibilityElement(children: .combine)
    }

    // MARK: Как шла партия

    private var summaryCard: some View {
        let tally = result.tally
        return VStack(alignment: .leading, spacing: ResultMetrics.cardInnerGap) {
            Text("How the match went")
                .font(.scalable(size: ResultMetrics.capLabel, weight: .bold))
                .tracking(ResultMetrics.capTracking)
                .textCase(.uppercase)
                .foregroundStyle(Color.inkSecondary)

            AdaptiveRow(spacing: ResultMetrics.metricsGap,
                                  accessibilitySpacing: ResultMetrics.rowsTop) {
                metric("shots", value: Text(verbatim: "\(tally.shots)"))
                metric("accuracy", value: accuracyText(tally.accuracy))
            }
            AdaptiveRow(spacing: ResultMetrics.metricsGap,
                                  accessibilitySpacing: ResultMetrics.rowsTop) {
                metric("best streak", value: Text(verbatim: "\(tally.bestStreak)"))
                // Вдвоём подсказок нет — на их месте число ходов партии.
                if let duel = result.duel {
                    metric("turns", value: Text(verbatim: "\(duel.turns)"))
                } else {
                    metric("hints", value: Text(verbatim: "\(tally.hintsUsed)"))
                }
            }
            .padding(.top, ResultMetrics.rowsTop)
            .overlay(alignment: .top) { divider }
        }
        .padding(ResultMetrics.cardPadding)
        .frame(maxHeight: stretchesCards ? .infinity : nil)
        .glassPanel(.g2, radius: ResultMetrics.cardRadius)
        .accessibilityIdentifier("resultSummary")
    }

    private func metric(_ label: LocalizedStringKey, value: Text) -> some View {
        VStack(alignment: .leading, spacing: ResultMetrics.metricLabelGap) {
            value
                .font(.scalable(size: ResultMetrics.metricValue, weight: .bold, design: .rounded)
                        .monospacedDigit())
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.scalable(size: ResultMetrics.metricLabel))
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Все партии на уровне

    /// Одиночная игра (заказчик, 07.10): все партии на уровне этой партии —
    /// победы, поражения и доля побед. Одной строкой, а не полосой из
    /// статистики: с полосой итоги переставали помещаться на экран.
    private func levelCard(_ level: AppState.DifficultyLevel, _ record: StatRecord) -> some View {
        AdaptiveRow(spacing: ResultMetrics.metricsGap, accessibilitySpacing: ResultMetrics.rowGap) {
            VStack(alignment: .leading, spacing: ResultMetrics.metricLabelGap + 3) {
                Text("All games · \(Text(LevelChoice.title(for: level)))")
                    .font(.scalable(size: ResultMetrics.capLabel, weight: .bold))
                    .tracking(ResultMetrics.capTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.inkSecondary)
                Text("\(Text("\(record.wins) wins")) · \(Text("\(record.losses) losses"))")
                    .font(.scalable(size: ResultMetrics.rowText))
                    .monospacedDigit()
                    .foregroundStyle(Color.inkPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: record.winShare.map { StatBar.percent($0) } ?? "—")
                .font(.scalable(size: ResultMetrics.metricValue, weight: .bold, design: .rounded)
                        .monospacedDigit())
                .foregroundStyle(Color.roleYou)
        }
        .padding(ResultMetrics.cardPadding)
        .frame(maxHeight: stretchesCards ? .infinity : nil)
        .glassPanel(.g2, radius: ResultMetrics.cardRadius)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("resultLevelStats")
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

    /// Вынесено из кнопки: тернарный оператор внутри `Text` в `Button`
    /// ломает инструментирование превью (сборка при этом проходит).
    private var playAgainTitle: LocalizedStringKey {
        result.didWin ? "Play again" : "Rematch"
    }

    @ViewBuilder
    private var actions: some View {
        switch chrome {
        case .dock, .tiles:
            // Тот же низ, что на всех экранах партии: «Меню» слева, главная
            // рядом (док iPhone) или квадратом в правом углу (iPad). «Сыграть
            // ещё» ложится туда же, где на следующем экране «Начать»: повтор —
            // два касания в одно место. Над доком — ряд второстепенных, в нём
            // есть место для будущих («история ходов» и т. п.). На iPad вместо
            // «Посмотреть поля» поля стоят прямо на итогах.
            BottomStack(onMenu: onMenu) {
                if let onReview, boards == nil, chrome == .dock {
                    HStack(spacing: Geometry.Nav.stackGap) {
                        reviewButton(onReview)
                    }
                }
                playAgainButton
            }
        case .legacy:
            VStack(spacing: Geometry.Nav.stackGap) {
                AdaptiveRow(spacing: Geometry.Nav.stackGap, accessibilitySpacing: Geometry.Nav.stackGap) {
                    if let onReview, boards == nil { reviewButton(onReview) }
                    Button { onMenu() } label: {
                        Label("To menu", systemImage: "line.3.horizontal")
                    }
                    .secondaryButton()
                    .accessibilityIdentifier("resultMenu")
                }
                playAgainButton
            }
            .padding(.horizontal, Geometry.Nav.stackInset)
            .padBottomFrame()
        }
    }

    private var playAgainButton: some View {
        Button { onPlayAgain() } label: {
            Text(playAgainTitle)
        }
        .primaryButton()
        .accessibilityIdentifier("resultPlayAgain")
    }

    /// Поля после партии (решение заказчика 05.10): посмотреть, где стоял
    /// флот противника и чем кончился последний выстрел.
    private func reviewButton(_ action: @escaping () -> Void) -> some View {
        Button { action() } label: {
            Label("View boards", systemImage: "square.grid.3x3")
        }
        .secondaryButton()
        .accessibilityIdentifier("resultReview")
    }
}

/// Оба поля партии для итогов iPad: своё и поле противника — у компьютера и
/// вдвоём с открытым флотом (видно, где стояли непотопленные корабли).
struct ResultBoards: Equatable {
    let own: [BoardCellState]
    let foe: [BoardCellState]

    init(own: [BoardCellState], foe: [BoardCellState]) {
        self.own = own
        self.foe = foe
    }

    init(own: Board, foe: Board) {
        self.own = Board.allCoordinates.map { BoardCellState.forDisplay(own[$0], on: .you) }
        self.foe = Board.allCoordinates.map { BoardCellState.forDisplay(foe[$0], on: .foe) }
    }

    /// Между полем и переключателем под ним.
    static let captionGap: CGFloat = 8
}

// MARK: - Столбик карточек по высоте поля

/// Столбик карточек, растянутый до предложенной высоты: прибавка делится
/// пропорционально собственной высоте карточек — однострочная карточка уровня
/// не раздувается, а большие получают больше воздуха (варианты 13.10).
struct StretchColumn: Layout {
    var spacing: CGFloat

    private func heights(_ width: CGFloat?, _ subviews: Subviews) -> [CGFloat] {
        subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width
            ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let natural = heights(width, subviews).reduce(0, +)
            + spacing * CGFloat(max(0, subviews.count - 1))
        return CGSize(width: width, height: max(natural, proposal.height ?? natural))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews,
                       cache: inout ()) {
        let own = heights(bounds.width, subviews)
        let sum = own.reduce(0, +)
        let extra = max(0, bounds.height - sum - spacing * CGFloat(max(0, subviews.count - 1)))
        var y = bounds.minY
        for (subview, height) in zip(subviews, own) {
            let grown = height + (sum > 0 ? extra * height / sum : 0)
            subview.place(at: CGPoint(x: bounds.minX, y: y), anchor: .topLeading,
                          proposal: ProposedViewSize(width: bounds.width, height: grown))
            y += grown + spacing
        }
    }
}

// MARK: - Счётчик баллов

/// Баллы досчитываются от нуля за `Motion.pointsCounter`: анимируется само
/// число, а не смена цифр, поэтому это `Animatable`, а не `numericText`.
extension Text {
    /// «+60 points», «−5 points»: знак отдельным аргументом, число — целым,
    /// чтобы каталог склонял слово по числу («+1 балл», «+5 баллов»).
    static func signedPoints(_ value: Int) -> Text {
        let sign = value > 0 ? "+" : value < 0 ? "\u{2212}" : ""
        return Text("\(sign)\(abs(value)) points")
    }
}

private struct PointsCounter: View, Animatable {
    var value: Double

    nonisolated var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text.signedPoints(Int(value.rounded()))
            .font(.scalable(size: ResultMetrics.pointsValue, weight: .bold, design: .rounded)
                    .monospacedDigit())
    }
}

// MARK: - Переход к итогам

extension View {
    /// Бой → итоги (14c) поверх экрана партии: пауза на поле, поля в
    /// размытие, итоги слоем сверху. Одно на бой против компьютера и игру на
    /// бумаге — у обеих партий переход одинаковый.
    ///
    /// `prepareReview` — переключить экран на поле, которое «Посмотреть поля»
    /// открывает первым: обычно поле противника — смотрят, где стоял чужой
    /// флот (заказчик, 07.10); игра на бумаге передаёт своё.
    ///
    /// `boards` — оба поля для итогов iPad (читаются, когда итоги
    /// показываются); на iPhone не нужны — там «Посмотреть поля».
    func matchResults(_ result: MatchResult?,
                      onPlayAgain: @escaping () -> Void,
                      onMenu: @escaping () -> Void,
                      prepareReview: @escaping () -> Void = {},
                      boards: @escaping () -> ResultBoards? = { nil }) -> some View {
        modifier(MatchResultsModifier(result: result, onPlayAgain: onPlayAgain, onMenu: onMenu,
                                      prepareReview: prepareReview, boards: boards))
    }
}

extension MatchResult {
    /// Статус в панели счёта после партии — вместо «Ваш ход», который после
    /// последнего выстрела врал бы (виден в просмотре полей).
    static func statusText(_ result: MatchResult) -> Text {
        Text(result.didWin ? "Victory" : "Defeat")
    }
}

/// Просмотр полей после партии: итоги убраны, поля снова видны, и вернуть
/// итоги можно кнопкой на месте подсказки (`ReviewResultsButton`). Приходит
/// в экран партии окружением от `matchResults`; `nil` — партия идёт или на
/// экране итоги.
struct MatchReview {
    let backToResults: () -> Void
}

/// Последний выстрел партии: поле, по которому он пришёлся, вспыхивает
/// (`BoardFinale`) — видно, что выстрел финальный (решение заказчика 05.10,
/// вместо плашки). Ставит `matchResults` на время паузы перед итогами.
struct MatchFinale: Equatable {
    /// Когда пришёл итог — то есть момент последнего выстрела.
    let start: Date
    /// Победа — латунь, поражение — лазурь, как рамка исхода на итогах.
    let didWin: Bool
}

extension EnvironmentValues {
    @Entry var matchReview: MatchReview? = nil
    @Entry var matchFinale: MatchFinale? = nil
}

private struct MatchResultsModifier: ViewModifier {
    let result: MatchResult?
    let onPlayAgain: () -> Void
    let onMenu: () -> Void
    let prepareReview: () -> Void
    let boards: () -> ResultBoards?

    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.usesPadLayout) private var usesPadLayout
    /// Поля ушли в размытие под итоги.
    @State private var fieldsHidden = false
    /// Итоги на экране. Ставятся не сразу с итогом, а после паузы
    /// `Motion.lastShotHold`: последний выстрел должен доиграть на поле, иначе
    /// игрок не видит, чем кончилась партия (решение заказчика 05.10).
    @State private var showsResults = false
    /// Игрок вышел из итогов посмотреть поля.
    @State private var reviewing = false
    /// Вспышка поля на последнем выстреле: без неё игрок видел потопленный
    /// корабль и пытался стрелять дальше (решение заказчика 05.10).
    @State private var finale: MatchFinale?

    private var half: Double { Motion.scaled(Motion.toResults, reduceMotion: reduceMotion) / 2 }
    private var fade: Animation { .easeInOut(duration: half) }

    func body(content: Content) -> some View {
        content
            // Прозрачность до нуля, чтобы под итогами было одно море, как в
            // кадре.
            .blur(radius: fieldsHidden ? ResultMetrics.fieldsBlur : 0)
            .opacity(fieldsHidden ? 0 : 1)
            // Пока доигрывает последний выстрел и пока видны итоги, поля не
            // нажимаются; в просмотре — да: переключатель, «Меню», «Итоги».
            .allowsHitTesting(result == nil || reviewing)
            // Под итогами поля невидимы — и для VoiceOver тоже.
            .accessibilityHidden(fieldsHidden)
            .environment(\.matchReview, reviewing ? MatchReview(backToResults: { backToResults() }) : nil)
            .environment(\.matchFinale, finale)
            .overlay { overlay }
            .task(id: result) { await present() }
    }

    @ViewBuilder
    private var overlay: some View {
        if showsResults, let result {
            // Колонку карточек на iPad ставит сам экран: поля рядом шире её.
            ResultsScreen(result: result, onPlayAgain: onPlayAgain, onMenu: onMenu,
                          onReview: review, boards: usesPadLayout ? boards() : nil)
                .transition(.opacity)
        }
    }

    /// Итог пришёл — дать доиграть выстрелу, увести поля и показать экран;
    /// ушёл (новая партия) — всё убрать. `task(id:)` обрывает ожидание, если
    /// итог сменился раньше.
    private func present() async {
        guard let result else {
            fieldsHidden = false
            showsResults = false
            reviewing = false
            finale = nil
            return
        }
        // Поле вспыхивает само по часам от `start` (`BoardFinale`); звук и
        // вибрация победы — в момент вспышки.
        finale = MatchFinale(start: .now, didWin: result.didWin)
        let delay = Motion.scaled(Motion.finaleDelay, reduceMotion: reduceMotion)
        try? await Task.sleep(for: .seconds(delay))
        guard !Task.isCancelled else { return }
        HapticService.shared.play(result.didWin ? .victory : .defeat)
        if appState.soundOn {
            AppState.playSound(sound: result.didWin ? "victory_sound.wav" : "defeat_sound.wav")
        }
        try? await Task.sleep(for: .seconds(Motion.scaled(Motion.lastShotHold,
                                                          reduceMotion: reduceMotion) - delay))
        guard !Task.isCancelled else { return }
        withAnimation(fade) { fieldsHidden = true }
        try? await Task.sleep(for: .seconds(half))
        guard !Task.isCancelled else { return }
        showsResults = true
    }

    private func review() {
        // Поле меняется, пока итоги ещё закрывают экран.
        prepareReview()
        withAnimation(fade) {
            showsResults = false
            fieldsHidden = false
            reviewing = true
            // В просмотре поля без вспышки — она уже отыграла.
            finale = nil
        }
    }

    private func backToResults() {
        withAnimation(fade) {
            reviewing = false
            fieldsHidden = true
            showsResults = true
        }
    }
}

// MARK: - Превью

private struct ResultsDemo: View {
    let result: MatchResult

    var body: some View {
        ZStack {
            SeaBackground()
                .ignoresSafeArea()
            // С «Посмотреть поля», как после настоящей партии.
            ResultsScreen(result: result, onReview: {})
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
        tally: ResultsDemo.tally(hits: 20, misses: 43, streak: 4, hints: 1, cost: 5),
        balance: 126, levelRecord: StatRecord(wins: 9, losses: 13)))
        .preferredColorScheme(.dark)
}

#Preview("Итоги · поражение") {
    ResultsDemo(result: MatchResult(
        didWin: false, level: .medium, yourLosses: 10, foeLosses: 7,
        tally: ResultsDemo.tally(hits: 17, misses: 41, streak: 3, hints: 1, cost: 3),
        balance: 76, levelRecord: StatRecord(wins: 21, losses: 11)))
        .preferredColorScheme(.dark)
}

#Preview("Итоги · победа · светлая") {
    ResultsDemo(result: MatchResult(
        didWin: true, level: .expert, yourLosses: 6, foeLosses: 10,
        // 49 выстрелов — быстрая победа, в чеке строка «×2».
        tally: ResultsDemo.tally(hits: 20, misses: 29, streak: 5, hints: 0, cost: 10),
        balance: 240, levelRecord: StatRecord(wins: 4, losses: 7)))
        .preferredColorScheme(.light)
}

private enum PadResultsSample {
    /// Поражение на «Среднем»: свой флот потоплен целиком, у противника
    /// потоплено 7 из 10, остальные три корабля видны открытыми.
    static let result: MatchResult = {
        var tally = MatchTally()
        for _ in 0..<3 { tally.record(.hit(shipID: nil)) }
        for _ in 0..<14 {
            tally.record(.miss)
            tally.record(.hit(shipID: nil))
        }
        for _ in 0..<27 { tally.record(.miss) }
        tally.recordHint(cost: 3)
        return MatchResult(didWin: false, level: .medium, yourLosses: 10, foeLosses: 7,
                           tally: tally, balance: 76,
                           levelRecord: StatRecord(wins: 21, losses: 11))
    }()

    static let boards: ResultBoards = {
        var own = Board(ships: FleetLayout.canonicalLayout())
        for ship in FleetLayout.canonicalLayout() {
            for cell in ship.cells { _ = own.apply(shotAt: cell) }
        }
        var foe = Board.randomFleet()
        let ships = Board.allCoordinates.compactMap { foe.ship(at: $0) }
        var seen: [ShipPlacement] = []
        for ship in ships where !seen.contains(ship) { seen.append(ship) }
        for ship in seen.prefix(7) {
            for cell in ship.cells { _ = foe.apply(shotAt: cell) }
        }
        var misses = 0
        for cell in Board.allCoordinates where misses < 30 && foe[cell] == .water {
            if (cell.row * 7 + cell.column * 3) % 4 == 0 {
                _ = foe.apply(shotAt: cell)
                misses += 1
            }
        }
        for cell in Board.allCoordinates where own[cell] == .water
            && (cell.row * 5 + cell.column) % 3 == 0 {
            _ = own.apply(shotAt: cell)
        }
        return ResultBoards(own: own, foe: foe)
    }()
}

/// iPad: поражение на «Среднем» — одно поле размером как на столе, под ним
/// переключатель.
private struct PadResultsDemo: View {
    var mirrored = false

    var body: some View {
        ZStack {
            SeaBackground()
                .ignoresSafeArea()
            ResultsScreen(result: PadResultsSample.result, onReview: {},
                          boards: PadResultsSample.boards)
        }
        .environment(\.usesPadLayout, true)
        .environment(\.mirrorsBottomTiles, mirrored)
        .preferredColorScheme(.dark)
    }
}

struct ResultsScreenPadPreview1: PreviewProvider {
    static var previews: some View {
        PadResultsDemo()
            .padPreview(.portrait, "Итоги · iPad · вертикально")
    }
}

struct ResultsScreenPadPreview2: PreviewProvider {
    static var previews: some View {
        PadResultsDemo()
            .padPreview(.landscapeLeft, "Итоги · iPad · горизонтально")
    }
}

struct ResultsScreenPadPreview3: PreviewProvider {
    static var previews: some View {
        PadResultsDemo(mirrored: true)
            .padPreview(.landscapeLeft, "Итоги · iPad · своё поле справа")
    }
}
