//
//  PaperScreen.swift
//  Sea Battle — игра на бумаге, iPhone (R3.1, шаг 11 порядка сборки)
//
//  Спека 4.6 после раунда 8, кадры 23a–23c (`screen23Phone`, `screen23Small`).
//  Раскладка боя (правило 3):
//
//  - верх — `ScorePanel` **без баланса** (подсказок здесь нет): «Кто начинает?»
//    до первого хода, «Скажите: Д7», пока выстрел назван, иначе чей ход;
//  - центр — подпись и поле B2, **сетка по центру экрана**, цифры висят в левом
//    отступе; под полем одно место 72 pt: ответы, капсула результата хода
//    соперника (только под своим полем) или подсказка, что делать. Поле стоит
//    на одном уровне на всех тактах;
//  - низ — переключатель полей и «Отменить», последней строкой `NavRow`.
//
//  Поле, капсула, ответы и «Отменить» — общие со столом iPad (`PadTableScreen`,
//  фаза `.paper`), там они стоят по-своему.
//

import SwiftUI

// MARK: - Числа

enum PaperMetrics {
    /// Капсула результата — кадр `paperCapsule`: 27 pt (24 на 375 и в панели
    /// iPad), поля 0,4 и 1,26 кегля.
    static let capsuleText: CGFloat = 27
    static let compactCapsuleText: CGFloat = 24
    static let padCapsuleText: CGFloat = 24
    static let capsulePaddingV: CGFloat = 0.4
    static let capsulePaddingH: CGFloat = 1.26
    /// Свечение капсулы: 0 0 26.
    static let capsuleGlow: CGFloat = 13
    /// Подсказка под полем — 13,5 (12,5 на 375), межстрочный 1,4, не шире 320.
    static let promptText: CGFloat = 13.5
    static let compactPromptText: CGFloat = 12.5
    static let promptWidth: CGFloat = 320
    /// Место под полем — одно на ответы, капсулу и подсказку.
    static let slotHeight: CGFloat = 72
    /// Кнопки ответа — кадр `answerBtn`: 56 / 52, кегль 14,5 / 13,5, значок
    /// 21 / 19, зазор 8 / 6 (В29: как в кадре, до шлифовки дизайна).
    static func answerHeight(_ size: Geometry.SizeClass) -> CGFloat { size.isCompact ? 52 : 56 }
    static func answerText(_ size: Geometry.SizeClass) -> CGFloat { size.isCompact ? 13.5 : 14.5 }
    static func answerIcon(_ size: Geometry.SizeClass) -> CGFloat { size.isCompact ? 19 : 21 }
    static func answerGap(_ size: Geometry.SizeClass) -> CGFloat { size.isCompact ? 6 : 8 }

    /// Метка попадания соперника: 9 % клетки, не тоньше 2,5, наружу на 3 pt,
    /// свечение половиной клетки снаружи и 6 pt внутри.
    static let markRatio: CGFloat = 0.09
    static let markMinStroke: CGFloat = 2.5
    static let markOutset: CGFloat = 3
    static let markInnerGlow: CGFloat = 6

    static func markStroke(for cell: CGFloat) -> CGFloat {
        max(markMinStroke, cell * markRatio)
    }
}

// MARK: - Экран

struct PaperScreen: View {

    let match: PaperMatch
    var onLeave: () -> Void = {}
    /// «Завершить партию» в окне выхода: партия удаляется без результата.
    var onEnd: () -> Void = {}
    var onPlayAgain: () -> Void = {}
    var onMenuAfterResult: () -> Void = {}

    @Environment(\.locale) private var locale
    @Environment(\.usesPadLayout) private var usesPadLayout
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var askLeave = false

    private var game: PaperGame { match.game }

    private var alphabet: BoardAlphabet {
        .forLanguage(locale.language.languageCode?.identifier)
    }

