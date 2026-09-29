//
//  PadTableScreen.swift
//  Sea Battle — стол на два поля, iPad (R2.6, раунд 7)
//
//  Спека 4.4 «iPad» после раунда 7, кадры 21a (`screen21Port`) и 21c
//  (`screen21Land` с равными отступами). Отдельного экрана расстановки нет:
//  партия открывается сразу двумя полями — своё с авторасставленным флотом и
//  пустое поле противника (приглушено). «Изменить» правит флот на том же
//  столе; «Начать» — бой на том же столе.
//
//  **Поля не двигаются никогда.** Клетка одна до старта и в бою, верх — одна и
//  та же панель счёта той же высоты (до старта в центре «Расстановка»). Всё,
//  что меняется между фазами, стоит на месте квадрата подсказки: до старта там
//  «Изменить» и «Начать», в бою — подсказка.
//
//  Одна рамка 24 pt от краёв. Вертикально своё поле сверху, поле противника
//  снизу — стреляют там, где рука держит планшет. Горизонтально отступы слева,
//  между полями и справа равны; сторона своего поля — только в настройках
//  (4.11), вместе с полями переезжают лента, кнопки и блоки счёта.
//

import SwiftUI

// MARK: - Геометрия стола

/// Размер клетки и отступы стола — чистая функция от области, под тестом.
///
/// Клетка 42 из токенов — **потолок**: клетка = min(42, сколько помещается).
/// iPad бывает от mini до 13", и на mini два поля по 42 в вертикали не
/// помещаются физически. Считается один раз на ориентацию и **от фазы не
/// зависит**: в расчёт берётся самое тесное из обеих фаз, поэтому поля по
/// «Начать» не прыгают.
struct PadTableGeometry: Equatable, Sendable {
    let orientation: PadOrientation
    let cell: CGFloat
    /// Рамка сверху и снизу. Сверху — не меньше полосы состояния, снизу — не
    /// меньше полоски «домой».
    let top: CGFloat
    let bottom: CGFloat
    /// Горизонтально: отступ слева и справа от полей и отступ между ними.
    let sideMargin: CGFloat
    let middleMargin: CGFloat

    static let frame = Geometry.Inset.padFrame
    static let gap = Geometry.Cell.gapPad
    /// Верхняя панель — одна высота до старта и в бою.
    static let topPanelHeight: CGFloat = 86
    /// Между верхней панелью и первым полем.
    static let topGap: CGFloat = 16
    /// Строка названия поля и зазор под ней.
    static let titleHeight: CGFloat = 26
    static let titleGap: CGFloat = 10
    static var titleBlock: CGFloat { titleHeight + titleGap }
    /// Наименьший зазор между полями по вертикали.
    static let blockGap: CGFloat = 12
    /// Квадраты нижней линии.
    static let tile = Geometry.Inset.padTile
    /// Лента столбиком: подпись, зазор и окно на три капсулы.
    static var feedHeight: CGFloat { ShotColumnMetrics.height }
    /// Между лентой и полем (спека 2.8 после раунда 7).
    static let feedClearance: CGFloat = 14
    static let minCell: CGFloat = 24

    /// Сторона поля с подложкой при такой клетке.
    static func boardSide(cell: CGFloat) -> CGFloat {
        BoardMetrics(cell: cell, gap: gap).boardSide
    }

    /// Наибольшая клетка, при которой поле влезает в сторону `side`.
    private static func cell(fitting side: CGFloat) -> CGFloat {
        let columns = CGFloat(BoardMetrics.columns)
        return floor((side - gap * (columns - 1) - Geometry.boardInset * 2) / columns)
    }

    /// Горизонтально отступы слева, между полями и справа равны:
    /// (ширина − 2 × поле) / 3. Нечётный остаток отдаётся середине (21c).
    static func margins(width: CGFloat, boardSide: CGFloat) -> (side: CGFloat, middle: CGFloat) {
        let rest = width - 2 * boardSide
        let side = floor(rest / 3)
        return (side, rest - 2 * side)
    }

