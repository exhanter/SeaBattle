//
//  BattleScreen.swift
//  Sea Battle — бой против компьютера (R2.3, шаг 9 порядка сборки)
//
//  Спека 4.5. Верх — `ScorePanel`, центр — поле, низ — `BottomStack`:
//  переключатель полей с подсказкой и `NavRow` последней строкой. Заголовка
//  `ScreenTitle` и строки возврата в бою нет — выход только через «Меню».
//
//  Поле противника — экран стрельбы, своё поле — экран показа: по клеткам не
//  нажимают, подсказки нет, есть лента «По вам за этот раунд».
//
//  Анимации клетки (всплеск, подсветка контура, волна потопления) рисует
//  `BoardView` по последнему событию из `BattleController` (R2.4).
//

import SwiftUI

// MARK: - Числа экрана

enum BattleScreenMetrics {
    /// Между подписью поля и полем.
    static let captionGap: CGFloat = 10
    /// Строка подписи: капсула уровня не выше её, поэтому поле от капсулы не
    /// сдвигается (4.5).
    static let captionHeight: CGFloat = 22
    /// Под панелью счёта — от безопасной зоны.
    static let scoreTop: CGFloat = 4
    /// Минимальный зазор над полем.
    static let minGap: CGFloat = 10

    /// Верх поля от верха области между панелью счёта и низом экрана.
    ///
    /// **Одна высота на оба поля** (2.8 после раунда 5): поле считается так,
    /// будто лента под ним есть всегда, и стоит посередине оставшегося места.
    /// На поле противника ленты нет, а поле остаётся там же — при
    /// переключении оно не прыгает. Пустого блока под несуществующую ленту
    /// при этом нет: место просто не занято.
    static func boardTop(available: CGFloat, board: CGFloat, feed: CGFloat) -> CGFloat {
        max(minGap, ((available - board - feed) / 2).rounded())
    }

    /// Верх самого поля (без подписи) от верха безопасной зоны в бою iPhone:
    /// панель счёта, место между ней и доком, подпись. По нему расстановка
    /// ставит своё поле, чтобы по «Начать» поле не прыгало (заказчик, 07.10).
    static func boardY(height: CGFloat, scorePanel: CGFloat, board: CGFloat) -> CGFloat {
        let above = scoreTop + scorePanel
        // Низ боя — один ряд в доке: переключатель полей и подсказка.
        let below = Geometry.Bottom.dockHeight + Geometry.Nav.stackBottom
        let caption = captionHeight + captionGap
        let top = boardTop(available: height - above - below, board: caption + board,
                           feed: ShotFeed.height + Geometry.Nav.stackGap)
        return above + top + caption
    }
}

// MARK: - Прицел

/// Спека 2.18, макет 18b: обводка `Role/You` толщиной 7 % клетки (не меньше
/// 1,5 pt), по краю и радиусу клетки; мягкое свечение `Role/YouSoft`
/// радиусом 50 % клетки.
enum AimMetrics {
    static let strokeRatio: CGFloat = 0.07
    static let minStroke: CGFloat = 1.5
    /// 0, а не 1 pt из спеки (06.10): в зазор выглядывала кромка клетки —
    /// светлая сверху, тёмная снизу, — и рамка казалась сдвинутой.
    static let insetIntoCell: CGFloat = 0
    static let glowRatio: CGFloat = 0.5
    /// Гаснет за 60 мс в момент выстрела (правило 4).
    static let fadeOut: Double = 0.060

    static func stroke(for cell: CGFloat) -> CGFloat {
        max(minStroke, cell * strokeRatio)
    }
}

// MARK: - Экран

struct BattleScreen: View {

    let battle: BattleController
    /// Выйти в меню. Вопрос «Выйти из партии?» задаёт сам экран.
    var onLeave: () -> Void = {}
    /// «Завершить партию» в окне выхода: партия удаляется без результата.
    var onEnd: () -> Void = {}
    /// Кнопки итогов: «Ещё партия» / «Отыграться» и «В меню».
    var onPlayAgain: () -> Void = {}
    var onMenuAfterResult: () -> Void = {}

    @Environment(AppState.self) private var appState
    @Environment(\.locale) private var locale
    @Environment(\.usesPadLayout) private var usesPadLayout
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var askLeave = false

    private var alphabet: BoardAlphabet {
        .forLanguage(locale.language.languageCode?.identifier)
    }