    var body: some View {
        Group {
            if usesPadLayout {
                // iPad: третья фаза стола на два поля (23d, 23e).
                PadTableScreen(phase: .paper(match), onMenu: menuTapped)
            } else {
                phone
            }
        }
        .battleTypeSize()
        // Флота соперника на бумаге приложение не знает — на чужом поле только
        // ваши выстрелы. Целиком известно своё поле: его и показываем
        // (заказчик, 07.10).
        .matchResults(match.result, onPlayAgain: onPlayAgain, onMenu: onMenuAfterResult,
                      prepareReview: { match.show(.you) })
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
        .animation(Motion.quick.reduced(reduceMotion), value: match.shownField)
        .animation(Motion.quick.reduced(reduceMotion), value: game.aim)
    }

    private var phone: some View {
        GeometryReader { proxy in
            let size = Geometry.SizeClass.forWidth(proxy.size.width)
            let metrics = BoardMetrics(cell: size.cellCoords, coordinates: true)
            let field = match.shownField

            VStack(spacing: 0) {
                PaperScorePanel(match: match, alphabet: alphabet, size: size, callsInPanel: false)
                    .padding(.top, BattleScreenMetrics.scoreTop)

                GeometryReader { area in
                    let slot = PaperMetrics.slotHeight + Geometry.Nav.stackGap
                    let caption = BattleScreenMetrics.captionHeight + BattleScreenMetrics.captionGap
                    let top = BattleScreenMetrics.boardTop(available: area.size.height,
                                                          board: caption + metrics.totalSize.height,
                                                          feed: slot)
                    VStack(spacing: 0) {
                        fieldCaption(field, size: size)
                            .padding(.bottom, BattleScreenMetrics.captionGap)
                        PaperBoard(match: match, field: field, metrics: metrics,
                                   alphabet: alphabet)
                        Spacer(minLength: 0)
                        place(field, size: size)
                            .frame(height: PaperMetrics.slotHeight)
                            .padding(.horizontal, Geometry.Nav.stackInset)
                            .padding(.bottom, Geometry.Nav.stackGap)
                    }
                    .padding(.top, top)
                    .frame(width: area.size.width, height: area.size.height)
                }

                actions(field, size: size)
            }
        }
    }

    /// Клетка названа — вместо подписи поля крупно её координата (заказчик
    /// 08.10: в шапке её приходилось искать глазами). Высота строки та же,
    /// поле не сдвигается.
    @ViewBuilder
    private func fieldCaption(_ field: Side, size: Geometry.SizeClass) -> some View {
        if field == .foe, let aim = game.aim {
            PaperCallCaption(label: ShotChip.label(aim, alphabet: alphabet))
                .frame(height: BattleScreenMetrics.captionHeight)
                .transition(.opacity)
        } else {
            plainCaption(field, size: size)
        }
    }

    private func plainCaption(_ field: Side, size: Geometry.SizeClass) -> some View {
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

    // MARK: Место под полем

    /// Ответы — сразу, как только назвали клетку; капсула — только под своим
    /// полем (результат хода соперника); иначе подсказка, что делать (23a).
    @ViewBuilder
    private func place(_ field: Side, size: Geometry.SizeClass) -> some View {
        if field == .foe, game.aim != nil {
            PaperAnswerRow(size: size) { match.answer($0) }
                .transition(.opacity)
        } else if field == .you, let call = game.opponentCall {
            PaperResultCapsule(call: call,
                               text: size.isCompact ? PaperMetrics.compactCapsuleText
                                                    : PaperMetrics.capsuleText)
                .id(game.moves)
                .transition(.opacity)
        } else {
            Text(PaperPrompt.text(for: field, in: game))
                .font(.system(size: size.isCompact ? PaperMetrics.compactPromptText
                                                   : PaperMetrics.promptText))
                .lineSpacing(3)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: PaperMetrics.promptWidth)
                .transition(.opacity)
        }
    }

    // MARK: Низ

