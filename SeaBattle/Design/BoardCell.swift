//
//  BoardCell.swift
//  Sea Battle — одна клетка поля
//
//  Один вид на всю игру (спека 2.3). Размер приходит параметром, всё остальное
//  считается от него: радиус, толщина кромок, длина креста. Абсолютных величин
//  здесь нет ни одной — поле на iPhone SE и на iPad рисуется одним кодом.
//
//  Имя `CellView` занято старым представлением, которое уйдёт в R4.6. `BoardCell`
//  и по смыслу точнее: клетка поля, в пару к `BoardView` из R1.4.
//
//  Перевод из CSS макетов, где это нужно знать:
//  - `inset 0 1px 0` (тень внутрь без размытия) — это светлая линия по верхней
//    кромке. Здесь обводка градиентом, гаснущим вниз: она повторяет скругление;
//  - `inset 0 -2px 4px` — мягкая тень внутрь снизу, здесь градиент от прозрачного
//    к тени по нижней трети;
//  - четыре разноцветные кромки пробоины в CSS дают жёсткие диагональные стыки
//    в углах; здесь угловой градиент — те же четыре цвета, но стыки мягкие.
//

import SwiftUI

// MARK: - Состояния

/// Шесть состояний клетки. `hit` и `hitMine` — **разные состояния, а не одно с
/// флагом**: на чужом поле это пробоина в воде, на своём — огонь на собственном
/// корпусе. Ядро правил их не различает (ему это не нужно), поэтому перевод
/// живёт здесь.
enum BoardCellState: String, CaseIterable, Sendable {
    /// Вода W1 / L2 — выпуклая клетка с бевелем.
    case water
    /// Промах M1 — воронка с подсвеченной нижней кромкой.
    case miss
    /// Свой корабль K2 «Песок».
    case ship
    /// Пробоина F4 на поле противника: сквозь неё видна вода.
    case hit
    /// Огонь F1 на своём корпусе.
    case hitMine
    /// Уничтожен S4 — выгоревшая сталь.
    case sunk

    /// Перевод состояния ядра в состояние отрисовки. Единственное место, где
    /// решается, пробоина это или огонь на своём корпусе: попадание по **своему**
    /// полю показывается как F1, по чужому — как F4.
    static func forDisplay(_ state: CellState, on side: Side) -> BoardCellState {
        switch state {
        case .water: .water
        case .miss:  .miss
        case .ship:  .ship
        case .hit:   side == .you ? .hitMine : .hit
        case .sunk:  .sunk
        }
    }
}

// MARK: - Клетка

struct BoardCell: View {
    let state: BoardCellState
    let size: CGFloat

    init(_ state: BoardCellState, size: CGFloat) {
        self.state = state
        self.size = size
    }

    var body: some View {
        ZStack {
            switch state {
            case .water:   water
            case .miss:    missPit
            case .ship:    hull
            case .hit:     breach
            case .hitMine: burningHull
            case .sunk:    burntSteel
            }
        }
        .frame(width: size, height: size)
        // Режимы смешивания у F1 обязаны видеть только саму клетку, а не экран
        // под ней, иначе огонь размажется по соседям.
        .compositingGroup()
        // Обрезки по форме здесь нет намеренно: ореол пробоины в макете светит
        // **наружу**, на подложку поля. Каждое состояние рисуется по `shape`
        // и потому не вылезает само по себе; обрезаются только те слои,
        // которым это нужно.
    }

    // MARK: Состояния

    private var water: some View {
        shape
            .fill(LinearGradient.waterCell)
            .overlay { bevel(highlight: .waterSheen, shade: .waterShade) }
    }

