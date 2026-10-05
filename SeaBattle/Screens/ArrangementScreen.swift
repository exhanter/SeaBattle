//
//  ArrangementScreen.swift
//  Sea Battle — расстановка флота (R2.2, шаг 8 порядка сборки)
//
//  Спека 4.4. Экран открывается с уже расставленным флотом, дока нет: игрок
//  либо соглашается, либо перемешивает, либо правит руками.
//
//  Где спека расходится с макетами — права спека (она новее на десять туров):
//  запрет показывается **розовым кораблём**, без красной разметки клеток и без
//  контура соседа; отпущенный в запрете корабль **остаётся там**, а не
//  возвращается на место; подвижность показывает дрожание, а не латунная
//  обводка (обводка отклонена в туре 7). Расхождения перечислены в
//  `docs/STATUS.md`.
//

import SwiftUI

// MARK: - Числа экрана

enum ArrangementMetrics {
    /// Между заголовком и полем.
    static let boardGap: CGFloat = 18
    /// Корабль в руке «поднят» над полем: чуть крупнее и с тенью. Раньше он
    /// был полупрозрачным (спека 4.4), но тогда его цвет смешивался с цветом
    /// корабля под ним (решение заказчика 05.10).
    static let liftScale: CGFloat = 1.06
    static let liftShadowRadius: CGFloat = 5
    static let liftShadowY: CGFloat = 4
    static let liftShadowAlpha: Double = 0.5
    /// Предупреждение появляется и гаснет вместе с розовым кораблём (2.16).
    static let warningFade: Double = 0.160
}

// MARK: - Экран

struct ArrangementScreen: View {

    @Binding var editor: FleetEditor
    /// Куда ведёт строка возврата: на экран уровня, если он показывался, иначе
    /// в меню (спека 3.1). Подпись меняется вместе с этим. `nil` — строки
    /// возврата нет: второй игрок вдвоём на устройстве не может вернуться к
    /// флоту первого.
    let backTitle: LocalizedStringKey?
    /// Название вне правки. Вдвоём на устройстве — с именем того, чей флот
    /// («Флот: Аня»): устройство переходит из рук в руки.
    var title: LocalizedStringKey = "Your fleet"
    /// Главная кнопка вне правки. Вдвоём она называет следующего (4.7).
    var startTitle: LocalizedStringKey = "Start"
    var onStart: () -> Void = {}
    var onBack: () -> Void = {}
    var onMenu: () -> Void = {}
    /// Расстановка перед игрой на бумаге: на iPad стол сразу с координатами.
    var isPaper = false
    /// Сетевая партия до подключения соперника (4.4): расстановку править
    /// можно, главная кнопка заблокирована. На «Готово» в правке не влияет.
    var startEnabled = true

    @Environment(\.usesPadLayout) private var usesPadLayout
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if usesPadLayout {
                // iPad: отдельного экрана расстановки нет — стол на два поля,
                // правка на нём же (4.4). До боя «Меню» выходит без вопроса.
                PadTableScreen(phase: .placement(editor: $editor, onStart: onStart),
                               onMenu: onMenu, isPaper: isPaper, startEnabled: startEnabled)
            } else {
                phone
            }
        }
        .battleTypeSize()
    }

    private var phone: some View {
        GeometryReader { proxy in
            let metrics = BoardMetrics(cell: Geometry.SizeClass.forWidth(proxy.size.width).cell)

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: Geometry.Warning.belowBoard) {
                        board(metrics)
                        warning
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, ArrangementMetrics.boardGap)
                }
                .scrollBounceBehavior(.basedOnSize)

                actions
            }
            // Предупреждение появляется и гаснет вместе с розовым кораблём —
            // одной анимацией на оба, иначе строка приходит после того, как
            // корабль уже покраснел.
            .animation(.easeInOut(duration: Motion.scaled(ArrangementMetrics.warningFade,
                                                          reduceMotion: reduceMotion)),
                       value: editor.conflictKind)
        }
    }

    // MARK: Заголовок и подсказка

    private var header: some View {
        // Подзаголовок — слот `ScreenTitle` (спека 2.11 после раунда 4): верх
        // один на все экраны, панели с деревянным кантом из кадров туров 6–8
        // отменены. Ни название, ни подсказка **не меняются при ошибке** — о
        // ней говорит `WarningLine` под полем, рядом с розовым кораблём.
        ScreenTitle(title: editor.isEditing ? "Change the layout" : title,
                    back: backTitle,
                    subtitle: editor.isEditing
                        ? "Drag a ship to move it · tap to turn it"
                        : "The ships are placed for you",
                    onBack: onBack)
            .padding(.top, NavMetrics.titleTopBelowSafeArea)
    }

    // MARK: Поле

    private func board(_ m: BoardMetrics) -> some View {
        EditableFleetBoard(editor: $editor, metrics: m)
    }

    // MARK: Строка ошибки

    @ViewBuilder
    private var warning: some View {
        // Два текста, а не один: «Клетка занята» заметнее, чем «нужен зазор»,
        // и путать их значит объяснять игроку не ту беду (спека 2.16).
        if let kind = editor.conflictKind {
            WarningLine(text: kind == .overlap ? "That cell is taken"
                                               : "A one-cell gap is needed")
                .transition(.opacity)
        }
    }

    // MARK: Кнопки

    private var actions: some View {
        BottomStack(onMenu: onMenu) {
            HStack(spacing: Geometry.Nav.stackGap) {
                Button {
                    editor.shuffle()
                } label: {
                    Label("Shuffle", systemImage: "shuffle")
                }
                .secondaryButton(enabled: editor.actionsEnabled)

                if !editor.isEditing {
                    Button {
                        editor.beginEditing()
                    } label: {
                        Label("Change", systemImage: "hand.draw")
                    }
                    .secondaryButton(enabled: editor.actionsEnabled)
                }
            }

            Button {
                if editor.isEditing {
                    editor.finishEditing()
                } else {
                    onStart()
                }
            } label: {
                Text(editor.isEditing ? "Done" : startTitle)
            }
            .primaryButton(enabled: editor.canFinish && editor.actionsEnabled
                               && (editor.isEditing || startEnabled))
        }
    }
}

