//
//  PadTableScreen.swift
//  Sea Battle — стол на два поля, iPad (R2.6, раунды 7–8)
//
//  Спека 4.4 «iPad» и 4.6 «iPad», кадры 21a / 21c (одиночная игра) и 23d / 23e
//  (игра на бумаге). Отдельного экрана расстановки нет: партия открывается
//  сразу двумя полями — своё с авторасставленным флотом и пустое поле
//  противника (приглушено). «Изменить» правит флот на том же столе;
//  «Начать» — бой на том же столе. Игра на бумаге — третья фаза того же стола,
//  вдвоём на устройстве — четвёртая (подсказки нет, квадрат пуст).
//
//  **Поля не двигаются никогда.** Клетка одна до старта и в бою, верх — одна и
//  та же панель счёта той же высоты (до старта в центре «Расстановка»). Всё,
//  что меняется между фазами, стоит на месте квадрата подсказки: до старта там
//  «Изменить» и «Начать», в бою — подсказка, на бумаге — ответы.
//
//  Одна рамка 24 pt от краёв. **«Меню» всегда слева внизу** (раунд 8), в обеих
//  ориентациях. Вертикально своё поле сверху, поле противника снизу.
//  Горизонтально отступы слева, между полями и справа равны; сторона своего
//  поля — только в настройках (4.11), вместе с полями переезжают лента, кнопки
//  и блоки счёта.
//

import SwiftUI

// MARK: - Геометрия стола

/// Размер клетки и отступы стола — чистая функция от области, под тестом.
///
/// Клетка из токенов — **потолок**: клетка = min(потолок, сколько помещается).
/// iPad бывает от mini до 13", и на mini два поля по 42 в вертикали не
/// помещаются физически. Считается один раз на ориентацию и **от фазы не
/// зависит**: в расчёт берётся самое тесное из обеих фаз, поэтому поля по
/// «Начать» не прыгают.
struct PadTableGeometry: Equatable, Sendable {
    let orientation: PadOrientation
    let cell: CGFloat
    /// Поля с координатами — игра на бумаге (B2).
    let coordinates: Bool
    /// Рамка сверху и снизу. Сверху — не меньше полосы состояния, снизу — не
    /// меньше полоски «домой».
    let top: CGFloat
    let bottom: CGFloat
    /// Горизонтально: отступ слева и справа от сеток и отступ между ними.
    let sideMargin: CGFloat
    let middleMargin: CGFloat

    static let frame = Geometry.Inset.padFrame
    static let gap = Geometry.Cell.gapPad
    /// Игра на бумаге: клетка 40 — координаты съедают по 2 pt (23d, 23e).
    static let paperCell: CGFloat = 40
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
    /// С координатами отступы считаются между сетками, цифры висят в них.
    static func margins(width: CGFloat, boardSide: CGFloat) -> (side: CGFloat, middle: CGFloat) {
        let rest = width - 2 * boardSide
        let side = floor(rest / 3)
        return (side, rest - 2 * side)
    }

