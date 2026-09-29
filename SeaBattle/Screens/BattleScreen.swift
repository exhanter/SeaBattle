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
    /// ПЕРЕХОДНОЕ до R2.5: кнопки старого окна итогов.
    var onPlayAgain: () -> Void = {}
    var onMenuAfterResult: () -> Void = {}

    @Environment(AppState.self) private var appState
    @Environment(\.locale) private var locale
    @State private var askLeave = false

    private var alphabet: BoardAlphabet {
        .forLanguage(locale.language.languageCode?.identifier)
    }

    var body: some View {
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
            .overlay { resultOverlay }
            .modalDialog(isPresented: askLeave) {
                ModalDialog.leaveMatch(.offline,
                                       onStay: { askLeave = false },
                                       onLeave: {
                                           askLeave = false
                                           onLeave()
                                       })
            }
        }
        .animation(Motion.quick, value: battle.shownField)
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
                    marks(m)
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
    private func marks(_ m: BoardMetrics) -> some View {
        let radius = Geometry.cellRadius(for: m.cell)
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
                let origin = m.cellOrigin(aim)
                let inset = AimMetrics.insetIntoCell
                RoundedRectangle(cornerRadius: max(0, radius - inset), style: .continuous)
                    .strokeBorder(Color.roleYou, lineWidth: AimMetrics.stroke(for: m.cell))
                    .padding(inset)
                    .shadow(color: .roleYouSoft, radius: m.cell * AimMetrics.glowRatio)
                    .frame(width: m.cell, height: m.cell)
                    .offset(x: origin.x, y: origin.y)
                    // Появляется за `Motion.aim`, гаснет за 60 мс и в
                    // анимации выстрела не участвует.
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeOut(duration: Motion.aim)),
                        removal: .opacity.animation(.easeOut(duration: AimMetrics.fadeOut))))
            }
        }
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

    // MARK: ПЕРЕХОДНОЕ: итоги

    /// Старое окно победы и поражения — до своего экрана итогов в R2.5.
    @ViewBuilder
    private var resultOverlay: some View {
        if battle.enemy.showFinishGameAlert || battle.player.showFinishGameAlert {
            WinAlertView(didPlayerWin: battle.enemy.showFinishGameAlert,
                         onPlayAgain: onPlayAgain,
                         onMenu: onMenuAfterResult)
        }
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

#Preview("Бой · светлая") {
    BattleDemo(field: .foe, enemysTurn: false)
        .preferredColorScheme(.light)
}