// MARK: - Поле с кораблями для правки

/// Своё поле с флотом из `FleetEditor`: дрожание, перетаскивание, поворот
/// касанием, розовый запрет. Одно на расстановку iPhone и на стол iPad
/// (4.4): правила жеста одни, копий быть не должно.
struct EditableFleetBoard: View {
    @Binding var editor: FleetEditor
    let metrics: BoardMetrics
    /// Как рисовать клетку, легшую прямо на чужой корабль. Пока заказчик
    /// выбирает по превью «Пересечение · …» — параметром.
    var overlapStyle: ShipOverlapStyle = .current

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

    private var alphabet: BoardAlphabet {
        .forLanguage(locale.language.languageCode?.identifier)
    }

    var body: some View {
        BoardView(cells: [BoardCellState](repeating: .water, count: 100),
                  role: .you, metrics: metrics)
            // Под кораблями одна вода: для VoiceOver поле здесь — корабли,
            // сто клеток «вода» только мешали бы их найти.
            .accessibilityHidden(true)
            // Корабли лежат **поверх** сетки, а не внутри неё: их надо тянуть
            // целиком, а сетка — это сто отдельных клеток.
            .overlay(alignment: .topLeading) {
                ships
                    .frame(width: metrics.gridSide, height: metrics.gridSide, alignment: .topLeading)
                    // С координатами (стол игры на бумаге) сетка сдвинута
                    // на столбик цифр и строку букв.
                    .offset(x: metrics.digitsWidth + metrics.axisGap + metrics.inset,
                            y: metrics.lettersHeight + metrics.axisGap + metrics.inset)
            }
            .frame(width: metrics.totalSize.width, height: metrics.totalSize.height)
    }

    private var ships: some View {
        ZStack(alignment: .topLeading) {
            ForEach(editor.ships) { ship in
                shipView(ship)
            }
        }
    }

    private func shipView(_ ship: ShipPlacement) -> some View {
        let isDragged = editor.draggingID == ship.id
        let denied = editor.deniedCells[ship.id] ?? []
        let isDenied = !denied.isEmpty
        let origin = metrics.cellOrigin(ship.origin)
        let size = metrics.shipSize(length: ship.length, orientation: ship.orientation)

        return ShipCells(ship: ship, metrics: metrics,
                         denied: denied,
                         overlaps: editor.overlapCells[ship.id] ?? [],
                         overlapStyle: overlapStyle,
                         isJiggling: editor.isEditing && !isDragged && !reduceMotion)
            .frame(width: size.width, height: size.height)
            .scaleEffect(isDragged ? ArrangementMetrics.liftScale : 1)
            .shadow(color: .black.opacity(isDragged ? ArrangementMetrics.liftShadowAlpha : 0),
                    radius: ArrangementMetrics.liftShadowRadius,
                    y: ArrangementMetrics.liftShadowY)
            .animation(.easeOut(duration: Motion.scaled(Motion.aim, reduceMotion: reduceMotion)),
                       value: isDragged)
            .offset(x: origin.x, y: origin.y)
            // Кого трогали последним, тот сверху — и под пальцем, и после.
            .zIndex(Double(editor.order(of: ship.id)))
            .gesture(dragGesture(ship), isEnabled: editor.isEditing)
            .onTapGesture { editor.rotate(ship.id) }
            .accessibilityElement()
            .accessibilityLabel(Text("\(ship.length)-cell ship"))
            .accessibilityValue(accessibilityValue(ship, isDenied: isDenied))
            .accessibilityAddTraits(editor.isEditing ? .isButton : [])
            .accessibilityAction { editor.rotate(ship.id) }
            // Перетаскивать VoiceOver не умеет — вместо жеста шаг на клетку.
            // Правило то же, что у пальца: корабль не упирается в соседей, а
            // краснеет, и только край поля его держит.
            .accessibilityActions {
                if editor.isEditing {
                    Button("Move left") { nudge(ship, columns: -1) }
                    Button("Move right") { nudge(ship, columns: 1) }
                    Button("Move up") { nudge(ship, rows: -1) }
                    Button("Move down") { nudge(ship, rows: 1) }
                    Button("Turn") { editor.rotate(ship.id) }
                }
            }
    }

