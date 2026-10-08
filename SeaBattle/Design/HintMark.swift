//
//  HintMark.swift
//  Sea Battle — метка подсказки на клетке (07.10)
//
//  Клетка, открытая подсказкой, — слоем поверх сетки: под водой играет
//  латунный блик (`hintCaustic` в `HintMark.metal`, выбор заказчика 07.10).
//  Появление — свет растекается от центра клетки. Выстрел по клетке —
//  метка вспыхивает и растворяется, пока клетка под ней становится «ранен»
//  или «убит» (`HintExit.flare`, выбор заказчика 08.10; остальные варианты
//  ждут, пока он решит светлую тему на устройстве). Под Reduce Motion блик
//  стоит неподвижно и появляется и уходит без движения.
//

import SwiftUI

// MARK: - Числа

enum HintMarkMetrics {
    /// Свет растекается от центра за столько секунд.
    static let reveal: Double = 0.6
    /// Уход метки по выстрелу — вместе со сменой клетки (`Motion.stateSwap`).
    static let exit: Double = 0.45
    /// Вспышка: насколько ярче и крупнее в пике.
    static let flareGain: Double = 1.8
    static let flareScale: CGFloat = 0.25
}

/// Как метка уходит, когда по клетке выстрелили.
enum HintExit: CaseIterable, Sendable {
    /// Исчезает в тот же кадр.
    case cut
    /// Гаснет, пока клетка под ней меняется.
    case fade
    /// Вспыхивает и растворяется — свет переходит в огонь.
    case flare
    /// Свет стягивается в центр и уходит в глубину.
    case sink
}

// MARK: - Метка

struct HintMark: View {
    let cell: CGFloat
    /// Когда по клетке выстрелили; `nil` — ещё не стреляли.
    var shotAt: Date?
    /// Вспышка — выбор заказчика 08.10 для тёмной темы; светлую он решит на
    /// устройстве.
    var exit: HintExit = .flare

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Уход доигран — кадры больше не нужны.
    @State private var exitDone = false
    /// Когда метка появилась — от этого идёт появление и время блика. Своё у
    /// каждой метки: вернулись на поле — свет растекается заново.
    @State private var start: Date

    init(cell: CGFloat, shotAt: Date? = nil, exit: HintExit = .flare, appearedAt: Date = .now) {
        self.cell = cell
        self.shotAt = shotAt
        self.exit = exit
        _start = State(initialValue: appearedAt)
    }

    var body: some View {
        TimelineView(.animation(paused: isFinished)) { context in
            let now = context.date
            glow(age: now.timeIntervalSince(start),
                 exitProgress: shotAt.map { now.timeIntervalSince($0) / exitDuration })
        }
        .frame(width: cell, height: cell)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: shotAt) {
            exitDone = false
            guard let shotAt else { return }
            let remaining = exitDuration - Date.now.timeIntervalSince(shotAt)
            if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
            if !Task.isCancelled { exitDone = true }
        }
    }

    private var exitDuration: Double { Motion.scaled(HintMarkMetrics.exit, reduceMotion: reduceMotion) }

    /// Кадры не нужны: под Reduce Motion блик стоит, а ушедшая метка не видна.
    private var isFinished: Bool {
        if shotAt != nil { return exitDone || exit == .cut }
        return reduceMotion
    }

    @ViewBuilder
    private func glow(age: Double, exitProgress: Double?) -> some View {
        let p = min(1, max(0, exitProgress ?? 0))
        let gone = exitProgress != nil && (exit == .cut || p >= 1)
        if !gone {
            let reveal = reduceMotion ? 1 : min(1, max(0, age / HintMarkMetrics.reveal))
            let shape = RoundedRectangle(cornerRadius: Geometry.cellRadius(for: cell), style: .continuous)
            shape
                .fill(.white)
                .colorEffect(ShaderLibrary.hintCaustic(
                    .float2(cell, cell),
                    .float(Float(reduceMotion ? 0 : max(0, age))),
                    .color(.roleYou),
                    .float(Float(Self.easeOut(reveal))),
                    .float(Float(gain(p)))))
                .clipShape(shape)
                .scaleEffect(reduceMotion ? 1 : scale(p))
                .opacity(opacity(p, reveal: reveal))
        }
    }

    // MARK: Уход

    private func gain(_ p: Double) -> Double {
        exit == .flare && !reduceMotion ? 1 + (HintMarkMetrics.flareGain - 1) * sin(.pi * min(1, p * 1.6)) : 1
    }

    private func scale(_ p: Double) -> CGFloat {
        switch exit {
        case .flare: 1 + HintMarkMetrics.flareScale * CGFloat(Self.easeOut(p))
        case .sink: 1 - 0.75 * CGFloat(Self.easeIn(p))
        case .cut, .fade: 1
        }
    }

    private func opacity(_ p: Double, reveal: Double) -> Double {
        let appear = reduceMotion ? reveal : 1
        switch exit {
        case .cut: return appear
        case .fade: return appear * (1 - Self.easeOut(p))
        case .flare: return appear * (p < 0.35 ? 1 : 1 - Self.easeOut((p - 0.35) / 0.65))
        case .sink: return appear * (1 - Self.easeIn(p))
        }
    }

    private static func easeOut(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
    private static func easeIn(_ x: Double) -> Double { x * x * x }
}

