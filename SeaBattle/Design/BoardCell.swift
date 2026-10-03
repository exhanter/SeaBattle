//
//  BoardCell.swift
//  Sea Battle — одна клетка поля
//
//  Один вид на всю игру (спека 2.3). Размер приходит параметром, всё остальное
//  считается от него: радиус, толщина кромок, длина креста. Абсолютных величин
//  здесь нет ни одной — поле на iPhone SE и на iPad рисуется одним кодом.
//
//  Имя `BoardCell` (не `CellView`, как у старого представления до R4.6) и по
//  смыслу точнее: клетка поля, в пару к `BoardView` из R1.4.
//
//  Перевод из CSS макетов, где это нужно знать:
//  - `inset 0 1px 0` (тень внутрь без размытия) — это светлая линия по верхней
//    кромке. Здесь обводка градиентом, гаснущим вниз: она повторяет скругление;
//  - `inset 0 -2px 4px` и любая другая тень внутрь — `insetShadow`: всё снаружи
//    формы, размытое с сигмой blur / 2 и обрезанное по форме, как в браузере;
//  - `radial-gradient(circle at X Y, …)` без размера тянется до **дальнего
//    угла** рамки, а не до её края;
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
    /// Корабль в запрещённой позиции при расстановке: та же рампа корпуса, но
    /// розовая. **Из ядра правил не приходит никогда** — у `CellState` такого
    /// состояния нет и быть не должно: запрет существует только пока корабль
    /// ставят, а по правилам игры его в этот момент ещё нет на поле.
    case shipDenied

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
            case .water:      water
            case .miss:       missPit
            case .ship:       hull
            case .hit:        breach
            case .hitMine:    burningHull
            case .sunk:       burntSteel
            case .shipDenied: deniedHull
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
            .fill(LinearGradient.waterCellCSS)
            .overlay { bevel(highlight: .waterSheen, shade: .waterShade, blur: 0.125) }
    }

    /// M1: тёмное пятно 56 % клетки. Под ним — та же вода, поэтому воронка
    /// читается углублением, а не наклейкой.
    private var missPit: some View {
        water.overlay {
            ZStack {
                // Подсвечена только нижняя кромка, а не всё кольцо: в макете это
                // внешняя тень `0 1px 0` — копия пятна, сдвинутая вниз. CSS рисует
                // внешнюю тень только **за пределами** пятна, поэтому из копии
                // вырезано само пятно. Пятно полупрозрачное: без выреза копия
                // просвечивает сквозь него, и нижняя половина воронки становится
                // светлым полукругом с жёсткой линией посередине (так и было до
                // сверки на подложке поля, 03.10).
                Circle()
                    .fill(Color.missRim)
                    .offset(y: px(0.04))
                    .mask {
                        ZStack {
                            // Шире пятна: сдвинутая копия выходит за его рамку.
                            Rectangle().padding(-px(0.1))
                            Circle().blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    }
                Circle()
                    // У края пятна остаётся 12 % плотности, а не ноль: в макете
                    // воронка не растворяется полностью, иначе она мельчает и
                    // читается точкой вместо вмятины.
                    .fill(RadialGradient(stops: [.init(color: .missPit, location: 0),
                                                 .init(color: .missPit.opacity(0.53), location: 0.62),
                                                 .init(color: .missPit.opacity(0.14), location: 1)],
                                         center: .init(x: 0.5, y: 0.32),
                                         // CSS `circle at 50% 32%` без размера
                                         // тянется до дальнего угла рамки пятна:
                                         // √(0,5² + 0,68²) = 0,844 диаметра 0,56.
                                         // С радиусом пятна (0,28) край воронки
                                         // выходил светлее эталона вдвое.
                                         startRadius: 0, endRadius: px(0.473))
                        // `inset 0 2px 2px` — верхний край воронки уходит в тень,
                        // это и делает её вмятиной, а не пятном. В обеих темах
                        // одна и та же, поэтому токена у неё нет.
                        .shadow(.inner(color: Self.missPitShade, radius: px(0.04), y: px(0.07))))
            }
            .frame(width: px(0.56), height: px(0.56))
        }
    }

    private var hull: some View {
        shape
            .fill(LinearGradient.hullSand)
            .overlay { bevel(highlight: .hullSheen, shade: .hullShade, blur: 0.094) }
    }

    /// Запрет при расстановке: та же рампа и тот же бевель, только розовые.
    /// Геометрия общая с корпусом намеренно — розовый должен читаться как
    /// «этот самый корабль нельзя сюда», а не как другая клетка.
    private var deniedHull: some View {
        shape
            .fill(LinearGradient.hullDenied)
            .overlay { bevel(highlight: .hullSheen, shade: .hullShade, blur: 0.094) }
    }

    /// F4: сквозь пробоину видна вода, поэтому основа та же. Кромок четыре и они
    /// разного тона — это объём: свет сверху, тень снизу-справа.
    private var breach: some View {
        water
            .overlay { shape.fill(Color.fireDarken) }
            // Свечение внутрь — `inset 0 0 24px` и `inset 0 0 11px` при клетке
            // 32 (кадр 16a), то есть 0,75 и 0,34 клетки. Прежние полосы 0,18 и
            // 0,05 гасили тепло у самой кромки: на 12 % ширины клетка уже была
            // холодной водой, у эталона там ещё тёплый свет (сверка 03.10).
            // Вода сквозь середину всё равно видна — у тени внутрь на кромке
            // только половина плотности, и дальше она спадает.
            .overlay { insetShadow(.fireGlowOut, blur: 0.75) }
            .overlay { insetShadow(.fireGlowIn, blur: 0.34) }
            .overlay {
                shape.strokeBorder(edgeGradient, lineWidth: max(1, px(0.042)))
            }
            // Ореол светит наружу, на подложку поля, и потому не обрезается.
            // В CSS — рамка 2 px ровно по кромке (от −1 до +1) с размытием 1 px.
            .overlay {
                shape
                    .strokeBorder(Color.fireHalo, lineWidth: max(1.5, px(0.0625)))
                    .blur(radius: px(0.031))
                    .padding(-px(0.031))
            }
            .overlay { crossBars(ink: .fireCross, stroke: .fireCrossEdge) }
    }

    /// F1: огонь ложится поверх **своего** корпуса, а не поверх воды. Три слоя с
    /// режимами смешивания обязательны: без них выходит плоская оранжевая
    /// заливка, а не горящий корпус.
    ///
    /// Корпус под огнём — не K2 целиком: в макете (23a, 21a, 21c, 4c, 14a)
    /// у F1 нет нижней тени бевеля, зато есть полоса света сверху вдвое шире и
    /// тёплое свечение **наружу**, на подложку поля. Без свечения и с тенью
    /// горящая клетка выходила темнее эталона на четверть внизу (сверка 03.10).
    private var burningHull: some View {
        shape
            .fill(LinearGradient.hullSand)
            .background {
                shape.fill(Self.burningGlow).blur(radius: px(0.17))
            }
            .overlay {
                shape.strokeBorder(LinearGradient(stops: [.init(color: Self.burningSheen, location: 0),
                                                          .init(color: .clear, location: 0.35)],
                                                  startPoint: .top, endPoint: .bottom),
                                   lineWidth: max(1, px(0.07)))
            }
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
                                          // До дальнего угла, как в CSS:
                                          // √(0,5² + 0,74²) = 0,893 клетки.
                                          startRadius: 0, endRadius: px(0.893)))
            }
            // У F1 под крестом **тень** (`0 1px 2px`), а не обводка, как у F4 и
            // S4: жёсткий тёмный контур делал белый крест коричневым.
            .overlay {
                crossBars(ink: .hitCross)
                    // Тень от креста целиком, а не от каждого штриха: иначе
                    // тень одного ложится поверх другого.
                    .compositingGroup()
                    .shadow(color: .hitCrossShadow, radius: px(0.04), y: px(0.04))
            }
    }

    /// Тень внутри воронки M1 — `rgba(0,0,0,.55)` в обеих темах.
    private static let missPitShade = Color.black.opacity(0.55)
    /// Свечение F1 наружу — `rgba(255,122,47,.30)`; в пакете токена нет
    /// (`Chrome/FireSoft` — это капсула, у неё .24).
    private static let burningGlow = Color(red: 1, green: 122 / 255, blue: 47 / 255).opacity(0.3)
    /// Полоса света сверху у F1 — `inset 0 2px 0 rgba(255,255,255,.50)`.
    private static let burningSheen = Color.white.opacity(0.5)

    private var burntSteel: some View {
        shape
            .fill(LinearGradient.steelSunk)
            .overlay { bevel(highlight: .steelSheen, shade: .steelShade, blur: 0.156) }
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
    /// Линия — `inset 0 1px 0`: 1 pt при клетке 32, не тоньше точки. Тень —
    /// `inset 0 -2px <blur>`, у воды размытие 4 px, у корпуса 3, у стали 5;
    /// доли считаются от клетки 32 (iPhone). Тень — точный перевод CSS через
    /// `insetShadow`, а не градиент снизу: размытие в браузере захватывает и
    /// бока клетки, и без этого края выходили светлее эталона на 15–20 единиц
    /// в светлой теме (сверка на подложке поля, 03.10).
    private func bevel(highlight: Color, shade: Color, blur: CGFloat) -> some View {
        ZStack {
            insetShadow(shade, blur: blur, y: -0.0625)
            shape.strokeBorder(LinearGradient(stops: [.init(color: highlight, location: 0),
                                                      .init(color: .clear, location: 0.35)],
                                              startPoint: .top, endPoint: .bottom),
                               lineWidth: max(1, px(0.02)))
        }
    }

    /// Точный перевод CSS `box-shadow: inset 0 <y> <blur>`: всё, что **снаружи**
    /// формы (сдвинутой на `y`), залито цветом, размыто и обрезано по форме. Так на кромке ровно
    /// половина плотности и гауссов спад внутрь, как у браузера. `blur` — доля
    /// размера клетки; у CSS сигма размытия — половина радиуса, у SwiftUI
    /// `blur(radius:)` — сама сигма.
    private func insetShadow(_ color: Color, blur: CGFloat, y: CGFloat = 0) -> some View {
        let sigma = px(blur) / 2
        return Rectangle()
            .fill(color)
            .padding(-sigma * 3)
            .mask {
                ZStack {
                    Rectangle().padding(-sigma * 3)
                    shape.offset(y: px(y)).blendMode(.destinationOut)
                }
                .compositingGroup()
            }
            .blur(radius: sigma)
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
    /// Без `stroke` — крест без обводки (F1 кладёт под него тень).
    private func crossBars(ink: Color, stroke: Color? = nil) -> some View {
        let length = (size * 0.58).rounded()
        let thickness = max(1.5, px(0.085))
        let outline = max(0.75, px(0.03))
        return ZStack {
            if let stroke {
                bar(length + outline * 2, thickness + outline * 2, stroke, 45)
                bar(length + outline * 2, thickness + outline * 2, stroke, -45)
            }
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
        (Geometry.Cell.iPadPortrait, "42 · iPad"),
        (37, "37 · iPad mini — клетка от места"),
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
                    Text(verbatim: "кусок поля 32 pt, зазор 3 pt")
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

/// Поле B1 ровно как эталонное в макете — та же раскладка клеток, та же
/// геометрия и тот же фон под полем, — чтобы сверять клетки по пикселям там,
/// где они на самом деле живут: на подложке поля. Клетки полупрозрачные, и на
/// открытом море (`SingleCellProbe`) весь профиль уезжал на ≈14 единиц.
///
/// Эталоны: чужое поле — кадр 16a (клетка 32, зазор 3), своё — блок 3b
/// (клетка 26, зазор 2; это единственное своё поле макета, где клетки —
/// отдельные элементы, а не корабли поверх; подложка там .12, а не .10, как в
/// текущих кадрах и токенах, — отсюда +4 единицы в зазорах). Фон —
/// вертикальный градиент из того же кадра. Рамка кадра 381 × 381 (у своего 312 × 312)
/// совпадает со снимком макета с полями 10 pt, поэтому клетки ложатся в те же
/// пиксели: у макета кант 1 pt **снаружи** отступа 6, у нас внутри, и подложка
/// на 2 pt меньше — но начало сетки совпадает.
private struct BoardReferenceProbe: View {
    let role: Side
    /// Светлая тема — только своё поле: светлое поле 3b стоит рядом с тёмным.
    var light = false

    var body: some View {
        let isFoe = role == .foe
        let metrics = isFoe ? BoardMetrics(cell: 32, gap: 3) : BoardMetrics(cell: 26, gap: 2)
        let side: CGFloat = isFoe ? 381 : 312
        BoardView(cells: isFoe ? Self.foe : Self.you, role: role, metrics: metrics)
            .frame(width: side, height: side)
            .background(LinearGradient(stops: isFoe ? Self.foeSea : light ? Self.youSeaLight : Self.youSea,
                                       startPoint: .top, endPoint: .bottom))
            .preferredColorScheme(light ? .light : .dark)
    }

    private static func cells(_ rows: [String], _ legend: [Character: BoardCellState]) -> [BoardCellState] {
        rows.flatMap { row in row.map { legend[$0] ?? .water } }
    }

    private static func stops(_ values: [(Double, Double, Double)]) -> [Gradient.Stop] {
        values.enumerated().map { index, rgb in
            Gradient.Stop(color: Color(red: rgb.0 / 255, green: rgb.1 / 255, blue: rgb.2 / 255),
                          location: Double(index + 1) / 10)
        }
    }

    /// Кадр 16a: 0 вода, 1 уничтожен, 2 промах, 3 пробоина.
    static let foe = cells([
        "0001111000", "0002000000", "0000000200", "0300000000", "0300000000",
        "0020000020", "0000002000", "0001100000", "0200000020", "0020000200",
    ], ["0": .water, "1": .sunk, "2": .miss, "3": .hit])

    /// Блок 3b: 0 корпус, 1 вода, 2 промах, 3 огонь на корпусе, 4 уничтожен.
    static let you = cells([
        "0001111111", "1121101100", "1111101111", "1111101111", "1211111331",
        "1111111211", "1100111111", "1111144111", "1111211111", "0112111101",
    ], ["0": .ship, "1": .water, "2": .miss, "3": .hitMine, "4": .sunk])

    /// Фон под полем в макете, по десятым высоты от 0,1 до 0,9. У чужого поля
    /// он восстановлен из зазоров между клетками за вычетом подложки: поле в
    /// 16a активное, и края кадра вокруг него подсвечены рамкой.
    static let foeSea = stops([(10, 41, 66), (11, 44, 69), (12, 46, 73), (12, 50, 77), (12, 52, 80),
                               (13, 55, 83), (13, 58, 85), (13, 60, 86), (15, 62, 89)])
    static let youSea = stops([(22, 45, 66), (23, 51, 73), (25, 57, 80), (26, 61, 87), (27, 67, 92),
                               (28, 73, 97), (29, 77, 101), (29, 83, 104), (30, 88, 109)])
    static let youSeaLight = stops([(48, 106, 133), (50, 112, 137), (53, 119, 143), (56, 125, 149),
                                    (60, 132, 153), (63, 140, 157), (66, 145, 160), (70, 152, 164),
                                    (75, 159, 167)])
}

#Preview("Сверка · поле B1, чужое как 16a", traits: .sizeThatFitsLayout) {
    BoardReferenceProbe(role: .foe)
}

#Preview("Сверка · поле B1, своё как 3b", traits: .sizeThatFitsLayout) {
    BoardReferenceProbe(role: .you)
}

#Preview("Сверка · поле B1, своё как 3b, светлая", traits: .sizeThatFitsLayout) {
    BoardReferenceProbe(role: .you, light: true)
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
