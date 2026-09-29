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
//  Анимации клетки (всплеск, подсветка контура, волна потопления) — R2.4;
//  здесь достаточно смены состояния.
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
    /// Минимальные зазоры вокруг поля; остальное место делится поровну.
    static let minGap: CGFloat = 10
    /// Латунный контур прицела («выстрел назван, ждём ответ», спека 5).
    static let aimStroke: CGFloat = 2
    /// Метка подсказки — доля клетки.
    static let hintMark: CGFloat = 0.6
}

// MARK: - Экран

struct BattleScreen: View {

    let battle: BattleController
    let isPremium: Bool
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

                Spacer(minLength: BattleScreenMetrics.minGap)

                caption(field, size: size)
                    .padding(.bottom, BattleScreenMetrics.captionGap)
                board(field, metrics)

                Spacer(minLength: BattleScreenMetrics.minGap)

                // Слот ленты занят на обоих полях: иначе поле прыгало бы по
                // вертикали при каждом переключении. На поле противника ленты
                // в кадре `screen16Battle` нет — место просто пустое.
                Group {
                    if field == .you {
                        ShotFeed(title: "Shots at you this round", entries: battle.incoming,
                                 alphabet: alphabet)
                    } else {
                        Color.clear.frame(height: ShotFeed.height)
                    }
                }
                .padding(.horizontal, Geometry.Nav.stackInset)
                .padding(.bottom, Geometry.Nav.stackGap)

                actions(field, size: size)
            }
            .overlay { resultOverlay }
            .overlay { leaveDialog }
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
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.roleYou, lineWidth: BattleScreenMetrics.aimStroke)
                    .frame(width: m.cell, height: m.cell)
                    .offset(x: origin.x, y: origin.y)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: Motion.aim), value: battle.aim)
    }

    // MARK: Низ

    private func actions(_ field: Side, size: Geometry.SizeClass) -> some View {
        BottomStack(onMenu: { menuTapped() }) {
            HStack(spacing: Geometry.Nav.stackGap) {
                FieldSwitch(selection: field, size: size) { battle.show($0) }
                // Подсказка только у поля противника (2.9). ПЕРЕХОДНОЕ: пока
                // она по-прежнему часть Pro, как с фазы 6.
                if field == .foe && isPremium {
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
            withAnimation(Motion.quick) { askLeave = true }
        } else {
            onLeave()
        }
    }

    // MARK: Окно «Выйти из партии?»

    @ViewBuilder
    private var leaveDialog: some View {
        if askLeave {
            ZStack {
                // Перехват касаний: пока окно открыто, стрелять нельзя.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {}
                LeaveMatchDialog(
                    onStay: { withAnimation(Motion.quick) { askLeave = false } },
                    onLeave: {
                        askLeave = false
                        onLeave()
                    })
                    .padding(.horizontal, Geometry.Nav.titleInset)
            }
            .transition(.opacity)
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

// MARK: - Окно выхода

/// Окно G3 «Выйти из партии?» (спека 3.1): главная кнопка «Остаться»,
/// второстепенная «Выйти». Главная — остаться: случайное касание «Меню» не
/// должно стоить партии.
struct LeaveMatchDialog: View {
    var onStay: () -> Void = {}
    var onLeave: () -> Void = {}

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Leave the match?")
                    .font(TypeScale.headline)
                    .foregroundStyle(Color.inkPrimary)
                Text("The game is saved. Continue it from the menu.")
                    .font(TypeScale.footnote)
                    .foregroundStyle(Color.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: Geometry.Nav.stackGap) {
                Button {
                    onStay()
                } label: {
                    Text("Stay")
                }
                .primaryButton()
                .accessibilityIdentifier("leaveStay")

                Button {
                    onLeave()
                } label: {
                    Text("Leave")
                }
                .secondaryButton()
                .accessibilityIdentifier("leaveConfirm")
            }
        }
        .padding(20)
        .glassPanel(.g3, radius: Geometry.Radius.panelLarge)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
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
            BattleScreen(battle: battle, isPremium: true)
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

#Preview("Окно выхода") {
    ZStack {
        SeaBackground()
        LeaveMatchDialog()
            .padding(.horizontal, 20)
    }
    .preferredColorScheme(.dark)
}