    /// «Е4, по горизонтали» и, если стоит не по правилам, — почему. У
    /// однопалубного направления нет.
    private func accessibilityValue(_ ship: ShipPlacement, isDenied: Bool) -> Text {
        let cell = Text(verbatim: ShotChip.label(ship.origin, alphabet: alphabet))
        let place = ship.length == 1 ? cell
            : cell + Text(verbatim: ", ") + Text(ship.orientation == .horizontal ? "horizontal" : "vertical")
        return isDenied ? place + Text(verbatim: ", ") + Text("cannot be placed here") : place
    }

    private func nudge(_ ship: ShipPlacement, columns: Int = 0, rows: Int = 0) {
        editor.move(ship.id, to: Coordinate(row: ship.origin.row + rows,
                                            column: ship.origin.column + columns))
    }

    /// Смещение считается в **клетках**, а не в точках: между клетками корабль
    /// стоять не может, и плавное движение только обманывало бы. За какую
    /// клетку взяли, значения не имеет — корабль смещается на столько же
    /// клеток, на сколько ушёл палец, поэтому взятая клетка сама остаётся под
    /// ним.
    private func dragGesture(_ ship: ShipPlacement) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if editor.draggingID != ship.id { editor.beginDragging(ship.id) }
                editor.dragBy(columns: Int((value.translation.width / metrics.step).rounded()),
                              rows: Int((value.translation.height / metrics.step).rounded()))
            }
            .onEnded { _ in editor.endDragging() }
    }
}

// MARK: - Корабль как набор клеток

/// Корабль — **набор клеток**, а не цельный корпус: цельный вводил в
/// заблуждение (решение тура 6). Дрожит каждая клетка отдельно.
private struct ShipCells: View {
    let ship: ShipPlacement
    let metrics: BoardMetrics
    /// Клетки, попавшие в чужую зону, — розовые.
    let denied: Set<Coordinate>
    /// Из них — легшие прямо на чужой корабль.
    let overlaps: Set<Coordinate>
    let overlapStyle: ShipOverlapStyle
    let isJiggling: Bool

    var body: some View {
        let layout = ship.orientation == .horizontal
            ? AnyLayout(HStackLayout(spacing: metrics.gap))
            : AnyLayout(VStackLayout(spacing: metrics.gap))

        return layout {
            ForEach(ship.cells, id: \.self) { cell in
                JigglingCell(look: overlaps.contains(cell) ? .overlap(overlapStyle)
                                 : denied.contains(cell) ? .denied : .ship,
                             size: metrics.cell,
                             spec: .forCell(cell),
                             isJiggling: isJiggling)
            }
        }
    }
}

/// Как рисовать клетку корабля, легшую прямо на клетку другого корабля.
/// Клетки в кольце соседа (на воде) розовые во всех вариантах.
enum ShipOverlapStyle: CaseIterable, Sendable {
    /// Замещение: розовая клетка целиком закрывает клетку под собой.
    case replace
    /// Рамка: от клетки остаётся розовая рамка, внутри видна клетка снизу.
    case frame
    /// Вложение: розовая клетка поменьше, вокруг видна клетка снизу.
    case inset

    /// Что стоит в игре, пока заказчик выбирает.
    static let current: ShipOverlapStyle = .frame

    /// Толщина рамки и размер вложенной клетки — доли клетки.
    static let frameRatio: CGFloat = 0.17
    static let insetRatio: CGFloat = 0.6
}

/// Вид одной клетки корабля при расстановке.
private enum ShipCellLook: Equatable {
    case ship
    case denied
    case overlap(ShipOverlapStyle)
}

/// Одна клетка корабля со своим дрожанием. Отдельным типом, потому что нужен
/// собственный `@State` на клетку: без него все клетки качались бы в ногу.
private struct JigglingCell: View {
    let look: ShipCellLook
    let size: CGFloat
    let spec: JiggleSpec
    let isJiggling: Bool

    @State private var swung = false