    var body: some View {
        Group {
            if usesPadLayout {
                // iPad: оба поля сразу, без переключателя (R2.6).
                PadTableScreen(phase: .battle(battle), onMenu: menuTapped)
            } else {
                phone
            }
        }
        .battleTypeSize()
        .matchResults(battle.result, onPlayAgain: onPlayAgain, onMenu: onMenuAfterResult,
                      prepareReview: { battle.show(.foe) })
        .modalDialog(isPresented: askLeave) {
            LeaveMatchDialog(onStay: { askLeave = false },
                             onLeave: {
                                 askLeave = false
                                 onLeave()
                             },
                             onEnd: {
                                 askLeave = false
                                 onEnd()
                             })
        }
        .animation(Motion.quick.reduced(reduceMotion), value: battle.shownField)
    }

    /// iPhone: одно поле на экране, переключатель полей внизу.
    private var phone: some View {
        GeometryReader { proxy in
            let size = Geometry.SizeClass.forWidth(proxy.size.width)
            let metrics = BoardMetrics(cell: size.cell)
            let field = battle.shownField

            VStack(spacing: 0) {
                ScorePanel(yourLosses: battle.player.numberShipsDestroyed,
                           foeLosses: battle.enemy.numberShipsDestroyed,
                           isYourTurn: !appState.enemysTurn,
                           balance: ProgressStore.shared.points,
                           size: size,
                           status: battle.result.map(MatchResult.statusText))
                    .padding(.top, BattleScreenMetrics.scoreTop)

                GeometryReader { area in
                    let feed = ShotFeed.height + Geometry.Nav.stackGap
                    let boardBlock = BattleScreenMetrics.captionHeight
                        + BattleScreenMetrics.captionGap + metrics.totalSize.height
                    let top = BattleScreenMetrics.boardTop(available: area.size.height,
                                                          board: boardBlock, feed: feed)
                    VStack(spacing: 0) {
                        caption(field, size: size)
                            .padding(.bottom, BattleScreenMetrics.captionGap)
                        board(field, metrics)
                        Spacer(minLength: 0)
                        // Лента только на своём поле (2.8).
                        if field == .you {
                            ShotFeed(title: "Shots at you this round",
                                     entries: battle.incoming, alphabet: alphabet)
                                .padding(.horizontal, Geometry.Nav.stackInset)
                                .padding(.bottom, Geometry.Nav.stackGap)
                        }
                    }
                    .padding(.top, top)
                    .frame(width: area.size.width, height: area.size.height)
                }

                actions(field, size: size)
            }
        }
    }

    // MARK: Подпись поля

    private func caption(_ field: Side, size: Geometry.SizeClass) -> some View {
        HStack(spacing: LevelChip.gap(size)) {
            Text(field == .foe ? "Opponent's board" : "Your fleet")
                .font(.system(size: BattleMetrics.forSize(size).caption,
                              weight: .semibold, design: .rounded))
                .foregroundStyle(Color.inkPrimary)
                .shadow(color: .inkTitleShadow,
                        radius: NavMetrics.titleShadowRadius,
                        y: NavMetrics.titleShadowOffsetY)
                // Подпись поля — заголовок: VoiceOver прыгает по ним ротором, и
                // это единственное имя поля (у `BoardView` своего нет).
                .accessibilityAddTraits(.isHeader)
            // Уровень компьютера — только в одиночной игре и только на поле
            // противника (4.5). Не нажимается: посреди партии он не меняется.
            if field == .foe {
                LevelChip(level: appState.difficultyLevel, size: size)
            }
        }
        .frame(height: BattleScreenMetrics.captionHeight)
    }

    // MARK: Поле

    private func board(_ field: Side, _ m: BoardMetrics) -> some View {
        BattleBoard(battle: battle, field: field, metrics: m, alphabet: alphabet)
    }

    // MARK: Низ

