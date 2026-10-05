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
    /// Чем показан всплеск (решение заказчика 05.10: два кольца бросались в
    /// глаза). Поменять — одна строка. Для `.ripple` нужен Metal Toolchain
    /// (`xcodebuild -downloadComponent MetalToolchain`, установлен 05.10).
    static let wave: WaveStyle = .ripple

    enum WaveStyle: Sendable {
        /// Одно расходящееся кольцо.
        case singleRing
        /// Само поле идёт волной (`BoardRipple.metal`), колец нет.
        case ripple
    }

    /// Сколько колец рисовать: в 14d их два, с 05.10 — одно или ни одного.
    static var ringCount: Int {
        switch wave {
        case .singleRing: 1
        case .ripple: 0
        }
    }

    /// Диаметр кольца — доля клетки.
    static let ringDiameter: CGFloat = 1.45
    /// Масштаб кольца: от 0,45 растёт на 1,35 — как в 14d.
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
                ForEach(0..<CellEffectMetrics.ringCount, id: \.self) { index in
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

// MARK: - Волна по полю

/// Числа волны — подбираются здесь (заказчик подбирает анимацию, 05.10).
/// Сейчас волна **в пределах клетки выстрела**: гаснет к `radiusCells` от
/// центра, чуть за кромкой — качается сама клетка и её край.
enum RippleMetrics {
    /// Наибольшее смещение — доля клетки. Больше 0,15 внутри клетки уже
    /// подтягивает в неё картинку соседей.
    static let amplitudeRatio: CGFloat = 0.12
    /// Частота колебаний (рад/с) и затухание во времени.
    static let frequency: Float = 28
    static let decay: Float = 6
    /// Скорость волны — клеток в секунду: за ~0,15 с доходит до кромки.
    static let speedCells: CGFloat = 4
    /// Затухание по расстоянию — в клетках (внутри клетки почти не влияет).
    static let falloffCells: CGFloat = 1
    /// Дальше этого от центра клетки волны нет: 0,5 — кромка клетки.
    static let radiusCells: CGFloat = 0.6
    static let duration: Double = 0.6
}

/// Поле идёт волной от клетки выстрела. Вешается на картинку сетки
/// (`drawingGroup`) — искажается вся сетка разом. Под Reduce Motion и в
/// варианте «одно кольцо» не делает ничего.
struct BoardRippleModifier: ViewModifier {
    let event: CellEvent?
    /// Центр клетки выстрела в координатах того, к чему применяется.
    let origin: CGPoint
    let cell: CGFloat
    let reduceMotion: Bool
    /// Превью: волна застыла в этот момент от выстрела.
    var still: Double?

    func body(content: Content) -> some View {
        if let still {
            content.layerEffect(shader(still), maxSampleOffset: maxOffset)
        } else if let event, !reduceMotion, CellEffectMetrics.wave == .ripple {
            EventClock(start: event.start, duration: RippleMetrics.duration) { t in
                content.layerEffect(shader(t), maxSampleOffset: maxOffset,
                                    isEnabled: t < RippleMetrics.duration)
            }
            .id(event.id)
        } else {
            content
        }
    }

    private var maxOffset: CGSize {
        CGSize(width: cell * RippleMetrics.amplitudeRatio, height: cell * RippleMetrics.amplitudeRatio)
    }

    private func shader(_ t: Double) -> Shader {
        ShaderLibrary.boardRipple(
            .float2(origin),
            .float(Float(t)),
            .float(Float(cell * RippleMetrics.amplitudeRatio)),
            .float(RippleMetrics.frequency),
            .float(RippleMetrics.decay),
            .float(Float(cell * RippleMetrics.speedCells)),
            .float(Float(cell * RippleMetrics.falloffCells)),
            .float(Float(cell * RippleMetrics.radiusCells)))
    }
}

// MARK: - Финал партии

/// Последний выстрел: по полю наискось проходит световой вал — поле идёт
/// волной и светлеет (`boardSweep` в `BoardRipple.metal`). Одно на все режимы —
/// вешает `BoardView`, когда в окружении есть `MatchFinale` и последнее событие
/// этого поля и есть финальный выстрел. Латунной вспышки окантовки нет: на
/// iPhone её не было видно (решение заказчика 05.10).
enum FinaleMetrics {
    /// Проход вала по полю.
    static let duration: Double = 0.6
    /// Наклон фронта, градусы от вертикали.
    static let angle: Double = 22
    /// Ширина вала, длина волны внутри, смещение — в клетках; свет — прибавка
    /// к яркости на гребне.
    static let widthCells: CGFloat = 2.2
    static let wavelengthCells: CGFloat = 3.2
    static let amplitudeCells: CGFloat = 0.12
    static let glow: Float = 0.5
    /// Reduce Motion: вместо вала — короткая ровная вспышка всего поля.
    static let stillFlash: Double = 0.5
    static let stillPeak: Double = 0.22

    /// Положение вала 0…1 в момент `x` от начала; `nil` — вала нет.
    static func sweep(at x: Double) -> Double? {
        let p = x / duration
        guard p > 0, p < 1 else { return nil }
        // Равномерно: с ease-in-out вал проскакивал середину поля.
        return p
    }

    /// Направление прохода — перпендикуляр к фронту.
    static var direction: CGVector {
        let a = angle * .pi / 180
        return CGVector(dx: cos(a), dy: sin(a))
    }
}

/// Вал по картинке сетки. Вешается рядом с `BoardRippleModifier`.
struct BoardSweepModifier: ViewModifier {
    let finale: MatchFinale?
    let size: CGSize
    let cell: CGFloat
    let reduceMotion: Bool
    /// Превью: вал застыл в этом положении 0…1.
    var still: Double?

    func body(content: Content) -> some View {
        if let still {
            content.layerEffect(shader(still), maxSampleOffset: maxOffset)
        } else if let finale {
            let delay = Motion.scaled(Motion.finaleDelay, reduceMotion: reduceMotion)
            EventClock(start: finale.start, duration: delay + FinaleMetrics.duration) { t in
                if reduceMotion {
                    content.overlay {
                        Color.white
                            .opacity(stillFlash(t - delay))
                            .blendMode(.plusLighter)
                            .allowsHitTesting(false)
                    }
                } else {
                    let p = FinaleMetrics.sweep(at: t - delay)
                    content.layerEffect(shader(p ?? 0), maxSampleOffset: maxOffset,
                                        isEnabled: p != nil)
                }
            }
        } else {
            content
        }
    }

    private var maxOffset: CGSize {
        CGSize(width: cell * FinaleMetrics.amplitudeCells, height: cell * FinaleMetrics.amplitudeCells)
    }

    private func shader(_ p: Double) -> Shader {
        let d = FinaleMetrics.direction
        let width = cell * FinaleMetrics.widthCells
        // Фронт идёт от-за верхнего левого угла до-за нижнего правого.
        let span = size.width * d.dx + size.height * d.dy
        let front = -width * 2 + (span + width * 4) * p
        return ShaderLibrary.boardSweep(
            .float2(CGPoint(x: d.dx, y: d.dy)),
            .float(Float(front)),
            .float(Float(width)),
            .float(Float(cell * FinaleMetrics.amplitudeCells)),
            .float(Float(cell * FinaleMetrics.wavelengthCells)),
            .float(FinaleMetrics.glow))
    }

    private func stillFlash(_ x: Double) -> Double {
        guard x > 0, x < FinaleMetrics.stillFlash else { return 0 }
        return FinaleMetrics.stillPeak * (1 - x / FinaleMetrics.stillFlash)
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

/// Вал финала в трёх положениях — шейдер без часов.
private struct SweepStoryboard: View {
    var body: some View {
        let metrics = BoardMetrics(cell: 24)
        let cells = (0..<100).map { $0 % 7 == 0 ? BoardCellState.sunk : .water }
        ZStack {
            SeaBackground()
            HStack(spacing: 20) {
                ForEach([0.2, 0.5, 0.8], id: \.self) { p in
                    BoardView(cells: cells, role: .foe, metrics: metrics)
                        .modifier(BoardSweepModifier(finale: nil,
                                                     size: CGSize(width: metrics.boardSide,
                                                                  height: metrics.boardSide),
                                                     cell: metrics.cell, reduceMotion: false,
                                                     still: p))
                }
            }
        }
    }
}

/// Волна от выстрела в В5 (потопленная клетка) в три момента — шейдер без часов.
private struct RippleStoryboard: View {
    var body: some View {
        let metrics = BoardMetrics(cell: 32)
        let cells = (0..<100).map { $0 % 7 == 0 ? BoardCellState.sunk : .water }
        let origin = metrics.cellOrigin(Coordinate(row: 5, column: 3))
        ZStack {
            SeaBackground()
            HStack(spacing: 20) {
                ForEach([0.04, 0.1, 0.2], id: \.self) { t in
                    BoardView(cells: cells, role: .foe, metrics: metrics)
                        .modifier(BoardRippleModifier(
                            event: nil,
                            origin: CGPoint(x: metrics.inset + origin.x + metrics.cell / 2,
                                            y: metrics.inset + origin.y + metrics.cell / 2),
                            cell: metrics.cell, reduceMotion: false, still: t))
                }
            }
        }
    }
}

#Preview("Выстрел · волна", traits: .fixedLayout(width: 1180, height: 420)) {
    RippleStoryboard()
        .preferredColorScheme(.dark)
}

#Preview("Финал · вал", traits: .fixedLayout(width: 900, height: 340)) {
    SweepStoryboard()
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