    init(size: CGSize, safeTop: CGFloat = 0, safeBottom: CGFloat = 0) {
        let orientation = PadOrientation.of(size)
        let top = max(Self.frame, safeTop)
        let bottom = max(Self.frame, safeBottom)
        let frame = Self.frame
        // Высота под поля: всё, что не верхняя панель и не зазор под ней.
        let body = size.height - top - bottom - Self.topPanelHeight - Self.topGap

        let fit: CGFloat
        switch orientation {
        case .portrait:
            // Два поля друг над другом; нижняя кромка поля противника на общей
            // нижней линии, рядом — квадраты. По бокам поля — лента (128 + 14)
            // и квадраты (104): поле не должно под них заходить.
            let height = (body - Self.titleBlock * 2 - Self.blockGap) / 2
            let width = size.width - 2 * (frame + Geometry.Inset.feedWidthPortrait + Self.feedClearance)
            fit = Self.cell(fitting: min(height, width))
        case .landscape:
            // Два поля рядом. Под своим полем в бою лента, она выше квадратов
            // до старта — считаем от неё в обеих фазах.
            let under = max(Self.feedHeight, Self.tile) + Self.feedClearance
            let height = body - Self.titleBlock - under
            let width = (size.width - 3 * frame) / 2
            fit = Self.cell(fitting: min(height, width))
        }

        let cell = max(Self.minCell, min(Geometry.Cell.iPadPortrait, fit))
        let margins = Self.margins(width: size.width, boardSide: Self.boardSide(cell: cell))
        self.orientation = orientation
        self.cell = cell
        self.top = top
        self.bottom = bottom
        self.sideMargin = margins.side
        self.middleMargin = margins.middle
    }

    var metrics: BoardMetrics { BoardMetrics(cell: cell, gap: Self.gap) }
    var boardSide: CGFloat { metrics.boardSide }
}

// MARK: - Экран

struct PadTableScreen: View {

    enum Phase {
        /// Стол до старта.
        case placement(editor: Binding<FleetEditor>, onStart: () -> Void)
        case battle(BattleController)
    }

    let phase: Phase
    var onMenu: () -> Void = {}

    @Environment(AppState.self) private var appState
    @Environment(\.locale) private var locale

    private var alphabet: BoardAlphabet {
        .forLanguage(locale.language.languageCode?.identifier)
    }

    private var editor: Binding<FleetEditor>? {
        if case .placement(let editor, _) = phase { return editor }
        return nil
    }

    private var battle: BattleController? {
        if case .battle(let battle) = phase { return battle }
        return nil
    }

    var body: some View {
        GeometryReader { proxy in
            let size = CGSize(width: proxy.size.width,
                              height: proxy.size.height + proxy.safeAreaInsets.top
                                  + proxy.safeAreaInsets.bottom)
            let g = PadTableGeometry(size: size,
                                     safeTop: proxy.safeAreaInsets.top,
                                     safeBottom: proxy.safeAreaInsets.bottom)
            Group {
                if g.orientation == .portrait {
                    portrait(g)
                } else {
                    landscape(g)
                }
            }
            .padding(.top, g.top)
            .padding(.bottom, g.bottom)
            .frame(width: size.width, height: size.height)
            .ignoresSafeArea()
        }
        .animation(.easeInOut(duration: ArrangementMetrics.warningFade),
                   value: editor?.wrappedValue.conflictKind)
    }

    // MARK: Вертикально (21a)

    private func portrait(_ g: PadTableGeometry) -> some View {
        VStack(spacing: 0) {
            topPanel(g)
                .padding(.horizontal, PadTableGeometry.frame)
            Spacer(minLength: PadTableGeometry.topGap)
            // Лента — справа, нижняя кромка по нижней кромке своего поля.
            ZStack(alignment: .bottomTrailing) {
                block(.you, g)
                    .frame(maxWidth: .infinity)
                if let battle {
                    ShotColumn(entries: battle.incoming,
                               width: Geometry.Inset.feedWidthPortrait,
                               alphabet: alphabet)
                }
            }
            .padding(.horizontal, PadTableGeometry.frame)
            Spacer(minLength: PadTableGeometry.blockGap)
                .overlay { warning }
            // Нижняя кромка поля противника и квадраты кончаются на одной
            // линии: «Меню» слева, справа кнопки фазы (11b, 21a).
            ZStack(alignment: .bottom) {
                block(.foe, g)
                    .frame(maxWidth: .infinity)
                HStack(alignment: .bottom) {
                    PadNavTile.menu(onMenu)
                    Spacer()
                    phaseTiles(stacked: true)
                }
            }
            .padding(.horizontal, PadTableGeometry.frame)
        }
    }