    private func actions(_ field: Side, size: Geometry.SizeClass) -> some View {
        BottomStack(onMenu: { menuTapped() }) {
            HStack(spacing: Geometry.Nav.stackGap) {
                FieldSwitch(selection: field, size: size) { battle.show($0) }
                // Подсказка работает только на поле противника (2.9) и **без
                // Pro**: Pro открывает режимы, а не ход партии (решение
                // заказчика 29.09, спека 4.12). Стоит на обоих полях, на своём
                // погашена: иначе переключатель менял ширину при каждом
                // переключении (решение заказчика 05.10).
                ReviewSlot(size: size) {
                    BattleHintButton(cost: battle.hintCost,
                                     isEnabled: field == .foe && battle.canUseHint,
                                     size: size) { battle.requestHint() }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// «Меню» из идущей партии спрашивает подтверждение (3.1); после конца
    /// партии выходит сразу.
    private func menuTapped() {
        if appState.gameIsActive {
            askLeave = true
        } else {
            onLeave()
        }
    }
}

// MARK: - Боевое поле

/// Одно поле боя: клетки из доски (флот противника скрыт), рамка хода,
/// событие клетки, касание по полю противника, прицел и метки подсказки.
/// Одно на бой iPhone и на стол iPad — у стола оба поля видны сразу.
struct BattleBoard: View {
    let battle: BattleController
    let field: Side
    let metrics: BoardMetrics
    let alphabet: BoardAlphabet

    @Environment(AppState.self) private var appState

    private var m: BoardMetrics { metrics }

    var body: some View {
        let data = field == .foe ? battle.enemy : battle.player
        // Флот противника скрыт тем же способом, каким он скрыт от ИИ: из
        // `opponentView()` нетронутый корабль приходит водой. После партии
        // флот открыт — посмотреть, где он стоял (решение заказчика 05.10).
        let core = field == .foe && battle.result == nil
            ? data.coreBoard.opponentView() : data.coreBoard
        let cells = Board.allCoordinates.map { BoardCellState.forDisplay(core[$0], on: field) }
        // Свечение рамки — на поле, по которому сейчас стреляют (2.4).
        let isActive = appState.gameIsActive
            && (field == .foe ? !appState.enemysTurn : appState.enemysTurn)

        return BoardView(cells: cells, role: field, metrics: m, isActive: isActive,
                         alphabet: alphabet,
                         event: battle.event(on: field),
                         marks: field == .foe ? accessibilityMarks : [:],
                         onTap: field == .foe
                            ? { column, row in battle.tap(Coordinate(row: row + 1, column: column + 1)) }
                            : nil)
            .overlay(alignment: .topLeading) {
                if field == .foe {
                    marks
                        .frame(width: m.gridSide, height: m.gridSide, alignment: .topLeading)
                        .offset(x: m.inset, y: m.inset)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: m.totalSize.width, height: m.totalSize.height)
            .accessibilityIdentifier(field == .foe ? "foeBoard" : "yourBoard")
    }

    /// Те же метки, что рисует `marks`, — значением клеток для VoiceOver.
    private var accessibilityMarks: [Coordinate: BoardMark] {
        var result: [Coordinate: BoardMark] = [:]
        for cell in battle.hintCells where battle.enemy.coreBoard[cell].isUnshot {
            result[cell] = .hint
        }
        return result
    }

    /// Открытые подсказкой клетки — поверх сетки, как корабли на
    /// расстановке: у `BoardCell` таких состояний нет, это не правила.
    /// Клетка, по которой только что выстрелили, ещё держит метку — та
    /// уходит, пока клетка становится «ранен» или «убит».
    private var marks: some View {
        let unshot = Set(Board.allCoordinates.filter { battle.enemy.coreBoard[$0].isUnshot })
        let event = battle.event(on: .foe)
        return ZStack(alignment: .topLeading) {
            ForEach(Array(battle.hintCells.filter { unshot.contains($0) || $0 == event?.target }),
                    id: \.self) { cell in
                let origin = m.cellOrigin(cell)
                HintMark(cell: m.cell, shotAt: unshot.contains(cell) ? nil : event?.start)
                    .offset(x: origin.x, y: origin.y)
            }
        }
    }
}

/// Прицел на клетке (2.18) — слоем поверх сетки. Только в игре на бумаге: там
/// он значит «выстрел назван, ждём ответ». В остальных режимах касание сразу
/// стреляет — подтверждение выстрела убрано 06.10.
struct AimMark: View {
    let coordinate: Coordinate
    let metrics: BoardMetrics

    init(at coordinate: Coordinate, metrics: BoardMetrics) {
        self.coordinate = coordinate
        self.metrics = metrics
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let m = metrics
        let origin = m.cellOrigin(coordinate)
        let inset = AimMetrics.insetIntoCell
        RoundedRectangle(cornerRadius: max(0, Geometry.cellRadius(for: m.cell) - inset),
                         style: .continuous)
            .strokeBorder(Color.roleYou, lineWidth: AimMetrics.stroke(for: m.cell))
            .padding(inset)
            .shadow(color: .roleYouSoft, radius: m.cell * AimMetrics.glowRatio)
            .frame(width: m.cell, height: m.cell)
            .offset(x: origin.x, y: origin.y)
            // Для VoiceOver прицел — значение клетки (`BoardMark.aim`); сама
            // рамка иначе висела бы пустым элементом над клеткой.
            .accessibilityHidden(true)
            // Появляется за `Motion.aim`, гаснет за 60 мс и в анимации
            // выстрела не участвует.
            .transition(.asymmetric(
                insertion: .opacity.animation(.easeOut(duration: Motion.scaled(Motion.aim,
                                                                               reduceMotion: reduceMotion))),
                removal: .opacity.animation(.easeOut(duration: Motion.scaled(AimMetrics.fadeOut,
                                                                             reduceMotion: reduceMotion)))))
    }
}

// MARK: - Превью

private struct BattleDemo: View {
    @State private var appState = AppState()
    @State private var battle = BattleController(pacing: .instant)
    let field: Side
    let enemysTurn: Bool

    var body: some View {
        ZStack {
            SeaBackground()
                .ignoresSafeArea()
            BattleScreen(battle: battle)
        }
        .environment(appState)
        .onAppear {
            battle.configure(appState: appState)
            battle.player.place(FleetLayout.canonicalLayout())
            battle.enemy.shipsRandomArrangement()
            appState.gameIsActive = true
            appState.selectedTab = field == .you ? .playerView : .enemyView
            // Несколько выстрелов в обе стороны — чтобы на снимке были все
            // состояния клеток.
            for coordinate in [Coordinate(row: 1, column: 1), Coordinate(row: 5, column: 5),
                               Coordinate(row: 9, column: 3)] {
                var board = battle.enemy.coreBoard
                _ = board.apply(shotAt: coordinate)
                battle.enemy.apply(board)
                var own = battle.player.coreBoard
                _ = own.apply(shotAt: coordinate)
                battle.player.apply(own)
            }
            appState.enemysTurn = enemysTurn
        }
    }
}

#Preview("Бой · поле противника") {
    BattleDemo(field: .foe, enemysTurn: false)
        .preferredColorScheme(.dark)
}

/// Пара к «Расстановка · запрет · 375 × 667»: где поле стоит в бою на SE.
#Preview("Бой · 375 × 667", traits: .fixedLayout(width: 375, height: 667)) {
    BattleDemo(field: .foe, enemysTurn: false)
        .preferredColorScheme(.dark)
}

#Preview("Бой · своё поле") {
    BattleDemo(field: .you, enemysTurn: true)
        .preferredColorScheme(.dark)
}

/// Переход «бой → итоги» живьём: флот противника добивается сам, последний
/// выстрел — через полсекунды после появления.
private struct FinishDemo: View {
    @State private var appState = AppState()
    @State private var battle = BattleController(pacing: .instant)
    var pad = false

    var body: some View {
        ZStack {
            SeaBackground()
                .ignoresSafeArea()
            BattleScreen(battle: battle)
        }
        .environment(appState)
        .environment(\.usesPadLayout, pad)
        .task {
            appState.soundOn = false
            battle.configure(appState: appState)
            appState.resetData(player: battle.player, enemy: battle.enemy)
            battle.player.place(FleetLayout.canonicalLayout())
            battle.enemy.shipsRandomArrangement()
            appState.gameIsActive = true
            appState.selectedTab = .enemyView
            battle.beginMatch()
            let cells = battle.enemy.ships.flatMap { $0.coordinates.map(Coordinate.init) }
            cells.dropLast().forEach(battle.tap)
            try? await Task.sleep(for: .seconds(0.5))
            if let last = cells.last { battle.tap(last) }
        }
    }
}

#Preview("Бой → итоги") {
    FinishDemo()
        .preferredColorScheme(.dark)
}

/// Живой переход на столе iPad; сами итоги в колонке — превью «Итоги · iPad».
#Preview("Бой → итоги · iPad", traits: .fixedLayout(width: 1194, height: 834)) {
    FinishDemo(pad: true)
        .preferredColorScheme(.dark)
}

#Preview("Бой · светлая") {
    BattleDemo(field: .foe, enemysTurn: false)
        .preferredColorScheme(.light)
}
