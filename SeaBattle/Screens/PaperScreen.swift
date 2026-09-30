//
//  PaperScreen.swift
//  Sea Battle — игра на бумаге, iPhone (R3.1, шаг 11 порядка сборки)
//
//  Спека 4.6, кадры `screen4PaperAsk` / `screen4PaperSunk` /
//  `screen4PaperAnswer` / `screenSmallPaper` (тур 4). Кадры старше системы
//  компонентов, поэтому раскладка — как у боя (правило 3: одна раскладка на
//  все режимы, различается содержимое шапки):
//
//  - верх — `ScorePanel`, в центре вместо «Ваш ход» — «Скажите: Д7»;
//  - центр — поле с координатами (B2), под ним одно место на три вещи: ряд
//    ответов «Мимо / Ранен / Убит», капсулу результата или подсказку, что
//    делать. Место одной высоты, поэтому поле стоит на одном уровне на всех
//    тактах (4.6);
//  - низ — переключатель полей и «Отменить», последней строкой `NavRow`.
//
//  «Отменить» стоит в ряду переключателя, на месте подсказки боя: подсказки в
//  этом режиме нет, а отдельная строка не помещается на 375 × 667 (в кадре
//  375 ради этого поднят в нижний стек даже ряд ответов). Вопрос В26.
//

import SwiftUI

// MARK: - Числа

enum PaperMetrics {
    /// Капсула результата — кадр `resultCapsule`: 27 pt, поля 11 / 34.
    static let capsuleText: CGFloat = 27
    static let capsulePaddingV: CGFloat = 11
    static let capsulePaddingH: CGFloat = 34
    /// Свечение латунной капсулы (0 0 26 в кадре).
    static let capsuleGlow: CGFloat = 13
    static let promptText: CGFloat = 13
}

// MARK: - Экран

struct PaperScreen: View {

    let match: PaperMatch
    var onLeave: () -> Void = {}
    var onPlayAgain: () -> Void = {}
    var onMenuAfterResult: () -> Void = {}

    @Environment(\.locale) private var locale
    @State private var askLeave = false

    private var game: PaperGame { match.game }