    init(size: CGSize, safeTop: CGFloat = 0, safeBottom: CGFloat = 0, coordinates: Bool = false) {
        let orientation = PadOrientation.of(size)
        let top = max(Self.frame, safeTop)
        let bottom = max(Self.frame, safeBottom)
        let frame = Self.frame
        // Высота под поля: всё, что не верхняя панель и не зазор под ней.
        let body = size.height - top - bottom - Self.topPanelHeight - Self.topGap
        // Строка букв над полем — только у B2.
        let letters = BoardMetrics(cell: 0, coordinates: coordinates)
        let axis = letters.lettersHeight + letters.axisGap

        let fit: CGFloat
        switch orientation {
        case .portrait:
            // Два поля друг над другом; нижняя кромка поля противника на общей
            // нижней линии, рядом — квадраты. По бокам поля — лента (128 + 14)
            // и квадраты (104): поле не должно под них заходить.
            let height = (body - (Self.titleBlock + axis) * 2 - Self.blockGap) / 2
            let width = size.width - 2 * (frame + Geometry.Inset.feedWidthPortrait + Self.feedClearance)
            fit = Self.cell(fitting: min(height, width))
        case .landscape:
            // Два поля рядом. Под своим полем в бою лента, она выше квадратов
            // до старта — считаем от неё в обеих фазах. На бумаге ленты нет.
            let under = (coordinates ? Self.tile : max(Self.feedHeight, Self.tile)) + Self.feedClearance
            let height = body - Self.titleBlock - axis - under
            let width = (size.width - 3 * frame) / 2
            fit = Self.cell(fitting: min(height, width))
        }

        let ceiling = coordinates ? Self.paperCell : Geometry.Cell.iPadPortrait
        let cell = max(Self.minCell, min(ceiling, fit))
        let margins = Self.margins(width: size.width, boardSide: Self.boardSide(cell: cell))
        self.orientation = orientation
        self.cell = cell
        self.coordinates = coordinates
        self.top = top
        self.bottom = bottom
        self.sideMargin = margins.side
        self.middleMargin = margins.middle
    }

    var metrics: BoardMetrics { BoardMetrics(cell: cell, gap: Self.gap, coordinates: coordinates) }
    var boardSide: CGFloat { metrics.boardSide }
    /// Ширина столбика цифр вместе с зазором — висит слева от сетки.
    var axisWidth: CGFloat { metrics.digitsWidth + metrics.axisGap }
}

// MARK: - Подписи расстановки вдвоём

/// Стол до старта вдвоём на устройстве (4.7): чей флот, чьё поле напротив и
/// кого называет главная кнопка.
struct PadDuelPlacement {
    /// «Флот: Аня».
    let ownTitle: LocalizedStringKey
    /// Имя соперника — над его пустым полем, как в бою.
    let foeName: String
    /// «Борис расставляет флот» / «Начать бой».
    let startTitle: LocalizedStringKey
}

// MARK: - Экран

struct PadTableScreen: View {

    enum Phase {
        /// Стол до старта.
        case placement(editor: Binding<FleetEditor>, onStart: () -> Void)
        case battle(BattleController)
        /// Игра на бумаге (4.6, 23d / 23e).
        case paper(PaperMatch)
        /// Вдвоём на устройстве (4.7): оба поля глазами держателя. Слой
        /// передачи рисует `DuelScreen` поверх всего стола.
        case duel(DuelMatch)
        /// Сетевая партия (4.8): после «Начать» — ожидание соперника и бой.
        /// При обрыве связи на месте панели баннер, поля погашены.
        case network(NetMatch)
    }

    let phase: Phase
    var onMenu: () -> Void = {}
    /// Стол игры на бумаге и до старта: поля с координатами и клеткой 40, как
    /// в партии, — иначе по «Начать» они прыгнули бы; уровня в панели нет.
    var isPaper = false
    /// Стол до старта вдвоём на устройстве: подписи называют игроков, уровня
    /// и баланса в панели нет.
    var duelPlacement: PadDuelPlacement?
    /// Сетевая партия до подключения соперника (4.4): расстановку править
    /// можно, «Начать» заблокирована. На правку не влияет.
    var startEnabled = true

    @Environment(AppState.self) private var appState
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Просмотр полей после партии — ставит `matchResults` экрана партии.
    @Environment(\.matchReview) private var review

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

    private var paper: PaperMatch? {
        if case .paper(let match) = phase { return match }
        return nil
    }

    private var duel: DuelMatch? {
        if case .duel(let match) = phase { return match }
        return nil
    }

    private var net: NetMatch? {
        if case .network(let match) = phase { return match }
        return nil
    }

