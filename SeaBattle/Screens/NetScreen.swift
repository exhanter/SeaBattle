//
//  NetScreen.swift
//  Sea Battle — сетевая партия: экран (R3.3, шаг 15)
//
//  Спека 4.8, кадры `screen5NetWait`, `screen5NetLost`, `screen5NetLeft`.
//  Один контейнер на партию, как у игры вдвоём: расстановка, ожидание
//  соперника, бой, итоги и окна поверх. Раскладка боя — та же, что против
//  компьютера (правило 3): `ScorePanel`, поле, лента, переключатель полей
//  и подсказка, `NavRow`.
//
//  - **Ожидание хода** — поле противника в полную яркость, но не нажимается;
//    под ним холодная капсула с таймером хода и лента «По вам». Приглушения
//    нет: не ваш ход показывают статус и капсула.
//  - **Обрыв связи** — баннер на месте панели счёта, поле погашено (0,45 —
//    единственное место, где экран приглушается), под полем пояснение, внизу
//    «Выйти из партии» и «Повторить сейчас».
//  - **Выход соперника** — окно поверх погашенного боя.
//

import SwiftUI

// MARK: - Числа

/// Кадры `screen5NetWait` и `screen5NetLost`.
enum NetMetrics {
    /// Холодная капсула ожидания хода.
    static let waitIcon: CGFloat = 20
    static let waitText: CGFloat = 14.5
    static let waitGap: CGFloat = 10
    static let waitPaddingV: CGFloat = 10
    static let waitPaddingH: CGFloat = 18
    /// Поле при оборванной связи.
    static let lostDim: Double = 0.45
    /// Баннер обрыва.
    static let bannerRadius: CGFloat = 20
    static let bannerPaddingV: CGFloat = 13
    static let bannerPaddingH: CGFloat = 15
    static let bannerIcon: CGFloat = 26
    static let bannerTitle: CGFloat = 14.5
    static let bannerSubtitle: CGFloat = 12
    static let bannerTime: CGFloat = 12
    static let bannerGlow: CGFloat = 13          // CSS 0 0 26
    /// Пояснение под полем.
    static let noteRadius: CGFloat = 18
    static let noteText: CGFloat = 12.5
    /// Окно «Соперник вышел».
    static let noticeIcon: CGFloat = 42

    /// Место под капсулой ожидания: сама капсула и зазор до ленты. Поле
    /// считается так, будто они есть всегда, — при смене хода оно не прыгает.
    static var waitBlock: CGFloat { waitIcon + waitPaddingV * 2 + Geometry.Nav.stackGap * 1.5 }
}

/// «0:18» — минуты и секунды, без часов: ход дольше часа не ждут.
func netClock(_ duration: Duration) -> String {
    let seconds = max(0, Int(duration.components.seconds))
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
}

// MARK: - Экран

struct NetScreen: View {

    @Bindable var match: NetMatch
    /// Партия закрыта — в меню.
    var onExit: () -> Void = {}
    /// Флот расставляют заранее по своему коду — строка возврата к коду.
    var onBackToCode: (() -> Void)?

    @Environment(\.locale) private var locale
    @Environment(\.usesPadLayout) private var usesPadLayout
    @State private var askLeave = false

    private var game: NetGame { match.game }

    private var alphabet: BoardAlphabet {
        .forLanguage(locale.language.languageCode?.identifier)
    }