    private var alphabet: BoardAlphabet {
        .forLanguage(locale.language.languageCode?.identifier)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = Geometry.SizeClass.forWidth(proxy.size.width)
            let metrics = BoardMetrics(cell: size.cellCoords, coordinates: true)
            let field = match.shownField

            VStack(spacing: 0) {
                ScorePanel(yourLosses: game.own.sunkShipCount,
                           foeLosses: game.foe.sunkShipCount,
                           isYourTurn: isYourTurn,
                           balance: ProgressStore.shared.points,
                           size: size,
                           status: status)
                    .padding(.top, BattleScreenMetrics.scoreTop)

                GeometryReader { area in
                    // На 375 подпись поля уходит в шапку (кадр `screenSmallPaper`):
                    // иначе поле с координатами и низ не помещаются на 667.
                    let showsCaption = !size.isCompact
                    let slotBlock = ShotFeed.height + Geometry.Nav.stackGap
                    let captionBlock = showsCaption
                        ? BattleScreenMetrics.captionHeight + BattleScreenMetrics.captionGap : 0
                    let top = BattleScreenMetrics.boardTop(available: area.size.height,
                                                          board: captionBlock + metrics.totalSize.height,
                                                          feed: slotBlock)
                    VStack(spacing: 0) {
                        if showsCaption {
                            caption(field, size: size)
                                .padding(.bottom, BattleScreenMetrics.captionGap)
                        }
                        PaperBoard(match: match, field: field, metrics: metrics,
                                   alphabet: alphabet)
                        Spacer(minLength: 0)
                        slot(field)
                            .frame(height: ShotFeed.height)
                            .padding(.horizontal, Geometry.Nav.stackInset)
                            .padding(.bottom, Geometry.Nav.stackGap)
                    }
                    .padding(.top, top)
                    .frame(width: area.size.width, height: area.size.height)
                }

                actions(field, size: size)
            }
        }
        .matchResults(match.result, onPlayAgain: onPlayAgain, onMenu: onMenuAfterResult)
        .modalDialog(isPresented: askLeave) {
            ModalDialog.leaveMatch(.offline,
                                   onStay: { askLeave = false },
                                   onLeave: {
                                       askLeave = false
                                       onLeave()
                                   })
        }
        .animation(Motion.quick, value: match.shownField)
        .animation(Motion.quick, value: game.aim)
    }

    // MARK: Шапка

    /// Чей такт. До первого хода первым может быть любой — тогда такт
    /// определяет показанное поле.
    private var isYourTurn: Bool {
        switch game.turn {
        case .you: true
        case .foe: false
        case nil: match.shownField == .foe
        }
    }

    /// «Скажите: Д7», пока выстрел назван и ждёт ответа (4.6).
    private var status: Text? {
        guard let aim = game.aim else { return nil }
        return Text("Say: \(ShotChip.label(aim, alphabet: alphabet))")
    }

    private func caption(_ field: Side, size: Geometry.SizeClass) -> some View {
        Text(field == .foe ? "Opponent's board" : "Your fleet")
            .font(.system(size: BattleMetrics.forSize(size).caption,
                          weight: .semibold, design: .rounded))
            .foregroundStyle(Color.inkPrimary)
            .shadow(color: .inkTitleShadow,
                    radius: NavMetrics.titleShadowRadius,
                    y: NavMetrics.titleShadowOffsetY)
            .frame(height: BattleScreenMetrics.captionHeight)
    }

    // MARK: Место под полем

    @ViewBuilder
    private func slot(_ field: Side) -> some View {
        if field == .foe, game.aim != nil {
            PaperAnswerRow { match.answer($0) }
                .transition(.opacity)
        } else if let last = game.last, last.field == field {
            PaperResultCapsule(call: last.call)
                .id(game.moves)
                .transition(.opacity)
        } else {
            Text(prompt(field))
                .font(.system(size: PaperMetrics.promptText, weight: .semibold))
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .transition(.opacity)
        }
    }

    private func prompt(_ field: Side) -> LocalizedStringKey {
        switch field {
        case .foe:
            game.acceptsYourShot ? "Tap the cell you call out" : "Your opponent is shooting"
        case .you:
            game.acceptsOpponentShot ? "Tap the cell your opponent calls" : "Your turn to shoot"
        }
    }

    // MARK: Низ

    private func actions(_ field: Side, size: Geometry.SizeClass) -> some View {
        BottomStack(onMenu: menuTapped) {
            HStack(spacing: Geometry.Nav.stackGap) {
                FieldSwitch(selection: field, size: size) { match.show($0) }
                PaperUndoButton(isEnabled: match.canUndo, size: size) { match.undo() }
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

// MARK: - Поле

/// Поле игры на бумаге: B2, прицел и подсветка буквы и цифры названной
/// клетки. Касание своего поля — выстрел соперника, чужого — ваш.
struct PaperBoard: View {
    let match: PaperMatch
    let field: Side
    let metrics: BoardMetrics
    let alphabet: BoardAlphabet

    private var game: PaperGame { match.game }

    var body: some View {
        let board = field == .foe ? game.foe : game.own
        let cells = Board.allCoordinates.map { BoardCellState.forDisplay(board[$0], on: field) }
        let accepts = field == .foe ? game.acceptsYourShot : game.acceptsOpponentShot
        // Буква и цифра горят у названной клетки, а после хода — у той, куда
        // стреляли последний раз (кадры 4.6).
        let marked = field == .foe ? (game.aim ?? lastShot) : lastShot
        let isActive = accepts && (game.turn != nil || match.shownField == field)

        return BoardView(cells: cells, role: field, metrics: metrics, isActive: isActive,
                         aim: marked.map { (column: $0.column - 1, row: $0.row - 1) },
                         alphabet: alphabet,
                         event: match.event(on: field),
                         onTap: accepts ? { column, row in
                             let cell = Coordinate(row: row + 1, column: column + 1)
                             if field == .foe { match.tapFoe(cell) } else { match.tapOwn(cell) }
                         } : nil)
            .overlay(alignment: .topLeading) {
                if field == .foe, let aim = game.aim {
                    AimMark(at: aim, metrics: metrics)
                        .frame(width: metrics.gridSide, height: metrics.gridSide,
                               alignment: .topLeading)
                        .offset(x: metrics.digitsWidth + metrics.axisGap + metrics.inset,
                                y: metrics.lettersHeight + metrics.axisGap + metrics.inset)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: metrics.totalSize.width, height: metrics.totalSize.height)
            .accessibilityIdentifier(field == .foe ? "paperFoeBoard" : "paperOwnBoard")
    }

    private var lastShot: Coordinate? {
        guard let last = game.last, last.field == field else { return nil }
        return last.coordinate
    }
}

// MARK: - Ответы и результат

/// «Мимо / Ранен / Убит» — `SecondaryButton` в ряд, ширина поровну (2.15).
/// Значки в цвете результата, как в кадре: вода, латунь, огонь.
struct PaperAnswerRow: View {
    var onAnswer: (PaperAnswer) -> Void

    var body: some View {
        HStack(spacing: Geometry.Nav.stackGap) {
            ForEach(PaperAnswer.allCases, id: \.self) { answer in
                Button { onAnswer(answer) } label: {
                    Label {
                        Text(Self.title(answer))
                    } icon: {
                        Image(systemName: Self.icon(answer))
                            .foregroundStyle(Self.tint(answer))
                    }
                }
                .secondaryButton()
                .accessibilityIdentifier("paperAnswer_\(answer.rawValue)")
            }
        }
    }

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

/// Капсула результата — одна на оба такта (4.6): на вашем выстреле — что
/// ответил соперник, на его ходе — что сказать вслух. «Ранен» латунная,
/// «Убит» огненная; слов «Скажите вслух» на ней нет.
struct PaperResultCapsule: View {
    let call: FeedOutcome

    var body: some View {
        let color = Self.color(call)
        Text(Self.word(call))
            .font(.system(size: PaperMetrics.capsuleText, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.vertical, PaperMetrics.capsulePaddingV)
            .padding(.horizontal, PaperMetrics.capsulePaddingH)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.glassFill)
                    .overlay { Capsule(style: .continuous).strokeBorder(color, lineWidth: 1) }
            }
            // Свечение только у латуни: у огня мягкого токена нет, а
            // `.opacity()` от цвета запрещён (правило 8). Вопрос В27.
            .shadow(color: call == .hit ? .roleYouSoft : .clear, radius: PaperMetrics.capsuleGlow)
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
}

/// «Отменить последний ход» — ровно один ход (4.6). В ряду переключателя
/// полей, на месте подсказки боя и той же высоты.
struct PaperUndoButton: View {
    let isEnabled: Bool
    var size: Geometry.SizeClass = .regular
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: Geometry.SecondaryButton.gap) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: symbolFontSize(inBox: Geometry.SecondaryButton.icon)))
                    .frame(height: Geometry.SecondaryButton.icon)
                Text("Undo")
            }
            .padding(.horizontal, size.isCompact ? 12 : Geometry.SecondaryButton.padding)
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

private struct PaperDemo: View {
    @State private var appState = AppState()
    @State private var match: PaperMatch = {
        var game = PaperGame(fleet: FleetLayout.canonicalLayout(), revealsRing: true)
        // Середина партии: промахи, потопленный трёхпалубный, раненый.
        for (cell, answer) in [((1, 1), PaperAnswer.miss)] {
            game.aim(at: Coordinate(row: cell.0, column: cell.1))
            game.answer(answer)
        }
        game.opponentShot(at: Coordinate(row: 5, column: 5))
        for cell in [(2, 4), (2, 5)] {
            game.aim(at: Coordinate(row: cell.0, column: cell.1))
            game.answer(.hit)
        }
        game.aim(at: Coordinate(row: 2, column: 6))
        game.answer(.sunk)
        game.aim(at: Coordinate(row: 7, column: 5))
        return PaperMatch(game: game, pacing: .instant, persists: false)
    }()

    var body: some View {
        ZStack {
            SeaBackground()
                .ignoresSafeArea()
            PaperScreen(match: match)
        }
        .environment(appState)
        .onAppear { match.soundOn = false }
    }
}

#Preview("Бумага · ваш выстрел") {
    PaperDemo()
        .preferredColorScheme(.dark)
}

#Preview("Бумага · светлая") {
    PaperDemo()
        .preferredColorScheme(.light)
}

#Preview("Бумага · 375", traits: .fixedLayout(width: 375, height: 667)) {
    PaperDemo()
        .preferredColorScheme(.dark)
}
