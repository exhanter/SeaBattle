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
    /// Подсказка под заголовком: чем экран сейчас занят.
    static let hintSize: CGFloat = 12.5
    static let hintLineSpacing: CGFloat = 12.5 * 0.4
    /// Между заголовком и полем.
    static let boardGap: CGFloat = 18
    /// Строка ошибки под полем.
    static let warningSize: CGFloat = 13.5
    static let warningGap: CGFloat = 8
    /// Полупрозрачность корабля в руке (спека 4.4). Это непрозрачность **всего
    /// элемента** как состояния, поэтому правило про альфу в цвете не задето.
    static let draggedOpacity: Double = 0.62
}

// MARK: - Экран

struct ArrangementScreen: View {

    @Binding var editor: FleetEditor
    /// Куда ведёт строка возврата: на экран уровня, если он показывался, иначе
    /// в меню (спека 3.1). Подпись меняется вместе с этим.
    let backTitle: LocalizedStringKey
    var onStart: () -> Void = {}
    var onBack: () -> Void = {}
    var onMenu: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let metrics = BoardMetrics(cell: Geometry.SizeClass.forWidth(proxy.size.width).cell)

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: ArrangementMetrics.warningGap) {
                        board(metrics)
                        warning
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, ArrangementMetrics.boardGap)
                }
                .scrollBounceBehavior(.basedOnSize)

                actions
            }
        }
    }

    // MARK: Заголовок и подсказка

    private var header: some View {
        VStack(alignment: .leading, spacing: Geometry.Nav.titleGap) {
            ScreenTitle(title: editor.isEditing ? "Change the layout" : "Your fleet",
                        back: backTitle, onBack: onBack)

            // Подсказка живёт здесь, а не внутри `ScreenTitle`: у компонента из
            // спеки 2.11 слота под неё нет, а в макетах расстановки заголовок
            // был панелью с подзаголовком. Вопрос В9 дизайну; переносится
            // внутрь компонента за десять минут, если ответ будет такой.
            Text(hint)
                .font(.system(size: ArrangementMetrics.hintSize))
                .foregroundStyle(Color.inkSecondary)
                .lineSpacing(ArrangementMetrics.hintLineSpacing)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Geometry.Nav.titleInset)
        }
        .padding(.top, NavMetrics.titleTopBelowSafeArea)
    }

    /// Подсказка говорит, что делать, и **не повторяет ошибку**: про ошибку есть
    /// строка под полем. В макете шапка меняла и заголовок, и подзаголовок на
    /// текст ошибки, но здесь заголовок занят фазой, и от подмены подсказки
    /// одно и то же оказывалось написано дважды — над полем и под ним.
    private var hint: LocalizedStringKey {
        editor.isEditing ? "Drag a ship to move it · tap to turn it"
                         : "The ships are placed for you"
    }

    // MARK: Поле

    private func board(_ m: BoardMetrics) -> some View {
        BoardView(cells: [BoardCellState](repeating: .water, count: 100),
                  role: .you, metrics: m)
            // Корабли лежат **поверх** сетки, а не внутри неё: их надо тянуть
            // целиком, а сетка — это сто отдельных клеток.
            .overlay(alignment: .topLeading) {
                ships(m)
                    .frame(width: m.gridSide, height: m.gridSide, alignment: .topLeading)
                    .offset(x: m.inset, y: m.inset)
            }
            .frame(width: m.totalSize.width, height: m.totalSize.height)
    }

    private func ships(_ m: BoardMetrics) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(editor.ships) { ship in
                shipView(ship, m)
            }
        }
    }

    private func shipView(_ ship: ShipPlacement, _ m: BoardMetrics) -> some View {
        let isDragged = editor.draggingID == ship.id
        let isDenied = editor.conflicts.contains(ship.id)
        let origin = m.cellOrigin(ship.origin)
        let size = m.shipSize(length: ship.length, orientation: ship.orientation)

        return ShipCells(ship: ship, metrics: m,
                         isDenied: isDenied,
                         isJiggling: editor.isEditing && !isDragged && !reduceMotion)
            .frame(width: size.width, height: size.height)
            .opacity(isDragged ? ArrangementMetrics.draggedOpacity : 1)
            .offset(x: origin.x, y: origin.y)
            .gesture(dragGesture(ship, m), isEnabled: editor.isEditing)
            .onTapGesture { editor.rotate(ship.id) }
            .accessibilityElement()
            .accessibilityLabel(Text("\(ship.length)-cell ship"))
            .accessibilityValue(isDenied ? Text("cannot be placed here") : Text(""))
    }

    /// Смещение считается в **клетках**, а не в точках: между клетками корабль
    /// стоять не может, и плавное движение только обманывало бы. За какую
    /// клетку взяли, значения не имеет — корабль смещается на столько же
    /// клеток, на сколько ушёл палец, поэтому взятая клетка сама остаётся под
    /// ним.
    private func dragGesture(_ ship: ShipPlacement, _ m: BoardMetrics) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if editor.draggingID != ship.id { editor.beginDragging(ship.id) }
                editor.dragBy(columns: Int((value.translation.width / m.step).rounded()),
                              rows: Int((value.translation.height / m.step).rounded()))
            }
            .onEnded { _ in editor.endDragging() }
    }

    // MARK: Строка ошибки

    @ViewBuilder
    private var warning: some View {
        if editor.hasConflicts {
            // Спека 4.4: одна строка под полем. Капсулы с красной обводкой из
            // макетов здесь нет — цвета `#ff5212` в каталоге не существует, а
            // выдумывать его в коде запрещает правило 8. Тон взят из
            // `Chrome/Fire` — единственного токена тревоги в системе.
            Text("A one-cell gap is needed")
                .font(.system(size: ArrangementMetrics.warningSize, weight: .semibold,
                              design: .rounded))
                .foregroundStyle(Color.fire)
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
                .secondaryButton()

                if !editor.isEditing {
                    Button {
                        editor.beginEditing()
                    } label: {
                        Label("Change", systemImage: "hand.draw")
                    }
                    .secondaryButton()
                }
            }
            .disabled(!editor.actionsEnabled)
            .opacity(editor.actionsEnabled ? 1 : ControlMetrics.Button.disabledOpacity)

            Button {
                if editor.isEditing {
                    editor.finishEditing()
                } else {
                    onStart()
                }
            } label: {
                Text(editor.isEditing ? "Done" : "Start")
            }
            .primaryButton(enabled: editor.canFinish && editor.actionsEnabled)
        }
    }
}