    private func actions(_ field: Side, size: Geometry.SizeClass) -> some View {
        BottomStack(onMenu: menuTapped) {
            HStack(spacing: Geometry.Nav.stackGap) {
                FieldSwitch(selection: field, size: size) { match.show($0) }
                ReviewSlot(size: size) {
                    PaperUndoButton(isEnabled: match.canUndo, size: size) { match.undo() }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Идущая партия — вопрос «Выйти из партии?» (3.1): она сохранена и
    /// продолжается из меню. После итогов — сразу.
    private func menuTapped() {
        if game.isOver {
            onLeave()
        } else {
            askLeave = true
        }
    }
}

// MARK: - Шапка

/// `ScorePanel` игры на бумаге: без баланса; «Кто начинает?» и «Ход
/// соперника» на стекле, свой ход и «Скажите: Д7» — на латуни (23a).
struct PaperScorePanel: View {
    let match: PaperMatch
    let alphabet: BoardAlphabet
    var size: Geometry.SizeClass = .regular
    var isPad = false
    var yoursOnTrailing = false
    /// «Скажите: Д7» в центре панели — только iPad. На iPhone координата
    /// с 08.10 стоит над полем, а панель пишет «Ваш ход» (заказчик: «Ждём
    /// ответа» врёт, пока игрок ещё думает, называть ли клетку).
    var callsInPanel = true

    private var game: PaperGame { match.game }

    var body: some View {
        ScorePanel(yourLosses: game.own.sunkShipCount,
                   foeLosses: game.foe.sunkShipCount,
                   isYourTurn: game.turn != .foe,
                   balance: 0,
                   size: size,
                   isPad: isPad,
                   yoursOnTrailing: yoursOnTrailing,
                   status: status,
                   statusIsWarm: game.aim != nil || game.turn == .you,
                   showsBalance: false,
                   // iPad: результат хода соперника — в центре панели (23d, 23e).
                   result: isPad ? game.opponentCall : nil)
    }

    private var status: Text {
        if let aim = game.aim {
            return callsInPanel ? Text("Say: \(ShotChip.label(aim, alphabet: alphabet))") : Text("Your turn")
        }
        switch game.turn {
        case nil: return Text("Who starts?")
        case .you: return Text("Your turn")
        case .foe: return Text("Opponent's turn")
        }
    }
}

// MARK: - Подсказка под полем

enum PaperPrompt {
    static func text(for field: Side, in game: PaperGame) -> LocalizedStringKey {
        switch (field, game.turn) {
        case (.foe, nil):
            "You call first — tap a cell here. Your opponent first — open “My board”"
        case (.foe, .you):
            "Tap the cell you call out"
        case (.foe, .foe):
            "Your opponent is shooting"
        case (.you, .you):
            "Your turn to shoot"
        case (.you, _):
            "Tap the cell your opponent calls"
        }
    }
}

// MARK: - Поле

/// Поле игры на бумаге: B2, прицел и подсветка буквы и цифры названной
/// клетки, метка последнего попадания соперника. **Сетка по центру**: справа
/// оставлен отступ шириной столбика цифр, и цифры висят в левом отступе
/// (раунд 8). Касание своего поля — выстрел соперника, чужого — ваш.
struct PaperBoard: View {
    let match: PaperMatch
    let field: Side
    let metrics: BoardMetrics
    let alphabet: BoardAlphabet
    /// Горизонтальный стол iPad: там сетки стоят на равных отступах, и
    /// уравновешивать цифры справа не нужно.
    var centersGrid = true

    private var game: PaperGame { match.game }

    var body: some View {
        let m = metrics
        let board = field == .foe ? game.foe : game.own
        let cells = Board.allCoordinates.map { BoardCellState.forDisplay(board[$0], on: field) }
        let accepts = field == .foe ? game.acceptsYourShot : game.acceptsOpponentShot
        // Буква и цифра горят у названной клетки, а на своём поле — у клетки,
        // которую назвал соперник последней.
        let marked = field == .foe ? game.aim : lastShot
        let isActive = accepts && (game.turn != nil || match.shownField == field)
        let gridOrigin = CGPoint(x: m.digitsWidth + m.axisGap + m.inset,
                                 y: m.lettersHeight + m.axisGap + m.inset)

        return BoardView(cells: cells, role: field, metrics: m, isActive: isActive,
                         aim: marked.map { (column: $0.column - 1, row: $0.row - 1) },
                         alphabet: alphabet,
                         event: match.event(on: field),
                         marks: (field == .foe ? game.aim : game.foeMark).map { [$0: .aim] } ?? [:],
                         onTap: accepts ? { column, row in
                             let cell = Coordinate(row: row + 1, column: column + 1)
                             if field == .foe { match.tapFoe(cell) } else { match.tapOwn(cell) }
                         } : nil)
            .overlay(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    if field == .foe, let aim = game.aim {
                        AimMark(at: aim, metrics: m)
                    }
                    if field == .you, let mark = game.foeMark {
                        FoeMark(at: mark, metrics: m)
                    }
                }
                .frame(width: m.gridSide, height: m.gridSide, alignment: .topLeading)
                .offset(x: gridOrigin.x, y: gridOrigin.y)
                .allowsHitTesting(false)
            }
            .frame(width: m.totalSize.width, height: m.totalSize.height)
            .padding(.trailing, centersGrid ? m.digitsWidth + m.axisGap : 0)
            .accessibilityIdentifier(field == .foe ? "paperFoeBoard" : "paperOwnBoard")
    }

    private var lastShot: Coordinate? {
        guard let last = game.last, last.field == field else { return nil }
        return last.coordinate
    }
}

/// Названная клетка над полем — латунная капсула с координатой. Строка
/// подписи 22 pt, капсула выше и выходит в зазоры над и под ней.
struct PaperCallCaption: View {
    let label: String

    var body: some View {
        Text(verbatim: label)
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Color.roleYou)
            .padding(.horizontal, 18)
            .padding(.vertical, 2)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.glassFill)
                    .overlay { Capsule(style: .continuous).strokeBorder(Color.roleYou, lineWidth: 1) }
            }
            .shadow(color: .roleYouSoft, radius: 10)
            .contentTransition(.numericText())
            .fixedSize()
            .accessibilityLabel(Text("Say: \(label)"))
            .accessibilityAddTraits(.isHeader)
    }
}

