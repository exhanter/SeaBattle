//
//  ContinueGame.swift
//  Sea Battle — «Продолжить партию» в меню iPhone (07.10)
//
//  Заказчик: ссылка «Продолжить партию» терялась среди строк режимов.
//  Теперь над режимами стоит карточка незакрытой партии (выбор заказчика
//  07.10): латунный ▶, название, подробность («Сложно · потоплено 3 : 1») и
//  мини-поле противника. Если партий несколько, в карточке — их режимы и
//  число, а нажатие открывает список прямо под карточкой (`ContinuePopover`).
//  Системное меню заказчика «коробило» — узкое и сливалось с морем. Своё окно
//  — стекло G3 с латунной рамкой (выбор заказчика 08.10: тёмная и латунная
//  заливки выбивались из стиля кнопок).
//

import SwiftUI

// MARK: - Незакрытая партия

/// Что меню знает о незакрытой партии: режим, строка подробностей и, если
/// есть, поле противника для мини-картинки. Собирает оболочка.
struct SavedGameSummary: Identifiable {
    let mode: GameMode
    /// Окно выбора: «Сложно · потоплено 3 : 1».
    let detail: Text
    /// Карточка: то же без счёта — «Сложно» (заказчик 08.10: со счётом
    /// подпись уходила во вторую строку). Нет — берётся `detail`.
    var short: Text?
    /// 100 клеток поля противника, как его видит игрок; `nil` — без картинки
    /// (вдвоём на устройстве «противник» у каждого свой).
    var cells: [BoardCellState]?

    var id: GameMode { mode }

    var menuMode: MenuMode? { MenuMode.all.first { $0.mode == mode } }

    /// «потоплено 3 : 1» — сколько потопили вы и сколько у вас.
    static func sunk(_ yours: Int, _ theirs: Int) -> Text {
        Text("sunk \(yours) : \(theirs)")
    }
}

// MARK: - Мини-поле

/// Поле противника в 10 × 10 точек: видно, насколько партия продвинулась.
struct MiniBoard: View {
    let cells: [BoardCellState]
    var side: CGFloat = 34

    var body: some View {
        Canvas { context, size in
            let gap: CGFloat = 1
            let step = (size.width - gap * 9) / 10
            for index in cells.indices.prefix(100) {
                let rect = CGRect(x: CGFloat(index % 10) * (step + gap),
                                  y: CGFloat(index / 10) * (step + gap),
                                  width: step, height: step)
                context.fill(Path(roundedRect: rect, cornerRadius: step * 0.25),
                             with: .color(Self.color(cells[index])))
            }
        }
        .frame(width: side, height: side)
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.boardFillFoe)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.boardStrokeFoe, lineWidth: 1)
                }
        }
        .accessibilityHidden(true)
    }

    private static func color(_ state: BoardCellState) -> Color {
        switch state {
        case .water, .ship, .shipDenied: .white.opacity(0.14)
        case .miss: .white.opacity(0.55)
        case .hit, .hitMine: .roleYou
        case .sunk: .fire
        }
    }
}

// MARK: - Карточка

/// Карточка над строками режимов. Одна партия — нажатие сразу продолжает
/// её; несколько — открывает окно выбора (`onToggleChoosing`).
struct ContinueCard: View {
    let games: [SavedGameSummary]
    var size: Geometry.SizeClass = .regular
    var onContinue: () -> Void = {}
    /// Выбор открыт — справа крестик вместо числа.
    var isChoosing = false
    var onToggleChoosing: () -> Void = {}
    var onDiscard: (GameMode) -> Void = { _ in }

    @Environment(\.shapeFamily) private var shapeFamily
    @Environment(AppState.self) private var appState: AppState?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Одна партия: карточка спрашивает «Удалить партию?».
    @State private var confirmingDelete = false