// MARK: - Корабль как набор клеток

/// Корабль — **набор клеток**, а не цельный корпус: цельный вводил в
/// заблуждение (решение тура 6). Дрожит каждая клетка отдельно.
private struct ShipCells: View {
    let ship: ShipPlacement
    let metrics: BoardMetrics
    let isDenied: Bool
    let isJiggling: Bool

    var body: some View {
        let layout = ship.orientation == .horizontal
            ? AnyLayout(HStackLayout(spacing: metrics.gap))
            : AnyLayout(VStackLayout(spacing: metrics.gap))

        return layout {
            ForEach(ship.cells, id: \.self) { cell in
                JigglingCell(state: isDenied ? .shipDenied : .ship,
                             size: metrics.cell,
                             spec: .forCell(cell),
                             isJiggling: isJiggling)
            }
        }
    }
}

/// Одна клетка корабля со своим дрожанием. Отдельным типом, потому что нужен
/// собственный `@State` на клетку: без него все клетки качались бы в ногу.
private struct JigglingCell: View {
    let state: BoardCellState
    let size: CGFloat
    let spec: JiggleSpec
    let isJiggling: Bool

    @State private var swung = false

    var body: some View {
        BoardCell(state, size: size)
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

#Preview("Расстановка · светлая") {
    ArrangementDemo(editing: true)
        .preferredColorScheme(.light)
}
