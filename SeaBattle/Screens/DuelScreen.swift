//
//  DuelScreen.swift
//  Sea Battle — вдвоём на устройстве: партия, iPhone (R3.2, шаг 12)
//
//  Спека 4.7. Один контейнер на всю партию: расстановка того, чья очередь,
//  бой глазами держателя устройства и **слой передачи** поверх — не sheet, а
//  непрозрачный G1 в том же контейнере, приезжает сверху, состояние партии
//  под ним не пересоздаётся.
//
//  Бой — та же раскладка, что против компьютера (правило 3): `ScorePanel`
//  (без баланса — баллов в режиме нет), поле, лента «По вам» на своём поле,
//  внизу переключатель полей и `NavRow`. Подсказки нет, поэтому переключатель
//  занимает всю строку.
//

import SwiftUI

// MARK: - Числа

/// Кадр `screen4Handoff`.
enum HandoffMetrics {
    /// Верх колонки — 104 от края экрана, то есть 45 под полосой состояния.
    static let top: CGFloat = 45
    static let gap: CGFloat = 18
    static let avatar: CGFloat = 88
    static let title: CGFloat = 26
    static let subtitle: CGFloat = 13.5
    static let titleGap: CGFloat = 6
    static let codeLabel: CGFloat = 11
    static let codeGap: CGFloat = 12
    static let dot: CGFloat = 15
    static let dotGap: CGFloat = 14
    static let keyWidth: CGFloat = 74
    static let keyHeight: CGFloat = 62
    static let keyGap: CGFloat = 12
    static let keyRadius: CGFloat = 18
    static let keyText: CGFloat = 24
    static let deleteIcon: CGFloat = 28
    static let footnote: CGFloat = 12
    static let footnoteInset: CGFloat = 24
    /// Свечение цвета игрока за аватаром: круг 420 с центром на 150 + 210 от
    /// верха, цвет `…26` макета — 15 %.
    static let glowSide: CGFloat = 420
    static let glowShare: Double = 0x26 / 255

    /// Плотность колонки iPhone. Макет рассчитан на высокий экран: на
    /// 375 × 667 колонка выше экрана на ≈ 30 pt ещё при стандартном тексте —
    /// SwiftUI её сжимал, `minimumScaleFactor` ужимал имя, а «Меню» уезжало
    /// за край. Тесная — та же колонка с меньшим аватаром и клавишами.
    struct Density {
        let top, gap, avatar, keyHeight: CGFloat

        static let regular = Density(top: HandoffMetrics.top, gap: HandoffMetrics.gap,
                                     avatar: HandoffMetrics.avatar,
                                     keyHeight: HandoffMetrics.keyHeight)
        static let tight = Density(top: 12, gap: 12, avatar: 64, keyHeight: 52)
    }
}

// MARK: - Экран партии

struct DuelScreen: View {