    var body: some View {
        Group {
            if confirmingDelete, let game = games.first {
                DeleteConfirmRow(size: size,
                                 onDelete: { confirmingDelete = false; onDiscard(game.mode) },
                                 onCancel: { setConfirming(false) })
            } else {
                HStack(spacing: 0) {
                    Button(action: games.count > 1 ? onToggleChoosing : onContinue) { content }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("continueGameButton")
                    // Одну партию удалить — корзиной прямо на карточке, как в
                    // окне выбора: мини-поле, за ним корзина (заказчик 08.10:
                    // мини-поле у самого края смотрелось плохо); несколько —
                    // корзинами в окне выбора.
                    if games.count == 1, let game = games.first {
                        TrashButton(size: size) { requestDelete(game.mode) }
                            .accessibilityIdentifier("continueDelete_\(game.mode.rawValue)")
                    }
                }
            }
        }
        .transition(.opacity)
        .glassPanel(.g2, radius: radius)
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Color.roleYou, lineWidth: 1.2)
                .allowsHitTesting(false)
        }
        .shadow(color: .roleYouSoft, radius: 12)
    }

    /// С подтверждением — вопрос на карточке; без (настройка выключена) —
    /// сразу.
    private func requestDelete(_ mode: GameMode) {
        if appState?.confirmEndMatch ?? true {
            setConfirming(true)
        } else {
            onDiscard(mode)
        }
    }

    private func setConfirming(_ value: Bool) {
        withAnimation(Motion.quick.reduced(reduceMotion)) { confirmingDelete = value }
    }

    private var radius: CGFloat { shapeFamily.radius(.control, legacy: size.modeRowRadius) }

    private var content: some View {
        HStack(spacing: size.modeRowGap) {
            PlayBadge()
            VStack(alignment: .leading, spacing: ControlMetrics.ModeRow.textGap) {
                Text("Continue game")
                    .font(.scalable(size: size.modeName, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.roleYou)
                subtitle
                    .font(.scalable(size: size.modeSub))
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if games.count == 1, let cells = games.first?.cells {
                MiniBoard(cells: cells, side: 30)
            } else if games.count > 1 {
                Group {
                    if isChoosing {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                    } else {
                        Text(verbatim: "\(games.count)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                }
                .foregroundStyle(Color.inkPrimary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.roleYou.opacity(isChoosing ? 0.3 : 0.55)))
                .contentTransition(.opacity)
                .accessibilityHidden(true)
            }
        }
        .padding(.leading, size.modeRowPadding)
        .padding(.trailing, games.count == 1 ? 0 : size.modeRowPadding)
        .padding(.vertical, ControlMetrics.ModeRow.grownPadding)
        .frame(minHeight: size.modeRowHeight)
        .contentShape(Rectangle())
    }

    /// Одна партия — режим и подробность («Одиночная игра · Сложно ·
    /// потоплено 3 : 1»: без режима «Ваш ход · …» не говорило, какая это
    /// партия, — заказчик 08.10); несколько — названия режимов через точку.
    private var subtitle: Text {
        if games.count == 1, let game = games.first {
            let detail = game.short ?? game.detail
            guard let mode = game.menuMode else { return detail }
            return Text(mode.title) + Text(verbatim: " · ") + detail
        }
        let titles = games.compactMap { $0.menuMode.map { Text($0.title) } }
        return titles.dropFirst().reduce(titles.first ?? Text(verbatim: "")) {
            $0 + Text(verbatim: " · ") + $1
        }
    }
}

// MARK: - Окно выбора

/// Список незакрытых партий под карточкой, во всю её ширину: строка на
/// партию — значок режима, название, подробность, мини-поле, латунный ▶.
/// Стекло G3 — как остальные панели, латунная рамка — как у карточки.
/// На iOS 18 стекло рисуется материалом, раскладка та же.
struct ContinuePopover: View {
    let games: [SavedGameSummary]
    var size: Geometry.SizeClass = .regular
    var onPick: (GameMode) -> Void = { _ in }
    /// Корзина в строке → «Удалить» в той же строке (заказчик 08.10).
    var onDiscard: (GameMode) -> Void = { _ in }
    /// Только превью: строка сразу спрашивает «Удалить?».
    var startsConfirming: GameMode?

    static let radius: CGFloat = 22
    static let rowHeight: CGFloat = 56

    /// Строка, которая сейчас спрашивает «Удалить партию?».
    @State private var confirming: GameMode?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppState.self) private var appState: AppState?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                if index > 0 {
                    Rectangle()
                        .fill(separator)
                        .frame(height: 1)
                        .padding(.leading, size.modeRowPadding + size.modeIcon + size.modeRowGap)
                }
                Group {
                    if confirming == game.mode {
                        confirmRow(game)
                    } else {
                        row(game)
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.vertical, 6)
        .glassPanel(.g3, radius: Self.radius)
        .overlay {
            RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
                .strokeBorder(Color.roleYou.opacity(0.8), lineWidth: 1.2)
        }
        .shadow(color: .black.opacity(0.45), radius: 22, y: 12)
        .accessibilityElement(children: .contain)
        .onAppear { if let startsConfirming { confirming = startsConfirming } }
    }

    /// Партия: нажатие по строке продолжает её, корзина справа — удалить.
    private func row(_ game: SavedGameSummary) -> some View {
        HStack(spacing: 0) {
            Button { onPick(game.mode) } label: {
                HStack(spacing: size.modeRowGap) {
                    if let mode = game.menuMode {
                        ScaledSymbol(name: mode.icon, box: size.modeIcon)
                            .foregroundStyle(Color.inkPrimary)
                    }
                    VStack(alignment: .leading, spacing: ControlMetrics.ModeRow.textGap) {
                        if let mode = game.menuMode {
                            Text(mode.title)
                                .font(.scalable(size: size.modeName, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.inkPrimary)
                                .lineLimit(1)
                        }
                        game.detail
                            .font(.scalable(size: size.modeSub))
                            .foregroundStyle(Color.inkSecondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if let cells = game.cells { MiniBoard(cells: cells, side: 30) }
                }
                .padding(.leading, size.modeRowPadding)
                .frame(minHeight: Self.rowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(PopoverRowStyle())

            TrashButton(size: size) {
                if appState?.confirmEndMatch ?? true {
                    setConfirming(game.mode)
                } else {
                    onDiscard(game.mode)
                }
            }
            .accessibilityIdentifier("continueDelete_\(game.mode.rawValue)")
        }
    }

    /// Та же строка спрашивает «Удалить партию?» — отдельного окна нет.
    private func confirmRow(_ game: SavedGameSummary) -> some View {
        DeleteConfirmRow(size: size,
                         onDelete: { onDiscard(game.mode); confirming = nil },
                         onCancel: { setConfirming(nil) })
    }

    private func setConfirming(_ mode: GameMode?) {
        withAnimation(Motion.quick.reduced(reduceMotion)) { confirming = mode }
    }

    private var separator: Color { Color.white.opacity(0.12) }
}

// MARK: - Удаление

/// Корзина справа в строке партии — на карточке и в окне выбора.
///
/// Ширина зоны — высота строки режима, значок по её центру: на карточке-
/// капсуле он встаёт в центр правого скругления, зеркально кругу ▶ слева
/// (тот сидит в центре левого), а не жмётся к краю. В окне выбора та же
/// ширина — корзины строк стоят точно под корзиной карточки.
struct TrashButton: View {
    var size: Geometry.SizeClass = .regular
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "trash")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.inkSecondary)
                .frame(width: size.modeRowHeight, height: ContinuePopover.rowHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(PopoverRowStyle())
        .accessibilityLabel(Text("Delete game"))
    }
}

/// «Удалить партию?» на месте строки: огненная «Удалить» и крестик отмены.
struct DeleteConfirmRow: View {
    var size: Geometry.SizeClass = .regular
    var onDelete: () -> Void
    var onCancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "trash")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.fire)
                .frame(width: size.modeIcon)
                .accessibilityHidden(true)
            Text("Delete game?")
                .font(.scalable(size: size.modeName, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDelete) {
                Text("Delete")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.fire)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 34)
                    .background {
                        Capsule(style: .continuous)
                            .fill(Color.fireSoft)
                            .overlay { Capsule(style: .continuous).strokeBorder(Color.fire, lineWidth: 1) }
                    }
                    .frame(minHeight: Geometry.Hit.minTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("continueDeleteConfirm")
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.glassFill))
                    .frame(width: Geometry.Hit.minTarget, height: Geometry.Hit.minTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Cancel"))
        }
        .padding(.leading, size.modeRowPadding)
        .padding(.trailing, 6)
        .frame(minHeight: max(ContinuePopover.rowHeight, size.modeRowHeight))
    }
}

/// Нажатая строка окна чуть светлеет — как строка системного меню.
private struct PopoverRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.white.opacity(configuration.isPressed ? 0.1 : 0))
    }
}