    /// Сетевая партия, пока соперник расставляет флот, — ещё до старта.
    private var isPlaying: Bool {
        battle != nil || paper != nil || duel != nil || (net.map { $0.game.stage != .arranging } ?? false)
    }
    private var isPaperTable: Bool { isPaper || paper != nil }
    /// Режим с уровнем в панели — только против компьютера.
    private var isComputerTable: Bool {
        !isPaperTable && duel == nil && duelPlacement == nil && net == nil
    }
    private var isLost: Bool { net?.link.isLost ?? false }

    var body: some View {
        GeometryReader { proxy in
            let size = CGSize(width: proxy.size.width,
                              height: proxy.size.height + proxy.safeAreaInsets.top
                                  + proxy.safeAreaInsets.bottom)
            let g = PadTableGeometry(size: size,
                                     safeTop: proxy.safeAreaInsets.top,
                                     safeBottom: proxy.safeAreaInsets.bottom,
                                     coordinates: isPaperTable)
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
        .animation(.easeInOut(duration: Motion.scaled(ArrangementMetrics.warningFade,
                                                      reduceMotion: reduceMotion)),
                   value: editor?.wrappedValue.conflictKind)
        .animation(Motion.quick.reduced(reduceMotion), value: paper?.game.aim)
        .animation(Motion.quick.reduced(reduceMotion), value: duel?.aim)
    }

    // MARK: Вертикально (21a, 23d)

    private func portrait(_ g: PadTableGeometry) -> some View {
        VStack(spacing: 0) {
            topPanel(g)
                .padding(.horizontal, PadTableGeometry.frame)
            Spacer(minLength: PadTableGeometry.topGap)
            // Лента — справа, нижняя кромка по нижней кромке своего поля.
            ZStack(alignment: .bottomTrailing) {
                block(.you, g)
                    .frame(maxWidth: .infinity)
                if let incoming {
                    ShotColumn(entries: incoming,
                               width: Geometry.Inset.feedWidthPortrait,
                               alphabet: alphabet)
                }
            }
            .padding(.horizontal, PadTableGeometry.frame)
            Spacer(minLength: PadTableGeometry.blockGap)
                .overlay { warning }
            // Нижняя кромка поля противника и квадраты кончаются на одной
            // линии: «Меню» слева (на бумаге над ним «Отменить»), справа
            // кнопки фазы. Своё поле справа — квадраты меняются сторонами, поля
            // стоят на месте (решение заказчика 30.09, В28).
            ZStack(alignment: .bottom) {
                block(.foe, g)
                    .frame(maxWidth: .infinity)
                HStack(alignment: .bottom) {
                    if mirrored {
                        phaseTiles(stacked: true)
                        Spacer()
                        menuColumn
                    } else {
                        menuColumn
                        Spacer()
                        phaseTiles(stacked: true)
                    }
                }
            }
            .padding(.horizontal, PadTableGeometry.frame)
        }
    }

    /// Своё поле справа (настройка 4.11): нижняя линия зеркалится целиком —
    /// «Меню» и «Отменить» справа, кнопки фазы слева (решение заказчика
    /// 30.09 по В28, в обеих ориентациях).
    private var mirrored: Bool { appState.ownBoardOnRight }

    private var menuColumn: some View {
        VStack(spacing: PadTileMetrics.pairGap) {
            if let paper { undoTile(paper) }
            PadNavTile.menu(onMenu)
        }
    }

    // MARK: Горизонтально (21c, 23e)

    private func landscape(_ g: PadTableGeometry) -> some View {
        let ownOnRight = appState.ownBoardOnRight
        let left: Side = ownOnRight ? .foe : .you
        let right: Side = ownOnRight ? .you : .foe
        // С координатами равные отступы считаются между сетками, а цифры висят
        // в них: сдвигаем пару на ширину цифр влево и сжимаем середину.
        let axis = g.axisWidth
        return VStack(spacing: 0) {
            topPanel(g)
                .padding(.horizontal, PadTableGeometry.frame)
                .padding(.bottom, PadTableGeometry.topGap)
            HStack(alignment: .top, spacing: g.middleMargin - axis) {
                block(left, g)
                block(right, g)
            }
            .padding(.leading, g.sideMargin - axis)
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: PadTableGeometry.blockGap)
                .overlay { warning }
            // Нижняя линия: «Меню» слева (на бумаге рядом «Отменить»), лента
            // под центром своего поля, кнопки фазы у дальней кромки поля
            // противника (21c, 23e). Своё поле справа — всё зеркально.
            ZStack(alignment: ownOnRight ? .bottomTrailing : .bottomLeading) {
                HStack(alignment: .bottom, spacing: g.middleMargin) {
                    underBoard(left, farEdge: .leading, g)
                    underBoard(right, farEdge: .trailing, g)
                }
                .padding(.leading, g.sideMargin)
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: PadTileMetrics.pairGap) {
                    if ownOnRight, let paper { undoTile(paper) }
                    PadNavTile.menu(onMenu)
                    if !ownOnRight, let paper { undoTile(paper) }
                }
                .padding(ownOnRight ? .trailing : .leading, PadTableGeometry.frame)
            }
            .frame(maxWidth: .infinity, alignment: ownOnRight ? .bottomTrailing : .bottomLeading)
        }
    }

    /// Что стоит под полем на нижней линии: под своим — лента по центру, под
    /// полем противника — кнопки фазы у его дальней кромки. «Меню» всегда в
    /// углу своего поля, поэтому кнопкам фазы с ним не встретиться.
    private func underBoard(_ side: Side, farEdge: HorizontalAlignment,
                            _ g: PadTableGeometry) -> some View {
        Group {
            if side == .you {
                // Колонка держит ширину и без ленты (на бумаге её нет), иначе
                // кнопки фазы съехали бы под своё поле.
                Color.clear
                    .frame(width: g.boardSide, height: 1)
                    .overlay(alignment: .bottom) { feed }
            } else {
                // Колонка держит ширину и без кнопок (вдвоём, ожидание хода по
                // сети): пустая схлопывалась, и лента своего поля справа
                // уезжала под поле противника.
                Color.clear
                    .frame(width: g.boardSide, height: 1)
                    .overlay(alignment: farEdge == .leading ? .bottomLeading : .bottomTrailing) {
                        phaseTiles(stacked: false)
                    }
            }
        }
    }

    @ViewBuilder
    private var feed: some View {
        if let incoming {
            ShotColumn(entries: incoming,
                       width: Geometry.Inset.feedWidthLandscape,
                       alphabet: alphabet)
        }
    }

    /// Лента «По вам» — в бою против компьютера и вдвоём (выстрелы соперника
    /// за его последний ход); на бумаге её нет.
    private var incoming: [ShotFeedEntry]? {
        battle?.incoming ?? duel?.incoming ?? net?.incoming
    }

    // MARK: Верхняя панель

    /// Одна `ScorePanel` на все фазы (4.4 после раунда 7): до старта в центре
    /// «Расстановка» и счёт 0 / 10, по «Начать» меняется только содержимое.
    @ViewBuilder
    private func topPanel(_ g: PadTableGeometry) -> some View {
        let trailing = g.orientation == .landscape && appState.ownBoardOnRight
        Group {
            if let paper {
                PaperScorePanel(match: paper, alphabet: alphabet,
                                isPad: true, yoursOnTrailing: trailing)
            } else if let net {
                if net.link.isLost {
                    NetLostBanner(match: net, isPad: true)
                } else {
                    NetScorePanel(match: net, isPad: true, yoursOnTrailing: trailing)
                }
            } else if let duel {
                // Как на iPhone: «Ход: Аня», латунь у своего хода, баланса нет.
                ScorePanel(yourLosses: duel.board(.you).sunkShipCount,
                           foeLosses: duel.game.boards[duel.opponent].sunkShipCount,
                           isYourTurn: duel.isViewersTurn,
                           balance: 0,
                           isPad: true,
                           yoursOnTrailing: trailing,
                           status: Text("Turn: \(duel.player(duel.game.attacker).name)"),
                           statusIsWarm: duel.isViewersTurn,
                           showsBalance: false)
            } else {
                ScorePanel(yourLosses: battle?.player.numberShipsDestroyed ?? 0,
                           foeLosses: battle?.enemy.numberShipsDestroyed ?? 0,
                           isYourTurn: !appState.enemysTurn,
                           balance: ProgressStore.shared.points,
                           isPad: true,
                           yoursOnTrailing: trailing,
                           isArranging: battle == nil,
                           // Уровень — только у одиночной игры, в центре панели.
                           level: isComputerTable ? appState.difficultyLevel : nil,
                           status: battle?.result.map(MatchResult.statusText),
                           showsBalance: isComputerTable)
            }
        }
        .frame(height: PadTableGeometry.topPanelHeight)
    }

    // MARK: Поле с названием

    private func block(_ side: Side, _ g: PadTableGeometry) -> some View {
        VStack(spacing: PadTableGeometry.titleGap) {
            title(side)
                .frame(height: PadTableGeometry.titleHeight)
                // Горизонтально сетки на равных отступах, цифры висят слева —
                // название стоит над сеткой, а не над сеткой с цифрами.
                .padding(.leading, isPaperTable && g.orientation == .landscape ? g.axisWidth : 0)
            board(side, g)
        }
        // До старта поле противника приглушено — это непрозрачность всего
        // элемента как состояние (правило 8). Оборванная связь гасит оба.
        .opacity(isLost ? NetMetrics.lostDim : side == .foe && !isPlaying ? 0.5 : 1)
    }

    /// Над полем противника — имя соперника; у компьютера имени нет, поэтому
    /// «Поле противника», на бумаге — «Противник» (23d). Уровень сюда больше
    /// не ставится (4.5 после раунда 7).
    private func title(_ side: Side) -> some View {
        titleText(side)
            .font(.system(size: BattleMetrics.pad.caption, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.inkPrimary)
            .lineLimit(1)
            .shadow(color: .inkTitleShadow,
                    radius: NavMetrics.titleShadowRadius,
                    y: NavMetrics.titleShadowOffsetY)
            // Подпись поля — заголовок: VoiceOver прыгает по ним ротором, и
            // это единственное имя поля (у `BoardView` своего нет).
            .accessibilityAddTraits(.isHeader)
    }

    /// Вдвоём своё поле — «Ваш флот» в бою и «Флот: Аня» на расстановке
    /// (устройство переходит из рук в руки), над чужим — имя соперника.
    private func titleText(_ side: Side) -> Text {
        if let duel {
            return side == .you ? Text("Your fleet") : Text(verbatim: duel.player(duel.opponent).name)
        }
        if let net, side == .foe, !net.opponentName.isEmpty {
            return Text(verbatim: net.opponentName)
        }
        if let duelPlacement {
            return side == .you ? Text(duelPlacement.ownTitle) : Text(verbatim: duelPlacement.foeName)
        }
        if side == .you { return Text("Your fleet") }
        return isPaperTable ? Text("Opponent") : Text("Opponent's board")
    }

    private func board(_ side: Side, _ g: PadTableGeometry) -> some View {
        fieldView(side, g)
            // Вертикально с координатами по центру стоит сетка (раунд 8): цифры
            // уравновешены пустым отступом справа. `PaperBoard` делает это сам.
            .padding(.trailing, isPaperTable && paper == nil && g.orientation == .portrait
                     ? g.axisWidth : 0)
    }

    @ViewBuilder
    private func fieldView(_ side: Side, _ g: PadTableGeometry) -> some View {
        let m = g.metrics
        if let paper {
            PaperBoard(match: paper, field: side, metrics: m, alphabet: alphabet,
                       centersGrid: g.orientation == .portrait)
        } else if let battle {
            BattleBoard(battle: battle, field: side, metrics: m, alphabet: alphabet)
        } else if let duel {
            DuelBoard(match: duel, field: side, metrics: m, alphabet: alphabet)
        } else if let net {
            NetBoard(match: net, field: side, metrics: m, alphabet: alphabet)
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
    /// в бою — подсказка, на бумаге — три ответа, вдвоём — ничего (подсказок
    /// в режиме нет). Вертикально столбиком
    /// («Начать» и «Мимо» внизу), горизонтально в ряд («Начать» и «Мимо» у
    /// кромки экрана).
    @ViewBuilder
    private func phaseTiles(stacked: Bool) -> some View {
        if let review {
            // Просмотр полей после партии: вместо кнопок фазы — «Итоги».
            Button(action: review.backToResults) {
                PadTileLabel(title: "Results", icon: "flag.checkered")
            }
            .buttonStyle(SecondaryButtonStyle(radius: PadTileMetrics.radius, fillsFrame: true))
            .frame(width: PadTileMetrics.side, height: PadTileMetrics.side)
            .accessibilityIdentifier("reviewResults")
        } else if let paper {
            answerTiles(paper, stacked: stacked)
        } else if let battle {
            PadHintButton(cost: battle.hintCost, isEnabled: battle.canUseHint) {
                battle.requestHint()
            }
        } else if let net {
            netTiles(net)
        } else if let editor, case .placement(_, let onStart) = phase {
            let layout = stacked
                ? AnyLayout(VStackLayout(spacing: PadTileMetrics.pairGap))
                : AnyLayout(HStackLayout(spacing: PadTileMetrics.pairGap))
            // «Начать» — у кромки экрана: внизу столбика, в ряду — с краю, а
            // при своём поле справа край — левый.
            layout {
                if edgeFirst(stacked) {
                    startTile(editor, onStart: onStart)
                    changeTile(editor)
                } else {
                    changeTile(editor)
                    startTile(editor, onStart: onStart)
                }
            }
        }
    }

    /// Сеть: при обрыве — «Повторить сейчас», на своём ходу — подсказка (не
    /// против своего аккаунта), в ожидании — ничего.
    @ViewBuilder
    private func netTiles(_ net: NetMatch) -> some View {
        if net.link.isLost {
            Button { net.retryNow() } label: {
                PadTileLabel(title: "Retry now", icon: "arrow.clockwise")
            }
            .buttonStyle(SecondaryButtonStyle(radius: PadTileMetrics.radius, fillsFrame: true))
            .frame(width: PadTileMetrics.side, height: PadTileMetrics.side)
        } else if net.isMyTurn && net.offersHint {
            PadHintButton(cost: net.hintCost, isEnabled: net.canUseHint) {
                net.requestHint()
            }
        }
    }

    /// В ряду при зеркальной нижней линии кромка экрана слева, и кнопка у
    /// кромки («Начать», «Мимо») идёт первой.
    private func edgeFirst(_ stacked: Bool) -> Bool { !stacked && mirrored }

    private func changeTile(_ editor: Binding<FleetEditor>) -> some View {
        let e = editor.wrappedValue
        return Button {
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
    }

    private func startTile(_ editor: Binding<FleetEditor>, onStart: @escaping () -> Void) -> some View {
        let e = editor.wrappedValue
        let canPress = e.canFinish && e.actionsEnabled && (e.isEditing || startEnabled)
        return Button {
            if e.isEditing {
                editor.wrappedValue.finishEditing()
            } else {
                onStart()
            }
        } label: {
            // Вдвоём кнопка называет следующего — «Борис расставляет флот»
            // (4.7), поэтому надпись переносится в квадрате.
            Text(e.isEditing ? "Done" : duelPlacement?.startTitle ?? "Start")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 8)
        }
        .buttonStyle(PrimaryButtonStyle(isEnabled: canPress,
                                        radius: PadTileMetrics.radius,
                                        fillsFrame: true))
        .disabled(!canPress)
        .frame(width: PadTileMetrics.side, height: PadTileMetrics.side)
    }

    /// Ответы — квадратами 104, как только названа клетка. «Мимо» — самый
    /// частый ответ — внизу столбика и у кромки экрана в ряду (23d, 23e).
    @ViewBuilder
    private func answerTiles(_ match: PaperMatch, stacked: Bool) -> some View {
        if match.game.aim != nil {
            let layout = stacked
                ? AnyLayout(VStackLayout(spacing: PadTileMetrics.pairGap))
                : AnyLayout(HStackLayout(spacing: PadTileMetrics.pairGap))
            layout {
                ForEach(edgeFirst(stacked) ? PaperAnswer.allCases : PaperAnswer.allCases.reversed(),
                        id: \.self) { answer in
                    Button { match.answer(answer) } label: {
                        PadTileLabel(title: PaperAnswerLabel.title(answer),
                                     icon: PaperAnswerLabel.icon(answer),
                                     iconTint: PaperAnswerLabel.tint(answer))
                    }
                    .buttonStyle(SecondaryButtonStyle(radius: PadTileMetrics.radius,
                                                      fillsFrame: true))
                    .frame(width: PadTileMetrics.side, height: PadTileMetrics.side)
                    .accessibilityIdentifier("paperAnswer_\(answer.rawValue)")
                }
            }
            .transition(.opacity)
        }
    }

    /// «Отменить последний ход» — квадратом рядом с «Меню».
    private func undoTile(_ match: PaperMatch) -> some View {
        Button { match.undo() } label: {
            PadTileLabel(title: "Undo", icon: "arrow.uturn.backward")
        }
        .buttonStyle(SecondaryButtonStyle(isEnabled: match.canUndo,
                                          radius: PadTileMetrics.radius,
                                          fillsFrame: true))
        .disabled(!match.canUndo)
        .frame(width: PadTileMetrics.side, height: PadTileMetrics.side)
        .accessibilityLabel(Text("Undo last move"))
        .accessibilityIdentifier("paperUndo")
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
        .phoneStyle(true)
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

/// Игра на бумаге на столе: клетка названа или соперник попал (23d, 23e).
private struct PadPaperDemo: View {
    @State private var appState = AppState()
    @State private var match: PaperMatch
    var ownOnRight = false

    init(_ phase: PaperDemoPhase, ownOnRight: Bool = false) {
        _match = State(initialValue: paperDemoMatch(phase))
        self.ownOnRight = ownOnRight
    }

    var body: some View {
        ZStack {
            SeaBackground()
                .ignoresSafeArea()
            PadTableScreen(phase: .paper(match))
        }
        .environment(appState)
        .environment(\.usesPadLayout, true)
        .phoneStyle(true)
        .onAppear { appState.ownBoardOnRight = ownOnRight }
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

#Preview("Стол · бумага · вертикально", traits: .fixedLayout(width: 834, height: 1194)) {
    PadPaperDemo(.aim)
        .preferredColorScheme(.dark)
}

#Preview("Стол · бумага · горизонтально", traits: .fixedLayout(width: 1194, height: 834)) {
    PadPaperDemo(.aim)
        .preferredColorScheme(.dark)
}

#Preview("Стол · бумага · ход соперника", traits: .fixedLayout(width: 1194, height: 834)) {
    PadPaperDemo(.theirs)
        .preferredColorScheme(.dark)
}

#Preview("Стол · бумага · своё справа", traits: .fixedLayout(width: 1194, height: 834)) {
    PadPaperDemo(.aim, ownOnRight: true)
        .preferredColorScheme(.light)
}

#Preview("Стол · бумага · вертикально · своё справа", traits: .fixedLayout(width: 834, height: 1194)) {
    PadPaperDemo(.aim, ownOnRight: true)
        .preferredColorScheme(.dark)
}
