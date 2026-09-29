//
//  PadTableScreen.swift
//  Sea Battle — стол на два поля, iPad (R2.6, шаг 10 порядка сборки)
//
//  Спека 4.4 «iPad» и 4.5, кадры `screen8Ipad` (стол до старта, тур 8.1),
//  `screen11Port` и `screen11Land` (бой, тур 11.2). Отдельного экрана
//  расстановки нет: партия открывается сразу двумя полями — своё с
//  авторасставленным флотом и пустое поле противника. «Изменить» правит флот
//  на том же экране, поле противника при этом приглушается; «Начать» — бой на
//  том же столе.
//
//  Одна рамка 24 pt от всех четырёх краёв в обеих ориентациях (тур 11.2).
//  Вертикально своё поле сверху, поле противника снизу — стреляют там, где
//  рука держит планшет. Горизонтально по умолчанию своё слева; сторона — только
//  в настройках (4.11), вместе с полями переезжают лента, подсказка и блоки
//  счёта, цвета ролей не меняются.
//
//  Правила экрана те же, что у iPhone: верх показывает и не нажимается, всё
//  нажимаемое — на нижней линии.
//

import SwiftUI

// MARK: - Геометрия стола

/// Размер клетки и рамка стола — чистая функция от области, под тестом.
///
/// Клетки из токенов (42 вертикально, 44 горизонтально, 40 на столе до
/// старта) — **потолок**, а не закон: iPad бывает от mini до 13", и на mini
/// два поля по 42 pt в вертикали не помещаются физически. Поэтому клетка
/// считается от места и зажимается сверху токеном.
struct PadTableGeometry: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        /// Стол до старта: вместо панели счёта — заголовок, внизу ряд кнопок.
        case placement
        case battle
    }

    let orientation: PadOrientation
    let phase: Phase
    let cell: CGFloat
    /// Рамка сверху и снизу. Сверху — не меньше полосы состояния, снизу — не
    /// меньше полоски «домой».
    let top: CGFloat
    let bottom: CGFloat

    static let frame = Geometry.Inset.padFrame
    static let gap = Geometry.Cell.gapPad
    /// Верхняя панель — одна высота на счёт и заголовок стола, иначе поля
    /// прыгнули бы по «Начать».
    static let topPanelHeight: CGFloat = 86
    /// Между верхней панелью и первым полем.
    static let topGap: CGFloat = 16
    /// Строка названия поля и зазор под ней.
    static let titleHeight: CGFloat = 26
    static let titleGap: CGFloat = 10
    static var titleBlock: CGFloat { titleHeight + titleGap }
    /// Наименьший зазор между полями по вертикали и над нижним рядом.
    static let blockGap: CGFloat = 12
    /// Ряд кнопок стола и нижняя панель — одна высота (тур 11.1).
    static let bottomRowHeight = Geometry.Inset.hintHeightLandscape
    /// Лента столбиком: подпись, зазор и окно на три капсулы.
    static var feedHeight: CGFloat { ShotColumnMetrics.height }
    /// Между лентой и кромкой поля — чтобы капсулы не липли к полю.
    static let feedClearance: CGFloat = 8
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

    init(size: CGSize, safeTop: CGFloat = 0, safeBottom: CGFloat = 0, phase: Phase) {
        let orientation = PadOrientation.of(size)
        let top = max(Self.frame, safeTop)
        let bottom = max(Self.frame, safeBottom)
        let frame = Self.frame
        // Высота под поля: всё, что не верхняя панель и не зазор под ней.
        let body = size.height - top - bottom - Self.topPanelHeight - Self.topGap

        let fit: CGFloat
        let ceiling: CGFloat
        switch (orientation, phase) {
        case (.portrait, _):
            // Два поля друг над другом. В бою нижняя кромка поля противника
            // стоит на общей нижней линии, рядом — «Меню» и подсказка; до
            // старта под полем противника ещё ряд кнопок.
            var height = body - Self.titleBlock * 2 - Self.blockGap
            if phase == .placement { height -= Self.bottomRowHeight + Self.blockGap }
            // По бокам поля — ячейки рельса и подсказки (104) и лента (128):
            // поле не должно под них заходить.
            let side = Geometry.Inset.feedWidthPortrait + Self.feedClearance
            let width = phase == .battle ? size.width - 2 * (frame + side) : size.width - 2 * frame
            fit = Self.cell(fitting: min(height / 2, width))
            ceiling = phase == .battle ? Geometry.Cell.iPadPortrait : Geometry.Cell.iPadTable

        case (.landscape, _):
            // Два поля рядом, 34 pt между ними. Под своим полем в бою лента,
            // она выше ряда кнопок до старта. Считаем от большего в **обеих**
            // фазах: иначе на iPad mini клетка менялась бы по «Начать».
            let under = max(Self.feedHeight + Self.feedClearance,
                            Self.bottomRowHeight + Self.blockGap)
            let height = body - Self.titleBlock - under
            let width = (size.width - 2 * frame - Geometry.Inset.boardGapPad) / 2
            fit = Self.cell(fitting: min(height, width))
            // Горизонтально клетка одна на обе фазы: места хватает, и поля
            // по «Начать» не прыгают.
            ceiling = Geometry.Cell.iPadLandscape
        }

        self.orientation = orientation
        self.phase = phase
        self.cell = max(Self.minCell, min(ceiling, fit))
        self.top = top
        self.bottom = bottom
    }

    var metrics: BoardMetrics { BoardMetrics(cell: cell, gap: Self.gap) }
    var boardSide: CGFloat { metrics.boardSide }
}