    // MARK: Горизонтально (21c)

    private func landscape(_ g: PadTableGeometry) -> some View {
        let ownOnRight = appState.ownBoardOnRight
        return VStack(spacing: 0) {
            topPanel(g)
                .padding(.horizontal, PadTableGeometry.frame)
                .padding(.bottom, PadTableGeometry.topGap)
            // Три равных отступа: слева, между полями и справа. Пара полей по
            // центру, остаток уходит в середину — поэтому боковые выходят сами.
            HStack(alignment: .top, spacing: g.middleMargin) {
                block(ownOnRight ? .foe : .you, g)
                block(ownOnRight ? .you : .foe, g)
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: PadTableGeometry.blockGap)
                .overlay { warning }
            // Нижняя линия: лента у внешней кромки своего поля, кнопки фазы у
            // дальней кромки поля противника, «Меню» по центру.
            ZStack(alignment: .bottom) {
                HStack(alignment: .bottom) {
                    if ownOnRight { phaseTiles(stacked: false) } else { feed }
                    Spacer()
                    if ownOnRight { feed } else { phaseTiles(stacked: false) }
                }
                .padding(.horizontal, g.sideMargin)
                PadNavTile.menu(onMenu)
            }
        }
    }

    @ViewBuilder
    private var feed: some View {
        if let battle {
            ShotColumn(entries: battle.incoming,
                       width: Geometry.Inset.feedWidthLandscape,
                       alphabet: alphabet)
        }
    }

    // MARK: Верхняя панель

    /// Одна `ScorePanel` на обе фазы (4.4 после раунда 7): до старта в центре
    /// «Расстановка» и счёт 0 / 10, по «Начать» меняется только содержимое.
    private func topPanel(_ g: PadTableGeometry) -> some View {
        ScorePanel(yourLosses: battle?.player.numberShipsDestroyed ?? 0,
                   foeLosses: battle?.enemy.numberShipsDestroyed ?? 0,
                   isYourTurn: !appState.enemysTurn,
                   balance: ProgressStore.shared.points,
                   isPad: true,
                   yoursOnTrailing: g.orientation == .landscape && appState.ownBoardOnRight,
                   isArranging: battle == nil,
                   // Уровень — только у одиночной игры, в центре панели.
                   level: appState.difficultyLevel)
            .frame(height: PadTableGeometry.topPanelHeight)
    }

    // MARK: Поле с названием

    private func block(_ side: Side, _ g: PadTableGeometry) -> some View {
        VStack(spacing: PadTableGeometry.titleGap) {
            title(side)
                .frame(height: PadTableGeometry.titleHeight)
            board(side, g.metrics)
        }
        // До старта поле противника приглушено — это непрозрачность всего
        // элемента как состояние (правило 8).
        .opacity(side == .foe && battle == nil ? 0.5 : 1)
    }

