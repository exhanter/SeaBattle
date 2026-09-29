//
//  CellEffects.swift
//  Sea Battle — отрисовка события клетки (R2.4)
//
//  Что и когда — в `CellEvent` и `CellEventTiming`; здесь только вид.
//  Числа колец и подсветки взяты из живого кода макетов 14d (`ringOut`,
//  `blink`): кольцо диаметром 1,45 клетки расходится от 0,45 до 1,8 и гаснет,
//  второе идёт следом тише; подсветка — обводка 2 pt со свечением по контуру
//  клетки.
//
//  Reduce Motion: кольца не растут, а только гаснут на месте (масштаб →
//  прозрачность), длительности × 0,5. Состояния клеток не меняются.
//

import SwiftUI

// MARK: - Часы события

/// Идёт кадрами ровно столько, сколько длится анимация, и останавливается.
/// `TimelineView` без паузы тикал бы до конца партии на каждом поле.
struct EventClock<Content: View>: View {
    let start: Date
    let duration: Double
    @ViewBuilder let content: (_ elapsed: Double) -> Content

    @State private var finished = false

    var body: some View {
        TimelineView(.animation(paused: finished)) { context in
            content(finished ? duration : context.date.timeIntervalSince(start))
        }
        .task(id: start) {
            let remaining = duration - Date().timeIntervalSince(start)
            finished = remaining <= 0
            guard remaining > 0 else { return }
            try? await Task.sleep(for: .seconds(remaining))
            if !Task.isCancelled { finished = true }
        }
    }
}

// MARK: - Числа

enum CellEffectMetrics {
    /// Диаметр кольца — доля клетки.
    static let ringDiameter: CGFloat = 1.45
    /// Масштаб кольца: от 0,45 растёт на 1,35.
    static let ringScaleFrom: CGFloat = 0.45
    static let ringScaleGrowth: CGFloat = 1.35
    /// Под Reduce Motion кольцо стоит на этом масштабе и только гаснет.
    static let ringScaleStill: CGFloat = 1.0
    /// Толщина кольца: 2 pt на клетке 34 в макете.
    static let ringStrokeRatio: CGFloat = 0.06
    static let ringMinStroke: CGFloat = 1.5
    /// Пиковая непрозрачность первого кольца и второго, «мягкого».
    static let ringPeak: [Double] = [0.92, 0.5]

    /// Подсветка контура: на 2 pt шире клетки, обводка 2 pt, свечение.
    static let contourOutset: CGFloat = 2
    static let contourStroke: CGFloat = 2
    static let contourGlow: CGFloat = 8
    static let contourPeak: Double = 0.8

    static func ringStroke(for cell: CGFloat) -> CGFloat {
        max(ringMinStroke, cell * ringStrokeRatio)
    }

    /// Непрозрачность кольца по его прогрессу: гаснет плавно, без обрыва.
    static func ringOpacity(_ index: Int, progress p: Double) -> Double {
        ringPeak[index] * pow(1 - p, 1.5)
    }

    static func ringScale(progress p: Double, reduceMotion: Bool) -> CGFloat {
        reduceMotion ? ringScaleStill : ringScaleFrom + ringScaleGrowth * CGFloat(p)
    }
}

extension CellEvent.Tone {
    var color: Color {
        switch self {
        case .brass: .roleYou
        case .fire: .fire
        }
    }
}

// MARK: - Всплеск и подсветка

/// Два кольца и подсветка контура у клетки выстрела. Рисуется на месте
/// клетки и выходит за неё — обрезать нельзя, кольцо шире клетки.
struct CellSplash: View {
    let event: CellEvent
    let cell: CGFloat
    let timing: CellEventTiming