/// Латунный круг с треугольником «играть».
struct PlayBadge: View {
    var side: CGFloat = 34

    var body: some View {
        Image(systemName: "play.fill")
            .font(.system(size: side * 0.4, weight: .bold))
            .foregroundStyle(Color.inkPrimary)
            .offset(x: side * 0.03)
            .frame(width: side, height: side)
            .background {
                Circle().fill(LinearGradient.buttonBrass)
                    .background(Material.glassPanel, in: Circle())
                    .overlay { Circle().strokeBorder(Color.roleYou, lineWidth: 1) }
            }
            .shadow(color: .roleYouSoft, radius: 6)
            .accessibilityHidden(true)
    }
}

// MARK: - Образцы для превью

extension SavedGameSummary {
    static let previewComputer = SavedGameSummary(
        mode: .computer,
        detail: Text(LevelChoice.title(for: .hard)) + Text(verbatim: " · ") + sunk(3, 1),
        short: Text(LevelChoice.title(for: .hard)),
        cells: previewCells(seed: 1))
    static let previewPaper = SavedGameSummary(
        mode: .paper,
        detail: Text("Opponent's turn") + Text(verbatim: " · ") + sunk(2, 2),
        short: Text("Their turn"),
        cells: previewCells(seed: 2))
    static let previewDuel = SavedGameSummary(
        mode: .hotSeat,
        detail: Text(verbatim: "Anna 4 : 3 Peter"),
        short: Text(verbatim: "Anna – Peter"),
        cells: nil)

    /// Поле в середине партии: промахи, раненые и потопленные.
    static func previewCells(seed: Int) -> [BoardCellState] {
        var cells = [BoardCellState](repeating: .water, count: 100)
        let misses = seed == 1 ? [2, 13, 27, 44, 52, 58, 66, 81, 88, 92, 97, 35, 71]
                               : [5, 22, 38, 47, 60, 73, 84, 99]
        for i in misses { cells[i] = .miss }
        for i in seed == 1 ? [62, 63, 64] : [16, 17] { cells[i] = .sunk }
        for i in seed == 1 ? [31, 41] : [55] { cells[i] = .hit }
        return cells
    }
}

#Preview("Окно выбора · удалить партию?") {
    ZStack {
        SeaBackground()
        ContinuePopover(games: [.previewComputer, .previewPaper, .previewDuel],
                        startsConfirming: .paper)
            .padding(.horizontal, 12)
    }
    .preferredColorScheme(.dark)
}