    @Bindable var match: DuelMatch
    /// Возврат с расстановки первого игрока — к настройке, партия не начата.
    var onBackToSetup: () -> Void = {}
    /// Выйти в меню. Идущая партия сохранена и закрыта слоем.
    var onLeave: () -> Void = {}
    var onPlayAgain: () -> Void = {}
    var onMenuAfterResult: () -> Void = {}

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.usesPadLayout) private var usesPadLayout
    @State private var askLeave = false

    private var game: DuelGame { match.game }

    private var alphabet: BoardAlphabet {
        .forLanguage(locale.language.languageCode?.identifier)
    }

    var body: some View {
        ZStack {
            content
                .battleTypeSize()
                // Под слоем экран есть (состояние не пересоздаётся), но его не
                // слышно и не нажать: VoiceOver прочёл бы чужой флот.
                .accessibilityHidden(match.showsHandoff)
                .allowsHitTesting(!match.showsHandoff)

            if match.showsHandoff {
                DuelHandoffLayer(match: match, onMenu: menuTapped)
                    .id(handoffID)
                    .transition(handoffTransition)
                    .zIndex(1)
            }
        }
        .animation(.easeOut(duration: Motion.scaled(Motion.handoverIn, reduceMotion: reduceMotion)),
                   value: match.showsHandoff)
        .animation(Motion.quick.reduced(reduceMotion), value: match.shownField)
        .matchResults(match.result, onPlayAgain: onPlayAgain, onMenu: onMenuAfterResult)
        .modalDialog(isPresented: askLeave) {
            ModalDialog.leaveMatch(.offline,
                                   onStay: { askLeave = false },
                                   onLeave: {
                                       askLeave = false
                                       onLeave()
                                   })
        }
    }

    /// Слой приезжает сверху за 260 и уходит наверх за 180 (`Motion.handover*`);
    /// при Reduce Motion — только прозрачность, вдвое быстрее.
    private var handoffTransition: AnyTransition {
        let edge: AnyTransition = reduceMotion ? .opacity : .move(edge: .top)
        return .asymmetric(
            insertion: edge.animation(.easeOut(duration: Motion.scaled(Motion.handoverIn,
                                                                      reduceMotion: reduceMotion))),
            removal: edge.animation(.easeIn(duration: Motion.scaled(Motion.handoverOut,
                                                                   reduceMotion: reduceMotion))))
    }

    /// Новая передача — новый слой: набранные цифры прошлого не переживают.
    private var handoffID: String {
        "\(game.handoff ?? -1)·\(game.turn)·\(game.stage)"
    }

    @ViewBuilder
    private var content: some View {
        switch game.stage {
        case .arranging(let player):
            arrangement(player)
        case .battle:
            battle
        }
    }

    // MARK: Расстановка

    @ViewBuilder
    private func arrangement(_ player: Int) -> some View {
        let name = match.player(player).name
        let next = match.player(1 - player).name
        let startTitle: LocalizedStringKey = player == 0 ? "\(next) places the fleet" : "Start the battle"
        if usesPadLayout {
            // iPad: стол до старта, напротив — пустое поле соперника (4.4).
            // Возврата нет: «Меню» у первого игрока ведёт к настройке.
            PadTableScreen(phase: .placement(editor: $match.editor, onStart: match.finishArrangement),
                           onMenu: menuTapped,
                           duelPlacement: PadDuelPlacement(ownTitle: "Fleet: \(name)",
                                                           foeName: next,
                                                           startTitle: startTitle))
        } else {
            ArrangementScreen(editor: $match.editor,
                              // Второй игрок к флоту первого не возвращается.
                              backTitle: player == 0 ? "Two players" : nil,
                              title: "Fleet: \(name)",
                              startTitle: startTitle,
                              onStart: match.finishArrangement,
                              onBack: onBackToSetup,
                              onMenu: menuTapped)
        }
    }

    // MARK: Бой

    @ViewBuilder
    private var battle: some View {
        if usesPadLayout {
            // iPad: оба поля сразу, переключателя нет (4.4).
            PadTableScreen(phase: .duel(match), onMenu: menuTapped)
        } else {
            phoneBattle
        }
    }

    private var phoneBattle: some View {
        GeometryReader { proxy in
            let size = Geometry.SizeClass.forWidth(proxy.size.width)
            let metrics = BoardMetrics(cell: size.cell)
            let field = match.shownField

            VStack(spacing: 0) {
                ScorePanel(yourLosses: match.board(.you).sunkShipCount,
                           foeLosses: game.boards[match.opponent].sunkShipCount,
                           isYourTurn: match.isViewersTurn,
                           balance: 0,
                           size: size,
                           status: Text("Turn: \(match.player(game.attacker).name)"),
                           statusIsWarm: match.isViewersTurn,
                           // Баллов у режима нет — баланса тоже (раунд 8).
                           showsBalance: false)
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
                        DuelBoard(match: match, field: field, metrics: metrics, alphabet: alphabet)
                        Spacer(minLength: 0)
                        // «По вам» — только на своём поле (2.8); на слое
                        // передачи её нет, результат живёт здесь (4.7).
                        if field == .you {
                            ShotFeed(title: "Shots at you this round",
                                     entries: match.incoming, alphabet: alphabet)
                                .padding(.horizontal, Geometry.Nav.stackInset)
                                .padding(.bottom, Geometry.Nav.stackGap)
                        }
                    }
                    .padding(.top, top)
                    .frame(width: area.size.width, height: area.size.height)
                }

                BottomStack(onMenu: menuTapped) {
                    HStack(spacing: Geometry.Nav.stackGap) {
                        FieldSwitch(selection: field, size: size) { match.show($0) }
                        // Подсказок вдвоём нет — место занимает только
                        // «Итоги» в просмотре полей после партии.
                        ReviewSlot(size: size, reservesWidth: false) { EmptyView() }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func caption(_ field: Side, size: Geometry.SizeClass) -> some View {
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
            .frame(height: BattleScreenMetrics.captionHeight)
    }

    /// «Меню»: на расстановке первого игрока партии ещё нет — выход сразу
    /// (3.1); дальше — вопрос «Выйти из партии?», партия сохранена.
    private func menuTapped() {
        if game.stage == .arranging(0) {
            onBackToSetup()
        } else if game.isOver {
            onMenuAfterResult()
        } else {
            askLeave = true
        }
    }
}

// MARK: - Поле

/// Поле боя глазами держателя: своё — с флотом, чужое — скрытым, как у
/// компьютера (`opponentView()`). Рамка горит на поле, по которому сейчас
/// стреляют.
struct DuelBoard: View {
    let match: DuelMatch
    let field: Side
    let metrics: BoardMetrics
    let alphabet: BoardAlphabet

    var body: some View {
        let m = metrics
        let board = match.board(field)
        let cells = Board.allCoordinates.map { BoardCellState.forDisplay(board[$0], on: field) }
        let game = match.game
        let isActive = game.isBattle && !game.isOver
            && (field == .foe ? match.isViewersTurn : !match.isViewersTurn)

        return BoardView(cells: cells, role: field, metrics: m, isActive: isActive,
                         alphabet: alphabet,
                         event: match.event(on: field),
                         marks: field == .foe ? match.aim.map { [$0: .aim] } ?? [:] : [:],
                         onTap: field == .foe
                            ? { column, row in match.tap(Coordinate(row: row + 1, column: column + 1)) }
                            : nil)
            .overlay(alignment: .topLeading) {
                if field == .foe, let aim = match.aim {
                    AimMark(at: aim, metrics: m)
                        .frame(width: m.gridSide, height: m.gridSide, alignment: .topLeading)
                        .offset(x: m.inset, y: m.inset)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: m.totalSize.width, height: m.totalSize.height)
            .accessibilityIdentifier(field == .foe ? "duelFoeBoard" : "duelOwnBoard")
    }
}

// MARK: - Слой передачи

/// Непрозрачный слой G1 (4.7): море не просвечивает — под `Glass/Solid`
/// лежит сам градиент моря, у него непрозрачные цвета. Аватар, имя и рамки
/// кода — в цвете игрока, которому передают; под именем номер хода.
/// Клавиатура — только при включённом коде.
struct DuelHandoffLayer: View {
    let match: DuelMatch
    var onMenu: () -> Void = {}

    /// Набранные цифры.
    @State private var digits = ""
    /// Первый ввод при создании кода — второй должен совпасть.
    @State private var firstEntry: String?
    @State private var problem: CodeProblem?

    @Environment(AppState.self) private var appState
    @Environment(\.usesPadLayout) private var usesPadLayout

    enum CodeProblem { case wrong, mismatch }

    private var game: DuelGame { match.game }
    private var target: Int { game.handoff ?? game.viewer }
    private var player: DuelPlayer { match.player(target) }
    private var color: Color { PlayerAvatar.color(player.colorIndex) }

    var body: some View {
        ZStack {
            background
            if usesPadLayout { pad } else { phone }
        }
        .accessibilityIdentifier("duelHandoff")
    }

    /// iPhone (`screen4Handoff`): колонка от верха, «Меню» строкой внизу.
    private var phone: some View {
        VStack(spacing: 0) {
            // Первая раскладка, что помещается по высоте: макет → тесная →
            // тесная с прокруткой (крупный текст на малом экране).
            ViewThatFits(in: .vertical) {
                phoneColumn(.regular)
                phoneColumn(.tight)
                ScrollView { phoneColumn(.tight) }
                    .scrollBounceBehavior(.basedOnSize)
            }
            .frame(maxHeight: .infinity, alignment: .top)

            BottomStack(onMenu: onMenu) {
                if game.codeStep == .none { openButton }
            }
        }
    }

    private func phoneColumn(_ density: HandoffMetrics.Density) -> some View {
        VStack(spacing: 0) {
            column(density)
                .padding(.top, density.top)

            Spacer(minLength: density.gap)

            if game.codeStep != .none {
                footnoteText
                    .padding(.bottom, Geometry.Nav.stackGap)
            }
        }
        .padding(.horizontal, HandoffMetrics.footnoteInset)
    }

    /// iPad: кадра нет. Та же колонка шириной 520 по центру экрана, сноска и
    /// «Открыть поля» — сразу под ней; «Меню» — квадрат в том же углу, что и
    /// на столе под слоем (при своём поле справа — в правом).
    private var pad: some View {
        let mirrored = appState.ownBoardOnRight
        return ZStack(alignment: mirrored ? .bottomTrailing : .bottomLeading) {
            VStack(spacing: HandoffMetrics.gap) {
                column(.regular)
                if game.codeStep != .none {
                    footnoteText
                } else {
                    openButton
                        .padding(.top, HandoffMetrics.gap)
                }
            }
            .padding(.horizontal, HandoffMetrics.footnoteInset)
            .frame(maxWidth: Geometry.Nav.padColumn)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            PadNavTile.menu(onMenu)
                .padding(.horizontal, Geometry.Inset.padFrame)
                .padBottomFrame()
        }
    }

    /// Аватар, имя, код и клавиатура — общая часть обеих раскладок.
    private func column(_ density: HandoffMetrics.Density) -> some View {
        VStack(spacing: density.gap) {
            AvatarDot(glyph: player.glyph, colorIndex: player.colorIndex,
                      size: density.avatar)
                .background { glow }
            heading
            if game.codeStep != .none {
                code
                keypad(keyHeight: density.keyHeight)
            }
        }
    }

    private var footnoteText: some View {
        Text(footnote)
            .font(.scalable(size: HandoffMetrics.footnote))
            .lineSpacing(HandoffMetrics.footnote * 0.5)
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.inkTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var openButton: some View {
        Button { match.open() } label: {
            Text("Open the boards")
        }
        .primaryButton()
        .accessibilityIdentifier("duelOpen")
    }

    // MARK: Фон

    private var background: some View {
        ZStack {
            LinearGradient.sea
            Color.glassSolid
        }
        .ignoresSafeArea()
    }

    /// Свечение цвета игрока — круг 420 с центром в центре аватара. Висит на
    /// аватаре, а не на фоне: так оно идёт за ним в обеих раскладках.
    /// Цвет игрока — содержимое, а не токен (см. `PlayerAvatar`).
    private var glow: some View {
        Circle()
            .fill(RadialGradient(colors: [color.opacity(HandoffMetrics.glowShare), .clear],
                                 center: .center, startRadius: 0,
                                 endRadius: HandoffMetrics.glowSide / 2))
            .frame(width: HandoffMetrics.glowSide, height: HandoffMetrics.glowSide)
            .allowsHitTesting(false)
    }

    // MARK: Кому и какой ход

    /// Имя — в именительном падеже и отдельной строкой: «Передайте телефон
    /// Ане» склоняет имя, а имена приходят любые.
    private var heading: some View {
        VStack(spacing: HandoffMetrics.titleGap) {
            Text(player.name)
                .font(.scalable(size: HandoffMetrics.title, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            subtitle
                .font(.scalable(size: HandoffMetrics.subtitle))
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }

    private var subtitle: Text {
        let stage: Text
        switch game.stage {
        case .arranging:
            stage = Text("Fleet placement")
        case .battle where game.turn == 1:
            stage = game.isCoinToss ? Text("Turn 1 · won the coin toss") : Text("Turn 1 · first move")
        case .battle:
            stage = Text("Turn \(game.turn) · the boards are hidden")
        }
        // Устройство не меняло рук — «передайте» было бы неправдой.
        guard target != game.holder else { return stage }
        let pass = usesPadLayout ? Text("Pass the device") : Text("Pass the phone")
        return Text("\(pass) · \(stage)")
    }

    // MARK: Код

    private var codeTitle: LocalizedStringKey {
        switch game.codeStep {
        case .create: firstEntry == nil ? "Create a code" : "Repeat the code"
        case .enter, .none: "Enter your code"
        }
    }

    private var footnote: LocalizedStringKey {
        switch (game.codeStep == .create, usesPadLayout) {
        case (true, false): "Only you should know it: it is asked every time the phone comes back to you."
        case (true, true): "Only you should know it: it is asked every time the device comes back to you."
        case (false, _): "Without the code the boards stay closed — you can only leave the match."
        }
    }

    private var code: some View {
        VStack(spacing: HandoffMetrics.codeGap) {
            Text(codeTitle)
                .font(.scalable(size: HandoffMetrics.codeLabel, weight: .bold))
                .tracking(HandoffMetrics.codeLabel * 0.12)
                .textCase(.uppercase)
                .foregroundStyle(Color.inkSecondary)
            HStack(spacing: HandoffMetrics.dotGap) {
                ForEach(0..<DuelGame.codeLength, id: \.self) { index in
                    Circle()
                        .strokeBorder(color, lineWidth: 2)
                        .background { Circle().fill(index < digits.count ? color : .clear) }
                        .frame(width: HandoffMetrics.dot, height: HandoffMetrics.dot)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(Text("\(digits.count) of \(DuelGame.codeLength) digits"))

            // Строка ошибки — на своём месте всегда, чтобы клавиатура не прыгала.
            WarningLine(text: problem == .mismatch ? "The codes don't match" : "Wrong code")
                .opacity(problem == nil ? 0 : 1)
                .accessibilityHidden(problem == nil)
        }
        .padding(.top, 6)
    }

    private func keypad(keyHeight: CGFloat) -> some View {
        let columns = Array(repeating: GridItem(.fixed(HandoffMetrics.keyWidth),
                                                spacing: HandoffMetrics.keyGap), count: 3)
        return LazyVGrid(columns: columns, spacing: HandoffMetrics.keyGap) {
            ForEach(1...9, id: \.self) { key(String($0), height: keyHeight) }
            Color.clear.frame(height: keyHeight)
            key("0", height: keyHeight)
            Button(action: deleteDigit) {
                Image(systemName: "delete.left")
                    .font(.system(size: symbolFontSize(inBox: HandoffMetrics.deleteIcon)))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(width: HandoffMetrics.keyWidth, height: keyHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Delete"))
            .accessibilityShowsLargeContentViewer {
                Label("Delete", systemImage: "delete.left")
            }
        }
        .frame(width: HandoffMetrics.keyWidth * 3 + HandoffMetrics.keyGap * 2)
    }

    private func key(_ digit: String, height: CGFloat) -> some View {
        Button { type(digit) } label: {
            Text(verbatim: digit)
                .font(.system(size: HandoffMetrics.keyText, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.inkPrimary)
                .frame(width: HandoffMetrics.keyWidth, height: height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Материалы, а не системное стекло: клавиши на стекле iOS 26 не ехали
        // вместе со слоем и вставали на место раньше него (видно живьём).
        // Под ними глухой слой, так что просвечивать нечему — вид тот же.
        .glassPanel(.g2, radius: HandoffMetrics.keyRadius, treatment: .material)
        .accessibilityIdentifier("duelKey\(digit)")
        .accessibilityShowsLargeContentViewer { Text(verbatim: digit) }
    }

    private func type(_ digit: String) {
        guard digits.count < DuelGame.codeLength else { return }
        problem = nil
        digits += digit
        if match.soundOn { AudioService.shared.play(.click) }
        guard digits.count == DuelGame.codeLength else { return }

        switch game.codeStep {
        case .create:
            if let first = firstEntry {
                if first == digits {
                    match.open(with: digits)
                } else {
                    // Несовпадение — начать заново: какой из двух верный, неизвестно.
                    problem = .mismatch
                    firstEntry = nil
                }
            } else {
                firstEntry = digits
            }
        case .enter:
            if !match.open(with: digits) { problem = .wrong }
        case .none:
            break
        }
        digits = ""
    }

    private func deleteDigit() {
        guard !digits.isEmpty else { return }
        digits.removeLast()
    }
}

// MARK: - Превью

@MainActor
func duelDemoMatch(locks: Bool = false, battle: Bool = true, handoff: Bool = false) -> DuelMatch {
    var game = DuelGame(players: [DuelPlayer(name: "Аня", glyph: "sailboat.fill", colorIndex: 0),
                                  DuelPlayer(name: "Борис", glyph: "helm", colorIndex: 8)],
                        locksWithCode: locks, revealsRing: true,
                        firstMove: .coinToss, firstShooter: 0)
    if locks { game.open(with: "1234") }
    if battle {
        game.finishArrangement(FleetLayout.canonicalLayout())
        game.open(with: locks ? "5678" : nil)
        game.finishArrangement(FleetLayout.canonicalLayout())
        game.open(with: locks ? "1234" : nil)
        // Аня мажет, Борис попадает и мажет — у Ани в ленте его выстрелы.
        game.fire(at: Coordinate(row: 10, column: 10))
        game.open(with: locks ? "5678" : nil)
        for cell in [(1, 1), (1, 2), (9, 9)] {
            game.fire(at: Coordinate(row: cell.0, column: cell.1))
        }
        if !handoff { game.open(with: locks ? "1234" : nil) }
    }
    let match = DuelMatch(game: game, pacing: .instant, persists: false)
    match.soundOn = false
    return match
}

private struct DuelDemo: View {
    @State private var appState = AppState()
    @State private var match: DuelMatch
    var field: Side = .foe
    var pad = false
    var ownOnRight = false

    init(_ match: DuelMatch, field: Side = .foe, pad: Bool = false, ownOnRight: Bool = false) {
        _match = State(initialValue: match)
        self.field = field
        self.pad = pad
        self.ownOnRight = ownOnRight
    }

    var body: some View {
        ZStack {
            SeaBackground()
                .ignoresSafeArea()
            DuelScreen(match: match)
        }
        .environment(appState)
        .environment(\.usesPadLayout, pad)
        .onAppear {
            appState.ownBoardOnRight = ownOnRight
            match.show(field)
        }
    }
}

#Preview("Вдвоём · iPad · бой · вертикально", traits: .fixedLayout(width: 834, height: 1194)) {
    DuelDemo(duelDemoMatch(), pad: true)
        .preferredColorScheme(.dark)
}

#Preview("Вдвоём · iPad · бой · горизонтально", traits: .fixedLayout(width: 1194, height: 834)) {
    DuelDemo(duelDemoMatch(), pad: true)
        .preferredColorScheme(.dark)
}

#Preview("Вдвоём · iPad · передача с кодом", traits: .fixedLayout(width: 1194, height: 834)) {
    DuelDemo(duelDemoMatch(locks: true, handoff: true), pad: true)
        .preferredColorScheme(.dark)
}

#Preview("Вдвоём · iPad · передача без кода", traits: .fixedLayout(width: 834, height: 1194)) {
    DuelDemo(duelDemoMatch(handoff: true), pad: true, ownOnRight: true)
        .preferredColorScheme(.light)
}

#Preview("Вдвоём · iPad · расстановка", traits: .fixedLayout(width: 1194, height: 834)) {
    DuelDemo(duelDemoMatch(battle: false), pad: true)
        .preferredColorScheme(.dark)
}

#Preview("Вдвоём · поле противника") {
    DuelDemo(duelDemoMatch())
        .preferredColorScheme(.dark)
}

#Preview("Вдвоём · своё поле") {
    DuelDemo(duelDemoMatch(), field: .you)
        .preferredColorScheme(.dark)
}

#Preview("Вдвоём · передача с кодом") {
    DuelDemo(duelDemoMatch(locks: true, handoff: true))
        .preferredColorScheme(.dark)
}

#Preview("Вдвоём · передача без кода") {
    DuelDemo(duelDemoMatch(handoff: true))
        .preferredColorScheme(.dark)
}

#Preview("Вдвоём · передача · светлая") {
    DuelDemo(duelDemoMatch(locks: true, handoff: true))
        .preferredColorScheme(.light)
}

#Preview("Вдвоём · код · 375", traits: .fixedLayout(width: 375, height: 667)) {
    DuelDemo(duelDemoMatch(locks: true, handoff: true))
        .preferredColorScheme(.dark)
}

#Preview("Вдвоём · расстановка") {
    DuelDemo(duelDemoMatch(battle: false))
        .preferredColorScheme(.dark)
}