    var body: some View {
        cell
            .frame(width: size, height: size)
            .rotationEffect(.degrees(swung ? spec.angle : -spec.angle))
            .animation(isJiggling
                       ? .easeInOut(duration: spec.period).repeatForever(autoreverses: true)
                         .delay(spec.phase)
                       : nil,
                       value: swung)
            .onChange(of: isJiggling, initial: true) { _, on in
                // Поворот ставится в конечное положение один раз: дальше его
                // гоняет туда-обратно `repeatForever`. Выключение возвращает
                // клетку ровно, без анимации.
                if on {
                    swung = true
                } else {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { swung = false }
                }
            }
    }

    @ViewBuilder
    private var cell: some View {
        switch look {
        case .ship:
            BoardCell(.ship, size: size)
        case .denied, .overlap(.replace):
            BoardCell(.shipDenied, size: size)
        case .overlap(.frame):
            RoundedRectangle(cornerRadius: Geometry.cellRadius(for: size), style: .continuous)
                .strokeBorder(LinearGradient.hullDenied,
                              lineWidth: size * ShipOverlapStyle.frameRatio)
        case .overlap(.inset):
            BoardCell(.shipDenied, size: size * ShipOverlapStyle.insetRatio)
        }
    }
}

// MARK: - Превью

private struct ArrangementDemo: View {
    @State private var editor: FleetEditor
    let backTitle: LocalizedStringKey

    init(editing: Bool = false, conflict: Bool = false, backTitle: LocalizedStringKey = "Level") {
        var editor = FleetEditor(ships: FleetLayout.canonicalLayout())
        if editing { editor.beginEditing() }
        if conflict {
            // Двухпалубный переставлен вплотную к четырёхпалубному: ровно тот
            // случай, который дизайн красит розовым.
            editor.beginEditing()
            let id = editor.ships.first { $0.length == 2 }!.id
            editor.move(id, to: Coordinate(row: 2, column: 2))
        }
        _editor = State(initialValue: editor)
        self.backTitle = backTitle
    }

    var body: some View {
        ZStack {
            SeaBackground()
            ArrangementScreen(editor: $editor, backTitle: backTitle)
        }
    }
}

#Preview("Расстановка · готово") {
    ArrangementDemo()
        .preferredColorScheme(.dark)
}

#Preview("Расстановка · изменение") {
    ArrangementDemo(editing: true)
        .preferredColorScheme(.dark)
}

#Preview("Расстановка · запрет") {
    ArrangementDemo(conflict: true)
        .preferredColorScheme(.dark)
}

/// Выбор заказчика (05.10): как рисовать клетку, легшую на чужой корабль.
/// Слева корабль под пальцем, справа — тот же, отпущенный. Трёхпалубный
/// наехал на четырёхпалубный двумя клетками, третья — в кольце соседа.
private struct OverlapGallery: View {
    let style: ShipOverlapStyle
    let title: String

    private static func editor(held: Bool) -> FleetEditor {
        var editor = FleetEditor(ships: FleetLayout.canonicalLayout())
        editor.beginEditing()
        let id = editor.ships.first { $0.length == 3 }!.id
        editor.beginDragging(id)
        editor.dragBy(columns: -3, rows: 0)
        if !held { editor.endDragging() }
        return editor
    }

    var body: some View {
        let metrics = BoardMetrics(cell: Geometry.Cell.iPhone)
        ZStack {
            SeaBackground()
            VStack(spacing: 16) {
                Text(verbatim: title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.inkPrimary)
                HStack(spacing: 28) {
                    ForEach([true, false], id: \.self) { held in
                        VStack(spacing: 8) {
                            EditableFleetBoard(editor: .constant(Self.editor(held: held)),
                                               metrics: metrics, overlapStyle: style)
                            Text(verbatim: held ? "under the finger" : "released")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.inkSecondary)
                        }
                    }
                }
            }
        }
    }
}

#Preview("Пересечение · замещение", traits: .fixedLayout(width: 800, height: 470)) {
    OverlapGallery(style: .replace, title: "A · replace")
        .preferredColorScheme(.dark)
}

#Preview("Пересечение · рамка", traits: .fixedLayout(width: 800, height: 470)) {
    OverlapGallery(style: .frame, title: "B · frame")
        .preferredColorScheme(.dark)
}

#Preview("Пересечение · вложение", traits: .fixedLayout(width: 800, height: 470)) {
    OverlapGallery(style: .inset, title: "C · inset")
        .preferredColorScheme(.dark)
}

#Preview("Пересечение · светлая", traits: .fixedLayout(width: 800, height: 470)) {
    OverlapGallery(style: .current, title: "current · light")
        .preferredColorScheme(.light)
}

#Preview("Расстановка · светлая") {
    ArrangementDemo(editing: true)
        .preferredColorScheme(.light)
}