/// Метка последнего попадания соперника (4.6, раунд 8): рамка прицела 2.18 в
/// цвете соперника, наружу на 3 pt, радиус клетки + 3, со свечением снаружи и
/// внутри.
struct FoeMark: View {
    let coordinate: Coordinate
    let metrics: BoardMetrics

    init(at coordinate: Coordinate, metrics: BoardMetrics) {
        self.coordinate = coordinate
        self.metrics = metrics
    }

    var body: some View {
        let m = metrics
        let origin = m.cellOrigin(coordinate)
        let outset = PaperMetrics.markOutset
        let side = m.cell + outset * 2
        let shape = RoundedRectangle(cornerRadius: Geometry.cellRadius(for: m.cell) + outset,
                                     style: .continuous)
        shape
            .strokeBorder(Color.boardMarkFoe, lineWidth: PaperMetrics.markStroke(for: m.cell))
            .background {
                // Свечение внутрь — размытая кромка, обрезанная формой.
                shape
                    .strokeBorder(Color.boardMarkFoeGlow, lineWidth: PaperMetrics.markInnerGlow)
                    .blur(radius: PaperMetrics.markInnerGlow / 2)
                    .clipShape(shape)
            }
            .shadow(color: .boardMarkFoeGlow, radius: m.cell / 4)
            .frame(width: side, height: side)
            .offset(x: origin.x - outset, y: origin.y - outset)
            .transition(.opacity)
            .accessibilityHidden(true)
    }
}

// MARK: - Ответы и результат

