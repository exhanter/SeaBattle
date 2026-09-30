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
    /// Метка подсказки — доля клетки.
    static let hintMark: CGFloat = 0.6

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
}

// MARK: - Прицел

/// Спека 2.18, макет 18b: обводка `Role/You` толщиной 7 % клетки (не меньше
/// 1,5 pt), внутрь на 1 pt, по радиусу клетки; мягкое свечение `Role/YouSoft`
/// радиусом 50 % клетки.
enum AimMetrics {
    static let strokeRatio: CGFloat = 0.07
    static let minStroke: CGFloat = 1.5
    static let insetIntoCell: CGFloat = 1
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
    /// Кнопки итогов: «Ещё партия» / «Отыграться» и «В меню».
    var onPlayAgain: () -> Void = {}
    var onMenuAfterResult: () -> Void = {}

    @Environment(AppState.self) private var appState
    @Environment(\.locale) private var locale
    @Environment(\.usesPadLayout) private var usesPadLayout
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
        .matchResults(battle.result, onPlayAgain: onPlayAgain, onMenu: onMenuAfterResult)
        .modalDialog(isPresented: askLeave) {
            ModalDialog.leaveMatch(.offline,
                                   onStay: { askLeave = false },
                                   onLeave: {
                                       askLeave = false
                                       onLeave()
                                   })
        }
        .animation(Motion.quick, value: battle.shownField)
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
                           size: size)
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
                // Подсказка только у поля противника (2.9) и **без Pro**:
                // Pro открывает режимы, а не ход партии (решение заказчика
                // 29.09, спека 4.12).
                if field == .foe {
                    BattleHintButton(cost: battle.hintCost,
                                     isEnabled: battle.canUseHint,
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
        // `opponentView()` нетронутый корабль приходит водой.
        let core = field == .foe ? data.coreBoard.opponentView() : data.coreBoard
        let cells = Board.allCoordinates.map { BoardCellState.forDisplay(core[$0], on: field) }
        // Свечение рамки — на поле, по которому сейчас стреляют (2.4).
        let isActive = appState.gameIsActive
            && (field == .foe ? !appState.enemysTurn : appState.enemysTurn)

        return BoardView(cells: cells, role: field, metrics: m, isActive: isActive,
                         alphabet: alphabet,
                         event: battle.event(on: field),
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

    /// Прицел и открытые подсказкой клетки — поверх сетки, как корабли на
    /// расстановке: у `BoardCell` таких состояний нет, это не правила.
    private var marks: some View {
        let unshot = Set(Board.allCoordinates.filter { battle.enemy.coreBoard[$0].isUnshot })
        return ZStack(alignment: .topLeading) {
            ForEach(Array(battle.hintCells.filter { unshot.contains($0) }), id: \.self) { cell in
                let origin = m.cellOrigin(cell)
                Image(systemName: "target")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.roleYou)
                    .frame(width: m.cell * BattleScreenMetrics.hintMark,
                           height: m.cell * BattleScreenMetrics.hintMark)
                    .frame(width: m.cell, height: m.cell)
                    .offset(x: origin.x, y: origin.y)
            }
            if let aim = battle.aim {
                AimMark(at: aim, metrics: m)
            }
        }
    }
}

/// Прицел на клетке (2.18) — слоем поверх сетки. Один на бой и игру на бумаге,
/// где он значит «выстрел назван, ждём ответ».
struct AimMark: View {
    let coordinate: Coordinate
    let metrics: BoardMetrics

    init(at coordinate: Coordinate, metrics: BoardMetrics) {
        self.coordinate = coordinate
        self.metrics = metrics
    }

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
            // Появляется за `Motion.aim`, гаснет за 60 мс и в анимации
            // выстрела не участвует.
            .transition(.asymmetric(
                insertion: .opacity.animation(.easeOut(duration: Motion.aim)),
                removal: .opacity.animation(.easeOut(duration: AimMetrics.fadeOut))))
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
            appState.confirmShot = false
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