    /// Над полем противника — имя соперника; у компьютера имени нет, поэтому
    /// «Поле противника». Уровень сюда больше не ставится (4.5 после раунда 7).
    private func title(_ side: Side) -> some View {
        Text(side == .foe ? "Opponent's board" : "Your fleet")
            .font(.system(size: BattleMetrics.pad.caption, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.inkPrimary)
            .lineLimit(1)
            .shadow(color: .inkTitleShadow,
                    radius: NavMetrics.titleShadowRadius,
                    y: NavMetrics.titleShadowOffsetY)
    }

    @ViewBuilder
    private func board(_ side: Side, _ m: BoardMetrics) -> some View {
        if let battle {
            BattleBoard(battle: battle, field: side, metrics: m, alphabet: alphabet)
        } else if side == .you, let editor {
            EditableFleetBoard(editor: editor, metrics: m)
        } else {
            BoardView(cells: [BoardCellState](repeating: .water, count: 100),
                      role: .foe, metrics: m)
                .frame(width: m.totalSize.width, height: m.totalSize.height)
                .accessibilityIdentifier("foeBoard")
        }
    }

    // MARK: Кнопки фазы — на месте квадрата подсказки

    /// До старта «Изменить» и «Начать» (в правке — «Перемешать» и «Готово»),
    /// в бою — подсказка. Вертикально столбиком, «Начать» внизу; горизонтально
    /// в ряд, «Начать» у кромки экрана.
    @ViewBuilder
    private func phaseTiles(stacked: Bool) -> some View {
        if let battle {
            PadHintButton(cost: battle.hintCost, isEnabled: battle.canUseHint) {
                battle.requestHint()
            }
        } else if let editor, case .placement(_, let onStart) = phase {
            let e = editor.wrappedValue
            let layout = stacked
                ? AnyLayout(VStackLayout(spacing: PadTileMetrics.pairGap))
                : AnyLayout(HStackLayout(spacing: PadTileMetrics.pairGap))
            layout {
                Button {
                    if e.isEditing {
                        editor.wrappedValue.shuffle()
                    } else {
                        editor.wrappedValue.beginEditing()
                    }
                } label: {
                    PadTileLabel(title: e.isEditing ? "Shuffle" : "Change",
                                 icon: e.isEditing ? "shuffle" : "hand.draw")
                }
                .buttonStyle(SecondaryButtonStyle(isEnabled: e.actionsEnabled,
                                                  radius: PadTileMetrics.radius,
                                                  fillsFrame: true))
                .disabled(!e.actionsEnabled)
                .frame(width: PadTileMetrics.side, height: PadTileMetrics.side)

                let canPress = e.canFinish && e.actionsEnabled
                Button {
                    if e.isEditing {
                        editor.wrappedValue.finishEditing()
                    } else {
                        onStart()
                    }
                } label: {
                    Text(e.isEditing ? "Done" : "Start")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .buttonStyle(PrimaryButtonStyle(isEnabled: canPress,
                                                radius: PadTileMetrics.radius,
                                                fillsFrame: true))
                .disabled(!canPress)
                .frame(width: PadTileMetrics.side, height: PadTileMetrics.side)
            }
        }
    }

    @ViewBuilder
    private var warning: some View {
        if let kind = editor?.wrappedValue.conflictKind {
            WarningLine(text: kind == .overlap ? "That cell is taken"
                                               : "A one-cell gap is needed")
                .fixedSize()
                .transition(.opacity)
        }
    }
}

// MARK: - Превью

private struct PadTableDemo: View {
    @State private var appState = AppState()
    @State private var battle = BattleController(pacing: .instant)
    @State private var editor = FleetEditor(ships: FleetLayout.canonicalLayout())
    let placement: Bool
    var ownOnRight = false

    var body: some View {
        ZStack {
            SeaBackground()
                .ignoresSafeArea()
            if placement {
                PadTableScreen(phase: .placement(editor: $editor, onStart: {}))
            } else {
                PadTableScreen(phase: .battle(battle))
            }
        }
        .environment(appState)
        .environment(\.usesPadLayout, true)
        .onAppear {
            appState.ownBoardOnRight = ownOnRight
            battle.configure(appState: appState)
            battle.player.place(FleetLayout.canonicalLayout())
            battle.enemy.shipsRandomArrangement()
            appState.gameIsActive = true
            appState.selectedTab = .enemyView
            for coordinate in [Coordinate(row: 1, column: 1), Coordinate(row: 5, column: 5),
                               Coordinate(row: 9, column: 3)] {
                var board = battle.enemy.coreBoard
                _ = board.apply(shotAt: coordinate)
                battle.enemy.apply(board)
                var own = battle.player.coreBoard
                _ = own.apply(shotAt: coordinate)
                battle.player.apply(own)
            }
        }
    }
}

#Preview("Стол · бой · вертикально", traits: .fixedLayout(width: 834, height: 1194)) {
    PadTableDemo(placement: false)
        .preferredColorScheme(.dark)
}

#Preview("Стол · бой · горизонтально", traits: .fixedLayout(width: 1194, height: 834)) {
    PadTableDemo(placement: false)
        .preferredColorScheme(.dark)
}

#Preview("Стол · до старта · вертикально", traits: .fixedLayout(width: 834, height: 1194)) {
    PadTableDemo(placement: true)
        .preferredColorScheme(.dark)
}

#Preview("Стол · до старта · горизонтально", traits: .fixedLayout(width: 1194, height: 834)) {
    PadTableDemo(placement: true)
        .preferredColorScheme(.dark)
}

#Preview("Стол · своё справа · светлая", traits: .fixedLayout(width: 1194, height: 834)) {
    PadTableDemo(placement: false, ownOnRight: true)
        .preferredColorScheme(.light)
}