    var body: some View {
        EventClock(start: event.start, duration: timing.effectsEnd) { t in
            CellSplashFrame(tone: event.tone, cell: cell, timing: timing, elapsed: t)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Один кадр всплеска в момент `elapsed`. Отдельно от часов — чтобы
/// раскадровку можно было посмотреть в превью по кадрам, как блок 14a.
struct CellSplashFrame: View {
    let tone: CellEvent.Tone
    let cell: CGFloat
    let timing: CellEventTiming
    let elapsed: Double

    var body: some View {
        let t = elapsed
        let color = tone.color
        ZStack {
                ForEach(0..<2, id: \.self) { index in
                    if let p = timing.ring(index, at: t) {
                        Circle()
                            .strokeBorder(color, lineWidth: CellEffectMetrics.ringStroke(for: cell))
                            .frame(width: cell * CellEffectMetrics.ringDiameter,
                                   height: cell * CellEffectMetrics.ringDiameter)
                            .scaleEffect(CellEffectMetrics.ringScale(progress: p,
                                                                     reduceMotion: timing.reduceMotion))
                            .opacity(CellEffectMetrics.ringOpacity(index, progress: p))
                    }
                }
                let glow = timing.contour(at: t)
                if glow > 0 {
                    let outset = CellEffectMetrics.contourOutset
                    RoundedRectangle(cornerRadius: Geometry.cellRadius(for: cell) + outset,
                                     style: .continuous)
                        .strokeBorder(color, lineWidth: CellEffectMetrics.contourStroke)
                        .shadow(color: color, radius: CellEffectMetrics.contourGlow)
                        .frame(width: cell + outset * 2, height: cell + outset * 2)
                        .opacity(CellEffectMetrics.contourPeak * glow)
                }
        }
        .frame(width: cell, height: cell)
    }
}

// MARK: - Смена состояния

/// Клетка посреди смены состояния. **Встречное растворение**: прежнее гаснет,
/// новое проявляется. Новое поверх старого без гашения дало бы вспышку —
/// вода полупрозрачная, и на середине перехода клетка светлела бы.
struct SwappingCell: View {
    let from: BoardCellState
    let to: BoardCellState
    let change: CellChange
    let start: Date
    let size: CGFloat
    let timing: CellEventTiming

    var body: some View {
        EventClock(start: start, duration: timing.end(of: change)) { t in
            let p = timing.swap(change, at: t)
            ZStack {
                BoardCell(from, size: size).opacity(1 - p)
                BoardCell(to, size: size).opacity(p)
            }
        }
    }
}

// MARK: - Превью

/// Раскадровка, как блок 14a: одна клетка в моменты от выстрела. Слева
/// промах на поле противника (огонь), справа попадание по своему (латунь).
private struct SplashStoryboard: View {
    let frames: [Double] = [0, 0.04, 0.09, 0.14, 0.2, 0.3, 0.45]
    let cell = Geometry.Cell.iPhone
    var reduceMotion = false

    var body: some View {
        let timing = CellEventTiming(reduceMotion: reduceMotion)
        ZStack {
            SeaBackground()
            VStack(spacing: 28) {
                row(.fire, from: .water, to: .miss, timing: timing)
                row(.fire, from: .water, to: .hit, timing: timing)
                row(.brass, from: .ship, to: .hitMine, timing: timing)
            }
        }
    }

    private func row(_ tone: CellEvent.Tone, from: BoardCellState, to: BoardCellState,
                     timing: CellEventTiming) -> some View {
        let change = CellChange(coordinate: Coordinate(row: 1, column: 1), from: .water,
                                delay: 0, duration: Motion.stateSwap)
        return HStack(spacing: 18) {
            ForEach(frames, id: \.self) { t in
                let p = timing.swap(change, at: t)
                VStack(spacing: 10) {
                    ZStack {
                        BoardCell(from, size: cell).opacity(1 - p)
                        BoardCell(to, size: cell).opacity(p)
                        CellSplashFrame(tone: tone, cell: cell, timing: timing, elapsed: t)
                    }
                    .frame(width: cell, height: cell)
                    Text(verbatim: "\(Int(t * 1000))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.inkSecondary)
                }
            }
        }
    }
}

#Preview("Всплеск · раскадровка") {
    SplashStoryboard()
        .preferredColorScheme(.dark)
}

#Preview("Всплеск · светлая") {
    SplashStoryboard()
        .preferredColorScheme(.light)
}

#Preview("Всплеск · Reduce Motion") {
    SplashStoryboard(reduceMotion: true)
        .preferredColorScheme(.dark)
}