    /// M1: тёмное пятно 56 % клетки. Под ним — та же вода, поэтому воронка
    /// читается углублением, а не наклейкой.
    private var missPit: some View {
        water.overlay {
            ZStack {
                // Подсвечена только нижняя кромка, а не всё кольцо: в макете это
                // жёсткая тень без размытия, то есть копия пятна, сдвинутая вниз
                // и видимая лишь снизу. Пятно полупрозрачное, поэтому копию
                // приходится обрезать нижней половиной — иначе она просвечивает
                // сквозь пятно и воронка превращается в мишень.
                Circle()
                    .fill(Color.missRim)
                    .offset(y: px(0.04))
                    .mask {
                        VStack(spacing: 0) {
                            Color.clear
                            Color.black
                        }
                    }
                Circle()
                    // У края пятна остаётся 12 % плотности, а не ноль: в макете
                    // воронка не растворяется полностью, иначе она мельчает и
                    // читается точкой вместо вмятины.
                    .fill(RadialGradient(stops: [.init(color: .missPit, location: 0),
                                                 .init(color: .missPit.opacity(0.53), location: 0.62),
                                                 .init(color: .missPit.opacity(0.14), location: 1)],
                                         center: .init(x: 0.5, y: 0.32),
                                         startRadius: 0, endRadius: px(0.28)))
            }
            .frame(width: px(0.56), height: px(0.56))
        }
    }

    private var hull: some View {
        shape
            .fill(LinearGradient.hullSand)
            .overlay { bevel(highlight: .hullSheen, shade: .hullShade) }
    }

    /// F4: сквозь пробоину видна вода, поэтому основа та же. Кромок четыре и они
    /// разного тона — это объём: свет сверху, тень снизу-справа.
    private var breach: some View {
        water
            .overlay { shape.fill(Color.fireDarken) }
            // Свечение внутрь: ярче всего у самой кромки, гаснет внутрь. В CSS
            // это `inset 0 0 N` — тень без смещения и разброса, поэтому полная
            // плотность приходится на границу, а не на полосу шириной N.
            // Обводка шириной N/2, размытая на N/2, даёт ровно такой спад;
            // сплошная полоса в N залила бы середину и сквозь пробоину
            // перестала бы быть видна вода — то единственное, чем F4
            // отличается от F1.
            .overlay { innerGlow(.fireGlowOut, width: 0.18, blur: 0.18) }
            .overlay { innerGlow(.fireGlowIn, width: 0.05, blur: 0.035) }
            .overlay {
                shape.strokeBorder(edgeGradient, lineWidth: max(1, px(0.042)))
            }
            // Ореол светит наружу, на подложку поля, и потому не обрезается.
            .overlay {
                shape
                    .strokeBorder(Color.fireHalo, lineWidth: max(1.5, px(0.07)))
                    .blur(radius: px(0.05))
                    .padding(-px(0.015))
            }
            .overlay { crossBars(ink: .fireCross, stroke: .fireCrossEdge) }
    }