/// «Мимо / Ранен / Убит» — стекло `SecondaryButton` в ряд, ширина поровну
/// (2.15), высота и кегль — по кадру `answerBtn` (В29). Значки в цвете
/// результата: вода, латунь, огонь.
struct PaperAnswerRow: View {
    var size: Geometry.SizeClass = .regular
    var onAnswer: (PaperAnswer) -> Void

    var body: some View {
        HStack(spacing: PaperMetrics.answerGap(size)) {
            ForEach(PaperAnswer.allCases, id: \.self) { answer in
                Button { onAnswer(answer) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: PaperAnswerLabel.icon(answer))
                            .font(.system(size: symbolFontSize(inBox: PaperMetrics.answerIcon(size))))
                            .frame(height: PaperMetrics.answerIcon(size))
                            .foregroundStyle(PaperAnswerLabel.tint(answer))
                        Text(PaperAnswerLabel.title(answer))
                            .font(.system(size: PaperMetrics.answerText(size),
                                          weight: .semibold, design: .rounded))
                            // «Gezonken» на 375 pt не влезал и переносился.
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .buttonStyle(SecondaryButtonStyle(minHeight: PaperMetrics.answerHeight(size)))
                .accessibilityIdentifier("paperAnswer_\(answer.rawValue)")
            }
        }
    }
}

/// Подпись, значок и цвет ответа — одни на ряд iPhone и квадраты iPad.
enum PaperAnswerLabel {

    static func title(_ answer: PaperAnswer) -> LocalizedStringKey {
        switch answer {
        case .miss: "Miss"
        case .hit: "Hit"
        case .sunk: "Sunk"
        }
    }

    static func icon(_ answer: PaperAnswer) -> String {
        switch answer {
        case .miss: "drop"
        case .hit: "flame"
        case .sunk: "xmark.square"
        }
    }

    static func tint(_ answer: PaperAnswer) -> Color {
        switch answer {
        case .miss: .inkPrimary
        case .hit: .roleYou
        case .sunk: .fire
        }
    }
}

/// Капсула результата хода соперника — что сказать вслух (4.6). «Ранен»
/// латунная со свечением `Role/YouSoft`, «Убит» огненная со свечением
/// `Chrome/FireSoft`, «Мимо» белая без свечения; заливка — стекло.
struct PaperResultCapsule: View {
    let call: FeedOutcome
    var text: CGFloat = PaperMetrics.capsuleText

    var body: some View {
        Text(Self.word(call))
            .font(.system(size: text, weight: .bold, design: .rounded))
            .foregroundStyle(Self.color(call))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.vertical, (text * PaperMetrics.capsulePaddingV).rounded())
            .padding(.horizontal, (text * PaperMetrics.capsulePaddingH).rounded())
            .background {
                Capsule(style: .continuous)
                    .fill(Color.glassFill)
                    .overlay {
                        Capsule(style: .continuous).strokeBorder(Self.stroke(call), lineWidth: 1)
                    }
            }
            .shadow(color: Self.glow(call), radius: PaperMetrics.capsuleGlow)
            .accessibilityIdentifier("paperResult")
    }

    static func word(_ call: FeedOutcome) -> LocalizedStringKey {
        switch call {
        case .miss: "Miss"
        case .hit: "Hit"
        case .sunk: "Sunk"
        case .repeatHit, .repeatMiss: "Already called"
        }
    }

    static func color(_ call: FeedOutcome) -> Color {
        switch call {
        case .miss: .inkPrimary
        case .hit: .roleYou
        case .sunk: .fire
        case .repeatHit, .repeatMiss: .inkSecondary
        }
    }

    static func stroke(_ call: FeedOutcome) -> Color {
        switch call {
        case .hit: .roleYou
        case .sunk: .fire
        case .miss, .repeatHit, .repeatMiss: .glassStroke
        }
    }

    static func glow(_ call: FeedOutcome) -> Color {
        switch call {
        case .hit: .roleYouSoft
        case .sunk: .fireSoft
        case .miss, .repeatHit, .repeatMiss: .clear
        }
    }
}