    var body: some View {
        content
            .animation(Motion.quick, value: match.shownField)
            .animation(Motion.quick, value: match.link)
            .matchResults(match.result, onPlayAgain: match.playAgain, onMenu: exit)
            .modalDialog(isPresented: askLeave) {
                ModalDialog.leaveMatch(.network,
                                       onStay: { askLeave = false },
                                       onLeave: {
                                           askLeave = false
                                           match.leave()
                                           onExit()
                                       })
            }
            .modalDialog(isPresented: match.notice != nil) {
                if let notice = match.notice {
                    NetNoticeDialog(notice: notice,
                                    onResults: match.showResult,
                                    onMenu: exit)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if game.stage == .arranging && !game.isReady {
            arrangement
        } else if usesPadLayout {
            PadTableScreen(phase: .network(match), onMenu: menuTapped)
        } else {
            phoneBattle
        }
    }

    // MARK: Расстановка

    /// Флот расставляют заранее, пока соперника ещё нет (4.4): «Начать»
    /// заблокирована и говорит, чего ждёт.
    private var startTitle: LocalizedStringKey {
        match.hasOpponent ? "Start" : "Waiting for an opponent"
    }

    @ViewBuilder
    private var arrangement: some View {
        if usesPadLayout {
            PadTableScreen(phase: .placement(editor: $match.editor, onStart: match.finishArrangement),
                           onMenu: menuTapped,
                           duelPlacement: PadDuelPlacement(ownTitle: "Your fleet",
                                                           foeName: match.opponentName,
                                                           startTitle: startTitle),
                           startEnabled: match.hasOpponent)
        } else {
            // Возврат — только к коду, пока соперника нет; когда он
            // подключился, выход — только «Меню».
            ArrangementScreen(editor: $match.editor,
                              backTitle: onBackToCode != nil && !match.hasOpponent ? "Code" : nil,
                              startTitle: startTitle,
                              onStart: match.finishArrangement,
                              onBack: { onBackToCode?() },
                              onMenu: menuTapped,
                              startEnabled: match.hasOpponent)
        }
    }

    // MARK: Бой, iPhone

    private var phoneBattle: some View {
        GeometryReader { proxy in
            let size = Geometry.SizeClass.forWidth(proxy.size.width)
            let metrics = BoardMetrics(cell: size.cell)
            let field = match.shownField
            let lost = match.link.isLost

            VStack(spacing: 0) {
                Group {
                    if lost {
                        NetLostBanner(match: match)
                            .padding(.horizontal, BattleMetrics.forSize(size).scoreInset)
                    } else {
                        // На 375 капсуле под полем места нет — таймер в статусе.
                        NetScorePanel(match: match, size: size, showsClock: size.isCompact)
                    }
                }
                .padding(.top, BattleScreenMetrics.scoreTop)

                GeometryReader { area in
                    let feed = ShotFeed.height + Geometry.Nav.stackGap
                        + (size.isCompact ? 0 : NetMetrics.waitBlock)
                    let boardBlock = BattleScreenMetrics.captionHeight
                        + BattleScreenMetrics.captionGap + metrics.totalSize.height
                    let top = BattleScreenMetrics.boardTop(available: area.size.height,
                                                          board: boardBlock, feed: feed)
                    VStack(spacing: 0) {
                        caption(field, size: size)
                            .padding(.bottom, BattleScreenMetrics.captionGap)
                        NetBoard(match: match, field: field, metrics: metrics, alphabet: alphabet)
                            .opacity(lost ? NetMetrics.lostDim : 1)
                        Spacer(minLength: 0)
                        underBoard(field, lost: lost, capsule: !size.isCompact)
                            .padding(.horizontal, Geometry.Nav.stackInset)
                            .padding(.bottom, Geometry.Nav.stackGap)
                    }
                    .padding(.top, top)
                    .frame(width: area.size.width, height: area.size.height)
                }

                BottomStack(onMenu: menuTapped) {
                    if lost {
                        lostActions
                    } else {
                        HStack(spacing: Geometry.Nav.stackGap) {
                            FieldSwitch(selection: field, size: size) { match.show($0) }
                            // Подсказка — на своём ходу и не против своего
                            // аккаунта; в ожидании строка только переключателя.
                            if field == .foe && match.isMyTurn && match.offersHint {
                                BattleHintButton(cost: match.hintCost,
                                                 isEnabled: match.canUseHint,
                                                 size: size) { match.requestHint() }
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    /// Под полем: при обрыве — пояснение; в ожидании на поле противника —
    /// капсула с таймером и лента; на своём поле — лента.
    @ViewBuilder
    private func underBoard(_ field: Side, lost: Bool, capsule: Bool) -> some View {
        if lost {
            NetLostNote()
        } else if field == .you || game.isBattle && !game.isMyTurn && !capsule {
            ShotFeed(title: "Shots at you this round", entries: match.incoming, alphabet: alphabet)
        } else if game.isBattle && !game.isMyTurn && capsule {
            VStack(spacing: Geometry.Nav.stackGap * 1.5) {
                NetWaitCapsule(since: match.turnStarted)
                ShotFeed(title: "Shots at you this round", entries: match.incoming, alphabet: alphabet)
            }
        }
    }

    private var lostActions: some View {
        HStack(spacing: Geometry.Nav.stackGap) {
            Button {
                match.leave()
                onExit()
            } label: {
                Text("Leave the match")
            }
            .secondaryButton()
            Button { match.retryNow() } label: {
                Label("Retry now", systemImage: "arrow.clockwise")
            }
            .secondaryButton()
        }
    }

    private func caption(_ field: Side, size: Geometry.SizeClass) -> some View {
        Group {
            if field == .foe && !match.opponentName.isEmpty {
                Text(verbatim: match.opponentName)
            } else {
                Text(field == .foe ? "Opponent's board" : "Your fleet")
            }
        }
        .font(.system(size: BattleMetrics.forSize(size).caption, weight: .semibold, design: .rounded))
        .foregroundStyle(Color.inkPrimary)
        .lineLimit(1)
        .shadow(color: .inkTitleShadow,
                radius: NavMetrics.titleShadowRadius,
                y: NavMetrics.titleShadowOffsetY)
        // Подпись поля — заголовок: VoiceOver прыгает по ним ротором, и
        // это единственное имя поля (у `BoardView` своего нет).
        .accessibilityAddTraits(.isHeader)
        .frame(height: BattleScreenMetrics.captionHeight)
    }

    // MARK: Выход

    /// «Меню»: посреди боя при живой связи — вопрос «Сдаться и выйти?»; до
    /// боя, после него и при оборванной связи — выход сразу: сдаваться там
    /// нечему (3.1, 4.8).
    private func menuTapped() {
        if game.isBattle && match.link == .connected {
            askLeave = true
        } else {
            match.leave()
            onExit()
        }
    }

    private func exit() {
        match.close()
        onExit()
    }
}

// MARK: - Панель счёта

/// `ScorePanel` сетевой партии: до боя — «Ждём» (соперник расставляет флот) на
/// стекле, в бою — как против компьютера, с балансом (подсказки есть).
struct NetScorePanel: View {
    let match: NetMatch
    var size: Geometry.SizeClass = .regular
    var isPad = false
    var yoursOnTrailing = false
    /// Таймер хода соперника в самом статусе — на iPad и на 375, где под
    /// полем капсуле места нет.
    var showsClock = false

    var body: some View {
        TimelineView(.periodic(from: match.turnStarted, by: 1)) { context in
            ScorePanel(yourLosses: match.board(.you).sunkShipCount,
                       foeLosses: match.board(.foe).sunkShipCount,
                       isYourTurn: match.isMyTurn,
                       balance: ProgressStore.shared.points,
                       size: size,
                       isPad: isPad,
                       yoursOnTrailing: yoursOnTrailing,
                       status: status(at: context.date),
                       statusIsWarm: match.game.isBattle ? match.isMyTurn : false,
                       showsBalance: match.offersHint)
        }
    }

    private func status(at date: Date) -> Text? {
        let game = match.game
        // Коротко: центр панели не сжимается (`fixedSize`), и «Соперник
        // расставляет флот» раздвигал панель за край экрана (поймано живьём).
        if game.stage == .arranging { return Text("Waiting") }
        if (isPad || showsClock) && game.isBattle && !game.isMyTurn {
            let clock = netClock(.seconds(date.timeIntervalSince(match.turnStarted)))
            return Text("\(Text("Opponent's turn")) · \(clock)")
        }
        return nil
    }
}

// MARK: - Поле

/// Поле сетевой партии: своё — с флотом, чужое — каким его знает игрок по
/// ответам соперника. Рамка горит на поле, по которому сейчас стреляют.
struct NetBoard: View {
    let match: NetMatch
    let field: Side
    let metrics: BoardMetrics
    let alphabet: BoardAlphabet

    var body: some View {
        let m = metrics
        let board = match.board(field)
        let cells = Board.allCoordinates.map { BoardCellState.forDisplay(board[$0], on: field) }
        let isActive = match.game.isBattle && !match.link.isLost
            && (field == .foe ? match.isMyTurn : !match.isMyTurn)

        return BoardView(cells: cells, role: field, metrics: m, isActive: isActive,
                         alphabet: alphabet,
                         event: match.event(on: field),
                         marks: field == .foe ? accessibilityMarks : [:],
                         onTap: field == .foe
                            ? { column, row in match.tap(Coordinate(row: row + 1, column: column + 1)) }
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
            .accessibilityIdentifier(field == .foe ? "netFoeBoard" : "netOwnBoard")
    }

    /// Те же метки, что рисует `marks`, — значением клеток для VoiceOver.
    private var accessibilityMarks: [Coordinate: BoardMark] {
        let board = match.board(.foe)
        var result: [Coordinate: BoardMark] = [:]
        for cell in match.game.revealed where board[cell].isUnshot { result[cell] = .hint }
        if let aim = match.aim { result[aim] = .aim }
        return result
    }

    /// Прицел и клетки, открытые подсказкой, — как в бою против компьютера.
    private var marks: some View {
        let m = metrics
        let board = match.board(.foe)
        return ZStack(alignment: .topLeading) {
            ForEach(Array(match.game.revealed.filter { board[$0].isUnshot }), id: \.self) { cell in
                let origin = m.cellOrigin(cell)
                Image(systemName: "target")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.roleYou)
                    .frame(width: m.cell * BattleScreenMetrics.hintMark,
                           height: m.cell * BattleScreenMetrics.hintMark)
                    .frame(width: m.cell, height: m.cell)
                    .offset(x: origin.x, y: origin.y)
                    // Метка — значение клетки (`BoardView.marks`), картинка
                    // VoiceOver не нужна.
                    .accessibilityHidden(true)
            }
            if let aim = match.aim {
                AimMark(at: aim, metrics: m)
            }
        }
    }
}

// MARK: - Ожидание хода

/// Холодная капсула «Ход соперника · 0:18» (кадр `screen5NetWait`): обводка
/// `Role/Foe`, заливка `Role/FoeSoft`, песочные часы.
struct NetWaitCapsule: View {
    let since: Date

    var body: some View {
        TimelineView(.periodic(from: since, by: 1)) { context in
            HStack(spacing: NetMetrics.waitGap) {
                Image(systemName: "hourglass")
                    .font(.system(size: symbolFontSize(inBox: NetMetrics.waitIcon)))
                    .frame(height: NetMetrics.waitIcon)
                Text("\(Text("Opponent's turn")) · \(netClock(.seconds(context.date.timeIntervalSince(since))))")
                    .font(.system(size: NetMetrics.waitText, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(Color.inkPrimary)
            .padding(.vertical, NetMetrics.waitPaddingV)
            .padding(.horizontal, NetMetrics.waitPaddingH)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.roleFoeSoft)
                    .overlay { Capsule(style: .continuous).strokeBorder(Color.roleFoe, lineWidth: 1) }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Обрыв связи

/// Баннер на месте панели счёта (кадр `screen5NetLost`): огненная кромка,
/// номер попытки и сколько партия ещё ждёт.
struct NetLostBanner: View {
    let match: NetMatch
    var isPad = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: symbolFontSize(inBox: NetMetrics.bannerIcon)))
                    .foregroundStyle(Color.fire)
                    .frame(width: NetMetrics.bannerIcon, height: NetMetrics.bannerIcon)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connection lost")
                        .font(.system(size: NetMetrics.bannerTitle, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.inkPrimary)
                    Text("Reconnecting · attempt \(attempt) of \(NetPacing.live.attempts)")
                        .font(.system(size: NetMetrics.bannerSubtitle))
                        .foregroundStyle(Color.inkSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // Сколько партия ещё ждёт — не сколько уже прошло: важно,
                // когда она закроется (решение R3.3).
                Text(verbatim: netClock(match.remaining(at: context.date)))
                    .font(.system(size: NetMetrics.bannerTime, design: .monospaced))
                    .foregroundStyle(Color.inkSecondary)
            }
            .padding(.vertical, NetMetrics.bannerPaddingV)
            .padding(.horizontal, NetMetrics.bannerPaddingH)
            .frame(minHeight: isPad ? PadTableGeometry.topPanelHeight : nil)
            .glassPanel(.g2, radius: NetMetrics.bannerRadius)
            .overlay {
                RoundedRectangle(cornerRadius: NetMetrics.bannerRadius, style: .continuous)
                    .strokeBorder(Color.fire, lineWidth: 1)
            }
            .shadow(color: .fireSoft, radius: NetMetrics.bannerGlow)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("netLostBanner")
    }

    private var attempt: Int {
        if case .lost(_, let attempt) = match.link { return attempt }
        return 1
    }
}

/// Пояснение под погашенным полем: партия не потеряна, и что будет, если
/// связь не вернётся.
struct NetLostNote: View {
    var body: some View {
        Text("The match is saved: if the connection returns within two minutes, the turn and the score stay as they were. If it never returns, the match closes without a win for either side.")
            .font(.system(size: NetMetrics.noteText))
            .lineSpacing(NetMetrics.noteText * 0.5)
            .foregroundStyle(Color.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 13)
            .padding(.horizontal, 15)
            .glassPanel(.g2, radius: NetMetrics.noteRadius)
    }
}

// MARK: - Окна

/// Окно поверх погашенного боя (кадр `screen5NetLeft`): значок, заголовок,
/// пояснение и одна-две кнопки. Устроено как `ModalDialog`, плюс значок.
struct NetNoticeDialog: View {
    let notice: NetNotice
    var onResults: () -> Void = {}
    var onMenu: () -> Void = {}

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: symbolFontSize(inBox: NetMetrics.noticeIcon)))
                .foregroundStyle(Color.inkPrimary)
                .frame(height: NetMetrics.noticeIcon)
            VStack(spacing: ModalMetrics.titleGap) {
                Text(title)
                    .font(TypeScale.headline)
                    .foregroundStyle(Color.inkPrimary)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(TypeScale.footnote)
                    .lineSpacing(ModalMetrics.messageLineSpacing)
                    .foregroundStyle(Color.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: Geometry.Nav.stackGap) {
                if notice == .opponentLeft(won: true) {
                    Button(action: onResults) { Text("See results") }
                        .primaryButton()
                        .accessibilityIdentifier("netResults")
                    Button(action: onMenu) { Text("To menu") }
                        .secondaryButton()
                } else {
                    Button(action: onMenu) { Text("To menu") }
                        .primaryButton()
                }
            }
            .padding(.top, 2)
        }
        .padding(ModalMetrics.padding)
        .glassPanel(.g3, radius: ModalMetrics.radius)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("netNotice")
    }

    private var icon: String {
        switch notice {
        case .opponentLeft: "person.fill.xmark"
        case .connectionClosed: "wifi.slash"
        case .incompatible: "exclamationmark.arrow.triangle.2.circlepath"
        }
    }

    private var title: LocalizedStringKey {
        switch notice {
        case .opponentLeft: "Opponent left"
        case .connectionClosed: "The connection did not return"
        case .incompatible: "Different app versions"
        }
    }

    private var message: LocalizedStringKey {
        switch notice {
        case .opponentLeft(won: true):
            "Your opponent left the match on purpose, so the win is yours."
        case .opponentLeft(won: false):
            "Your opponent left. Nothing is counted — the battle had not started."
        case .connectionClosed:
            "The match is closed without a win for either side."
        case .incompatible:
            "Update the app on both devices to play together."
        }
    }
}

// MARK: - Превью

@MainActor
func netDemoMatch(waiting: Bool = false, lost: Bool = false,
                  notice: Bool = false, arranging: Bool = false) -> NetMatch {
    let (a, b) = LoopbackTransport.pair()
    let me = NetMatch(transport: a, statKey: .nearby,
                      me: NetMatch.hello(name: "Вы", glyph: "sailboat.fill", colorIndex: 0, accountID: "me"),
                      records: false)
    let foe = NetMatch(transport: b, statKey: .nearby,
                       me: NetMatch.hello(name: "Борис", glyph: "helm", colorIndex: 8, accountID: "boris"),
                       records: false)
    for match in [me, foe] {
        match.soundOn = false
        match.editor = FleetEditor(ships: FleetLayout.canonicalLayout())
        match.start()
    }
    guard !arranging else { return me }
    me.finishArrangement()
    foe.finishArrangement()
    // Несколько выстрелов в обе стороны: промах, попадание, чужие выстрелы.
    let water = Board.allCoordinates.filter { Board(ships: FleetLayout.canonicalLayout())[$0] == .water }
    let hull = FleetLayout.canonicalLayout().first { $0.length == 4 }!.cells
    if !me.isMyTurn { foe.tap(water[5]) }
    me.tap(hull[0])
    me.tap(water[0])
    foe.tap(hull[1])
    foe.tap(water[3])
    if waiting || lost || notice { me.tap(water[9]) }
    if lost { a.cut() }
    if notice { foe.leave() }
    return me
}

private struct NetDemo: View {
    @State private var appState = AppState()
    @State private var match: NetMatch
    var pad = false

    init(_ match: NetMatch, field: Side = .foe, pad: Bool = false) {
        match.show(field)
        _match = State(initialValue: match)
        self.pad = pad
    }

    var body: some View {
        ZStack {
            SeaBackground()
                .ignoresSafeArea()
            NetScreen(match: match)
        }
        .environment(appState)
        .environment(\.usesPadLayout, pad)
    }
}

#Preview("Сеть · ваш ход") {
    NetDemo(netDemoMatch())
        .preferredColorScheme(.dark)
}

#Preview("Сеть · ожидание хода") {
    NetDemo(netDemoMatch(waiting: true))
        .preferredColorScheme(.dark)
}

#Preview("Сеть · своё поле") {
    NetDemo(netDemoMatch(waiting: true), field: .you)
        .preferredColorScheme(.dark)
}

#Preview("Сеть · обрыв связи") {
    NetDemo(netDemoMatch(lost: true))
        .preferredColorScheme(.dark)
}

#Preview("Сеть · соперник вышел") {
    NetDemo(netDemoMatch(notice: true))
        .preferredColorScheme(.dark)
}

#Preview("Сеть · ожидание · светлая") {
    NetDemo(netDemoMatch(waiting: true))
        .preferredColorScheme(.light)
}

#Preview("Сеть · 375", traits: .fixedLayout(width: 375, height: 667)) {
    NetDemo(netDemoMatch(waiting: true))
        .preferredColorScheme(.dark)
}

#Preview("Сеть · iPad · ожидание", traits: .fixedLayout(width: 1194, height: 834)) {
    NetDemo(netDemoMatch(waiting: true), pad: true)
        .preferredColorScheme(.dark)
}

#Preview("Сеть · iPad · обрыв", traits: .fixedLayout(width: 834, height: 1194)) {
    NetDemo(netDemoMatch(lost: true), pad: true)
        .preferredColorScheme(.dark)
}