    /// F1: огонь ложится поверх **своего** корпуса, а не поверх воды. Три слоя с
    /// режимами смешивания обязательны: без них выходит плоская оранжевая
    /// заливка, а не горящий корпус.
    private var burningHull: some View {
        hull
            .overlay {
                shape
                    .fill(LinearGradient(colors: [.hitTintMulTop, .hitTintMulBottom],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .blendMode(.multiply)
            }
            .overlay {
                shape
                    .fill(LinearGradient(colors: [.hitTintScrTop, .hitTintScrBottom],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .blendMode(.screen)
            }
            .overlay {
                shape.fill(RadialGradient(stops: [.init(color: .hitWarmIn, location: 0),
                                                  .init(color: .hitWarmOut, location: 0.68),
                                                  .init(color: .clear, location: 1)],
                                          center: .init(x: 0.5, y: 0.26),
                                          startRadius: 0, endRadius: px(0.75)))
            }
            .overlay {
                crossBars(ink: .hitCross, stroke: .hitCrossShadow)
            }
    }

    private var burntSteel: some View {
        shape
            .fill(LinearGradient.steelSunk)
            .overlay { bevel(highlight: .steelSheen, shade: .steelShade) }
            .overlay { crossBars(ink: .sunkCross, stroke: .sunkCrossEdge) }
    }

    // MARK: Кирпичи

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Geometry.cellRadius(for: size), style: .continuous)
    }

    /// Доля размера клетки. Все толщины в макете заданы так же.
    private func px(_ fraction: CGFloat) -> CGFloat { size * fraction }

    /// Выпуклость: светлая линия по верхней кромке и мягкая тень внутрь снизу.
    ///
    /// Величины взяты из CSS макета и переведены в доли размера: линия там 1 px
    /// при клетке 48 px, то есть 2 % размера, а тень — `inset 0 -2px 4px`, она
    /// достаёт внутрь на 2 + 4/2 = 4 px, то есть на 8 %. Первая версия давала
    /// 5 % и 40 % — сверка по пикселям показала выбеленную верхнюю кромку и
    /// пережатый низ у стали и корпуса.
    private func bevel(highlight: Color, shade: Color) -> some View {
        ZStack {
            shape.fill(LinearGradient(stops: [.init(color: .clear, location: 0.88),
                                              .init(color: shade, location: 1)],
                                      startPoint: .top, endPoint: .bottom))
            shape.strokeBorder(LinearGradient(stops: [.init(color: highlight, location: 0),
                                                      .init(color: .clear, location: 0.35)],
                                              startPoint: .top, endPoint: .bottom),
                               lineWidth: max(1, px(0.02)))
        }
    }

    /// Свечение от кромки внутрь: полоса шириной `width` с размытием `blur`,
    /// обе величины — доли размера клетки. Значения подобраны не на глаз, а по
    /// профилю яркости эталона: тёплый свет держится у кромки и гаснет к 30 %
    /// ширины клетки, дальше видна холодная вода.
    private func innerGlow(_ color: Color, width: CGFloat, blur: CGFloat) -> some View {
        shape
            .strokeBorder(color, lineWidth: px(width))
            .blur(radius: px(blur))
            .clipShape(shape)
    }

    /// Четыре кромки пробоины. В CSS это border с четырьмя цветами и жёсткими
    /// стыками по диагоналям; угловой градиент даёт те же цвета по сторонам и
    /// мягкие переходы в углах.
    private var edgeGradient: AngularGradient {
        AngularGradient(stops: [.init(color: .fireEdgeTop, location: 0),
                                .init(color: .fireEdgeRight, location: 0.25),
                                .init(color: .fireEdgeBottom, location: 0.5),
                                .init(color: .fireEdgeLeft, location: 0.75),
                                .init(color: .fireEdgeTop, location: 1)],
                        center: .center,
                        angle: .degrees(-90))
    }

    /// Крест из двух скруглённых штрихов вместо глифа «✕»: у глифа концы острые
    /// и он зависит от шрифта. Сначала обе капсулы обводкой, поверх — обе
    /// заливкой, поэтому внутренних стыков не видно.
    private func crossBars(ink: Color, stroke: Color) -> some View {
        let length = (size * 0.58).rounded()
        let thickness = max(1.5, px(0.085))
        let outline = max(0.75, px(0.03))
        return ZStack {
            bar(length + outline * 2, thickness + outline * 2, stroke, 45)
            bar(length + outline * 2, thickness + outline * 2, stroke, -45)
            bar(length, thickness, ink, 45)
            bar(length, thickness, ink, -45)
        }
    }

    private func bar(_ length: CGFloat, _ thickness: CGFloat,
                     _ color: Color, _ degrees: Double) -> some View {
        Capsule()
            .fill(color)
            .frame(width: length, height: thickness)
            .rotationEffect(.degrees(degrees))
    }
}

// MARK: - Превью: сверка с блоком 3a макетов

/// Все шесть состояний во всех размерах, которые встречаются в игре. Это и есть
/// проверка шага 3 порядка сборки.
private struct BoardCellGallery: View {
    private let sizes: [(CGFloat, String)] = [
        (Geometry.Cell.iPhoneSmallCoords, "28 · SE с координатами"),
        (Geometry.Cell.iPhone, "32 · iPhone 393"),
        (Geometry.Cell.iPadPortrait, "42 · iPad вертикально"),
        (Geometry.Cell.iPadPlacement, "46 · iPad, расстановка"),
    ]

    var body: some View {
        ZStack {
            SeaBackground()

            VStack(alignment: .leading, spacing: 20) {
                ForEach(sizes, id: \.0) { size, label in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(label)
                            .font(TypeScale.caption)
                            .foregroundStyle(Color.inkSecondary)
                        HStack(spacing: Geometry.Cell.gapPhone) {
                            ForEach(BoardCellState.allCases, id: \.self) { state in
                                BoardCell(state, size: size)
                            }
                        }
                    }
                }

                // Клетки в сетке: так видно, что бевель и зазор складываются в
                // поле, а не в набор отдельных кнопок.
                VStack(alignment: .leading, spacing: 8) {
                    Text("кусок поля 32 pt, зазор 3 pt")
                        .font(TypeScale.caption)
                        .foregroundStyle(Color.inkSecondary)
                    fragment
                }
            }
            .padding(18)
            .glassPanel(.g2)
            .padding(Geometry.Inset.phoneSide)
        }
    }

    private var fragment: some View {
        let rows: [[BoardCellState]] = [
            [.water, .water, .miss,    .water,   .water],
            [.water, .hit,   .hit,     .sunk,    .water],
            [.miss,  .water, .water,   .sunk,    .miss],
            [.water, .ship,  .hitMine, .ship,    .water],
            [.water, .water, .miss,    .water,   .water],
        ]
        return VStack(spacing: Geometry.Cell.gapPhone) {
            ForEach(rows.indices, id: \.self) { row in
                HStack(spacing: Geometry.Cell.gapPhone) {
                    ForEach(rows[row].indices, id: \.self) { column in
                        BoardCell(rows[row][column], size: Geometry.Cell.iPhone)
                    }
                }
            }
        }
    }
}

/// Одна клетка крупно, по центру экрана, без обвязки. Нужна для сверки с
/// эталоном по пикселям: макет рендерится в headless-Chrome, оба снимка
/// сканируются по средней линии и сравниваются числами. Глазом кромку в
/// полтора пикселя и спад свечения не оценить — на миниатюре приглушённая
/// тёплая кромка выглядит яркой оранжевой, проверено.
private struct SingleCellProbe: View {
    let state: BoardCellState
    var body: some View {
        ZStack {
            LinearGradient.sea.ignoresSafeArea()
            // Клетка по центру и крупно; границы скрипт сверки находит сам,
            // сканируя центральную колонку снимка. Угадывать положение нельзя:
            // первая версия кропа промахнулась на полтора десятка пикселей и
            // срезала низ клетки — «расхождение» у корпуса и стали внизу
            // оказалось артефактом замера, а не кода.
            BoardCell(state, size: 200)
        }
    }
}

#Preview("Клетка · тёмная") {
    BoardCellGallery()
        .preferredColorScheme(.dark)
}

#Preview("Клетка · светлая") {
    BoardCellGallery()
        .preferredColorScheme(.light)
}

#Preview("Сверка · пробоина F4") {
    SingleCellProbe(state: .hit)
        .preferredColorScheme(.dark)
}

#Preview("Сверка · вода W1") {
    SingleCellProbe(state: .water)
        .preferredColorScheme(.dark)
}

#Preview("Сверка · промах M1") {
    SingleCellProbe(state: .miss)
        .preferredColorScheme(.dark)
}

#Preview("Сверка · корпус K2") {
    SingleCellProbe(state: .ship)
        .preferredColorScheme(.dark)
}

#Preview("Сверка · огонь на корпусе F1") {
    SingleCellProbe(state: .hitMine)
        .preferredColorScheme(.dark)
}

#Preview("Сверка · уничтожен S4") {
    SingleCellProbe(state: .sunk)
        .preferredColorScheme(.dark)
}