// MARK: - Превью

/// Живое поле против компьютера: три подсказки — по двум клеткам выйдет
/// «ранен», по одиночному кораблю — «убит». Касание по клетке — выстрел,
/// касание по подписи — всё заново.
private struct HintMarkDemo: View {
    let exit: HintExit

    @State private var board = HintMarkDemo.freshBoard()
    @State private var event: CellEvent?
    @State private var shots: [Coordinate: Date] = [:]
    @State private var start = Date.now
    @State private var shotCount = 0

    private let metrics = BoardMetrics(cell: Geometry.Cell.iPhone)
    private static let hints = [Coordinate(row: 1, column: 2), Coordinate(row: 3, column: 5),
                                Coordinate(row: 5, column: 6)]

    var body: some View {
        let view = board.opponentView()
        let cells = Board.allCoordinates.map { BoardCellState.forDisplay(view[$0], on: .foe) }
        ZStack {
            SeaBackground()
                .ignoresSafeArea()
            VStack(spacing: 18) {
                BoardView(cells: cells, role: .foe, metrics: metrics, alphabet: .latin,
                          event: event, onTap: { column, row in
                              shoot(Coordinate(row: row + 1, column: column + 1))
                          })
                    .overlay(alignment: .topLeading) {
                        ZStack(alignment: .topLeading) {
                            ForEach(Self.hints, id: \.self) { cell in
                                let origin = metrics.cellOrigin(cell)
                                HintMark(cell: metrics.cell, shotAt: shots[cell], exit: exit)
                                    .id(start)
                                    .offset(x: origin.x, y: origin.y)
                            }
                        }
                        .frame(width: metrics.gridSide, height: metrics.gridSide, alignment: .topLeading)
                        .offset(x: metrics.inset, y: metrics.inset)
                    }
                Button {
                    board = Self.freshBoard()
                    event = nil
                    shots = [:]
                    start = .now
                } label: {
                    Text(verbatim: "Tap a glowing cell to shoot · tap here to reset")
                        .font(.footnote)
                        .foregroundStyle(Color.inkSecondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func shoot(_ cell: Coordinate) {
        guard board[cell].isUnshot else { return }
        let before = board.opponentView()
        let result = board.apply(shotAt: cell)
        shotCount += 1
        let now = Date.now
        event = CellEvent(id: shotCount, field: .foe, target: cell, result: result,
                          before: before, after: board.opponentView(), start: now)
        if Self.hints.contains(cell) { shots[cell] = now }
    }

    /// Расстановка из образца, несколько промахов уже есть.
    private static func freshBoard() -> Board {
        var board = Board(ships: FleetLayout.canonicalLayout())
        for cell in [Coordinate(row: 7, column: 3), Coordinate(row: 9, column: 8),
                     Coordinate(row: 2, column: 9)] {
            _ = board.apply(shotAt: cell)
        }
        return board
    }
}

#Preview("1 · Уход — сразу") {
    HintMarkDemo(exit: .cut).preferredColorScheme(.dark)
}

#Preview("2 · Уход — гаснет") {
    HintMarkDemo(exit: .fade).preferredColorScheme(.dark)
}

#Preview("3 · Уход — вспышка") {
    HintMarkDemo(exit: .flare).preferredColorScheme(.dark)
}

#Preview("4 · Уход — в глубину") {
    HintMarkDemo(exit: .sink).preferredColorScheme(.dark)
}

#Preview("5 · Вспышка · светлая") {
    HintMarkDemo(exit: .flare).preferredColorScheme(.light)
}

/// Застывшие кадры: метка горит, и середина ухода у каждого варианта.
#Preview("6 · Кадры ухода") {
    let cell: CGFloat = 56
    let lit = Date.now.addingTimeInterval(-2)
    ZStack {
        SeaBackground().ignoresSafeArea()
        VStack(spacing: 14) {
            ZStack {
                BoardCell(.water, size: cell)
                HintMark(cell: cell, appearedAt: lit)
            }
            ForEach(HintExit.allCases, id: \.self) { exit in
                HStack(spacing: 12) {
                    ForEach([0.1, 0.2, 0.3], id: \.self) { ago in
                        ZStack {
                            BoardCell(.hit, size: cell)
                            HintMark(cell: cell, shotAt: .now.addingTimeInterval(-ago),
                                     exit: exit, appearedAt: lit)
                        }
                    }
                }
            }
        }
    }
    .preferredColorScheme(.dark)
}