// MARK: - Экран

struct PadTableScreen: View {

    enum Phase {
        /// Стол до старта. Уровень, который в кадре стоит подзаголовком
        /// шапки, здесь — капсулой в строке поля противника, как в бою.
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

    private var geometryPhase: PadTableGeometry.Phase {
        if case .placement = phase { return .placement }
        return .battle
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
                                     safeBottom: proxy.safeAreaInsets.bottom,
                                     phase: geometryPhase)
            Group {
                if g.orientation == .portrait {
                    portrait(g)
                } else {
                    landscape(g)
                }
            }
            .padding(.top, g.top)
            .padding(.bottom, g.bottom)
            .padding(.horizontal, PadTableGeometry.frame)
            .frame(width: size.width, height: size.height)
            .ignoresSafeArea()
        }
        .animation(.easeInOut(duration: ArrangementMetrics.warningFade),
                   value: editor?.wrappedValue.conflictKind)
    }

    // MARK: Вертикально

    private func portrait(_ g: PadTableGeometry) -> some View {
        VStack(spacing: 0) {
            topPanel(g)
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
            Spacer(minLength: PadTableGeometry.blockGap)
                .overlay { warning }
            // Нижняя кромка поля противника, «Меню» и подсказка кончаются на
            // одной линии (тур 11.2).
            ZStack(alignment: .bottom) {
                block(.foe, g)
                    .frame(maxWidth: .infinity)
                if battle != nil {
                    HStack(alignment: .bottom) {
                        PadMenuButton(orientation: .portrait, action: onMenu)
                            .frame(height: Geometry.Inset.railWidth)
                        Spacer()
                        hint(tall: true)
                    }
                }
            }
            if editor != nil {
                placementRow(g)
                    .padding(.top, PadTableGeometry.blockGap)
            }
        }
    }

    // MARK: Горизонтально

    private func landscape(_ g: PadTableGeometry) -> some View {
        let pairWidth = g.boardSide * 2 + Geometry.Inset.boardGapPad
        let ownOnRight = appState.ownBoardOnRight
        return VStack(spacing: 0) {
            topPanel(g)
                .padding(.bottom, PadTableGeometry.topGap)
            HStack(alignment: .top, spacing: Geometry.Inset.boardGapPad) {
                block(ownOnRight ? .foe : .you, g)
                block(ownOnRight ? .you : .foe, g)
            }
            Spacer(minLength: PadTableGeometry.blockGap)
                .overlay { warning }
            if editor != nil {
                placementRow(g)
            } else {
                // Лента под своим полем у его внешней кромки, подсказка под
                // полем противника у дальней кромки, «Меню» по центру (11a).
                ZStack(alignment: .bottom) {
                    HStack(alignment: .bottom) {
                        if ownOnRight { hint(tall: false) } else { feed(g) }
                        Spacer()
                        if ownOnRight { feed(g) } else { hint(tall: false) }
                    }
                    PadMenuButton(orientation: .landscape, action: onMenu)
                        .frame(height: PadNavMetrics.barHeight)
                }
                .frame(width: pairWidth)
            }
        }
    }

    @ViewBuilder
    private func feed(_ g: PadTableGeometry) -> some View {
        if let battle {
            ShotColumn(entries: battle.incoming,
                       width: Geometry.Inset.feedWidthLandscape,
                       alphabet: alphabet)
        }
    }

    // MARK: Верхняя панель

    @ViewBuilder
    private func topPanel(_ g: PadTableGeometry) -> some View {
        Group {
            if let battle {
                ScorePanel(yourLosses: battle.player.numberShipsDestroyed,
                           foeLosses: battle.enemy.numberShipsDestroyed,
                           isYourTurn: !appState.enemysTurn,
                           balance: ProgressStore.shared.points,
                           isPad: true,
                           yoursOnTrailing: g.orientation == .landscape && appState.ownBoardOnRight)
            } else if let editor {
                tableHead(editing: editor.wrappedValue.isEditing)
            }
        }
        .frame(height: PadTableGeometry.topPanelHeight)
    }

    /// Шапка стола до старта (кадр `screen8Ipad`): название фазы и подсказка.
    /// Как и на iPhone, **при ошибке они не меняются** — об ошибке говорит
    /// строка между полями.
    private func tableHead(editing: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            // Над своим полем уже написано «Ваш флот», поэтому до правки
            // шапка называет режим, как в кадре.
            Text(editing ? "Change the layout" : "Single player")
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.inkPrimary)
            Text(editing ? "Drag a ship to move it · tap to turn it"
                         : "The ships are placed for you")
                .font(.system(size: 13))
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .glassPanel(.g2, radius: Geometry.Radius.panel, wood: .bottom)
    }

    // MARK: Поле с названием

    private func block(_ side: Side, _ g: PadTableGeometry) -> some View {
        VStack(spacing: PadTableGeometry.titleGap) {
            title(side)
                .frame(height: PadTableGeometry.titleHeight)
            board(side, g.metrics)
        }
        // До старта в режиме правки поле противника приглушено — это
        // непрозрачность всего элемента как состояние (правило 8).
        .opacity(side == .foe && editor?.wrappedValue.isEditing == true ? 0.5 : 1)
    }

    private func title(_ side: Side) -> some View {
        HStack(spacing: LevelChip.gap(.regular)) {
            Text(side == .foe ? "Opponent's board" : "Your fleet")
                .font(.system(size: BattleMetrics.pad.caption, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
                .shadow(color: .inkTitleShadow,
                        radius: NavMetrics.titleShadowRadius,
                        y: NavMetrics.titleShadowOffsetY)
            // Уровень — в строке заголовка поля противника, по тем же
            // правилам, что на iPhone (4.5).
            if side == .foe {
                LevelChip(level: appState.difficultyLevel, size: .regular)
            }
        }
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

    // MARK: Подсказка

    @ViewBuilder
    private func hint(tall: Bool) -> some View {
        if let battle {
            PadHintButton(cost: battle.hintCost, isEnabled: battle.canUseHint,
                          isTall: tall) { battle.requestHint() }
        }
    }

    // MARK: Ряд кнопок до старта

    /// «Меню» слева, кнопки по центру нижней линии, справа зеркальный отступ
    /// той же ширины — равное расстояние для левой и правой руки (тур 9).
    private func placementRow(_ g: PadTableGeometry) -> some View {
        HStack(spacing: 0) {
            PadMenuButton(orientation: .portrait, action: onMenu)
                .frame(width: Geometry.Inset.railWidth)
            Spacer(minLength: PadTableGeometry.blockGap)
            placementButtons
                .frame(maxWidth: PadTableMetrics.buttonsWidth)
            Spacer(minLength: PadTableGeometry.blockGap)
            Color.clear
                .frame(width: Geometry.Inset.railWidth)
        }
        .frame(height: PadTableGeometry.bottomRowHeight)
    }

    @ViewBuilder
    private var placementButtons: some View {
        if let editor, case .placement(_, let onStart) = phase {
            let e = editor.wrappedValue
            HStack(spacing: PadTableMetrics.buttonsGap) {
                if e.isEditing {
                    Button {
                        editor.wrappedValue.shuffle()
                    } label: {
                        Label("Shuffle", systemImage: "shuffle")
                    }
                    .secondaryButton(enabled: e.actionsEnabled)
                } else {
                    Button {
                        editor.wrappedValue.beginEditing()
                    } label: {
                        Label("Change", systemImage: "hand.draw")
                    }
                    .secondaryButton(enabled: e.actionsEnabled)
                }

                Button {
                    if e.isEditing {
                        editor.wrappedValue.finishEditing()
                    } else {
                        onStart()
                    }
                } label: {
                    Text(e.isEditing ? "Done" : "Start")
                }
                .primaryButton(enabled: e.canFinish && e.actionsEnabled)
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

/// Числа ряда кнопок из кадра `screen8Ipad`.
enum PadTableMetrics {
    static let buttonsWidth: CGFloat = 470
    static let buttonsGap: CGFloat = 14
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

#Preview("Стол · своё справа · светлая", traits: .fixedLayout(width: 1194, height: 834)) {
    PadTableDemo(placement: false, ownOnRight: true)
        .preferredColorScheme(.light)
}