/// «Отменить последний ход» — ровно один ход (4.6). В ряду переключателя
/// полей, на месте подсказки боя и той же высоты (кадр `undoBtn`).
struct PaperUndoButton: View {
    let isEnabled: Bool
    var size: Geometry.SizeClass = .regular
    var action: () -> Void = {}

    @Environment(\.inBottomStack) private var inBottomStack
    @Environment(\.locale) private var locale

    /// Длинная подпись («Ongedaan maken») на узком экране сжимала
    /// переключатель полей до многоточий — там остаётся только значок.
    static let longLabel = 10

    private var showsLabel: Bool {
        !size.isCompact || String(game: "Undo", locale: locale).count <= Self.longLabel
    }

    var body: some View {
        let compact = size.isCompact
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: symbolFontSize(inBox: compact ? 18 : 20)))
                    .frame(height: compact ? 18 : 20)
                if showsLabel {
                    Text("Undo")
                        .font(inBottomStack ? TypeScale.bottomLabelFixed
                                            : .system(size: compact ? 12 : 12.5, weight: .semibold, design: .rounded))
                }
            }
            .padding(.horizontal, showsLabel ? (compact ? 11 : 14) : 16)
        }
        .buttonStyle(SecondaryButtonStyle(isEnabled: isEnabled,
                                          radius: BattleMetrics.forSize(size).hintRadius,
                                          fillsFrame: true))
        .fixedSize(horizontal: true, vertical: false)
        .disabled(!isEnabled)
        .accessibilityLabel(Text("Undo last move"))
        .accessibilityIdentifier("paperUndo")
    }
}

// MARK: - Превью

/// Такты кадров 23a: до первого хода, клетка названа, соперник попал.
enum PaperDemoPhase { case first, aim, theirs }

@MainActor
func paperDemoMatch(_ phase: PaperDemoPhase) -> PaperMatch {
    var game = PaperGame(fleet: FleetLayout.canonicalLayout(), revealsRing: true)
    if phase != .first {
        game.aim(at: Coordinate(row: 1, column: 1))
        game.answer(.miss)
        game.opponentShot(at: Coordinate(row: 9, column: 9))
        for cell in [(2, 4), (2, 5)] {
            game.aim(at: Coordinate(row: cell.0, column: cell.1))
            game.answer(.hit)
        }
        game.aim(at: Coordinate(row: 2, column: 6))
        game.answer(.sunk)
        game.aim(at: Coordinate(row: 7, column: 5))
    }
    if phase == .theirs {
        game.answer(.miss)
        game.opponentShot(at: Coordinate(row: 3, column: 5))
    }
    let match = PaperMatch(game: game, pacing: .instant, persists: false)
    match.soundOn = false
    if phase == .theirs { match.show(.you) }
    return match
}

private struct PaperDemo: View {
    @State private var appState = AppState()
    @State private var match: PaperMatch

    init(_ phase: PaperDemoPhase) {
        _match = State(initialValue: paperDemoMatch(phase))
    }

    var body: some View {
        ZStack {
            SeaBackground()
                .ignoresSafeArea()
            PaperScreen(match: match)
        }
        .environment(appState)
    }
}

#Preview("Бумага · клетка названа") {
    PaperDemo(.aim)
        .preferredColorScheme(.dark)
}

#Preview("Бумага · кто начинает") {
    PaperDemo(.first)
        .preferredColorScheme(.dark)
}

#Preview("Бумага · ход соперника") {
    PaperDemo(.theirs)
        .preferredColorScheme(.dark)
}

#Preview("Бумага · светлая") {
    PaperDemo(.theirs)
        .preferredColorScheme(.light)
}

#Preview("Бумага · 375", traits: .fixedLayout(width: 375, height: 667)) {
    PaperDemo(.aim)
        .preferredColorScheme(.dark)
}
