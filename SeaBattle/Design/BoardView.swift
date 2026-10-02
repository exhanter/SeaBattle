//
//  BoardView.swift
//  Sea Battle — поле 10 × 10
//
//  Обвязка из спеки 2.4. Два варианта:
//
//  - **B1** — подложка в цвете роли: тёплая у своего поля, холодная у чужого.
//    Применяется везде, кроме игры на бумаге.
//  - **B2** — та же подложка плюс координаты по краям. Только «игра на бумаге»:
//    там игрок называет клетку вслух, и без букв с цифрами это невозможно.
//
//  Рамка активного поля — та, по которой **сейчас стреляют**: на вашем ходу
//  светится поле противника, на ходу соперника — ваше. Не пульсирует.
//
//  Событие клетки (R2.4, спека 5) — всплеск, смена состояния и подсветка
//  контура — приходит параметром `event`: поле рисует ровно одно, последнее.
//

import SwiftUI

// MARK: - Геометрия поля

/// Размеры поля считаются от размера клетки, а не задаются по месту: иначе
/// подложка, рамка и координаты разъедутся между iPhone, iPad и расстановкой.
/// Вынесено в отдельный тип, чтобы проверять арифметику тестом.
struct BoardMetrics: Equatable, Sendable {
    let cell: CGFloat
    let gap: CGFloat
    let showsCoordinates: Bool

    static let columns = 10

    init(cell: CGFloat, gap: CGFloat = Geometry.Cell.gapPhone, coordinates: Bool = false) {
        self.cell = cell
        self.gap = gap
        self.showsCoordinates = coordinates
    }

    /// Отступ подложки вокруг клеток.
    var inset: CGFloat { Geometry.boardInset }

    /// Радиус подложки = радиус клетки + отступ. Так скругление подложки
    /// продолжает скругление угловых клеток, а не спорит с ним.
    var radius: CGFloat { Geometry.cellRadius(for: cell) + inset }

    /// Сторона сетки без подложки.
    var gridSide: CGFloat { cell * CGFloat(Self.columns) + gap * CGFloat(Self.columns - 1) }

    /// Сторона подложки.
    var boardSide: CGFloat { gridSide + inset * 2 }

    /// Ширина колонки цифр слева (0, если координат нет).
    var digitsWidth: CGFloat { showsCoordinates ? 16 : 0 }
    /// Высота строки букв сверху.
    var lettersHeight: CGFloat { showsCoordinates ? 14 : 0 }
    /// Зазор между осью координат и подложкой.
    var axisGap: CGFloat { showsCoordinates ? 3 : 0 }

    /// Полный размер вместе с координатами — то, что занимает поле на экране.
    var totalSize: CGSize {
        CGSize(width: boardSide + digitsWidth + axisGap,
               height: boardSide + lettersHeight + axisGap)
    }

    // MARK: Место клетки в сетке

    /// Шаг сетки: клетка плюс зазор.
    var step: CGFloat { cell + gap }

    /// Левый верхний угол клетки **внутри сетки** (без подложки и координат).
    /// Координата 1-based, как в ядре правил: путаница с нулём здесь стоит
    /// сдвига поля на клетку, а это видно только на устройстве.
    func cellOrigin(_ coordinate: Coordinate) -> CGPoint {
        CGPoint(x: CGFloat(coordinate.column - 1) * step,
                y: CGFloat(coordinate.row - 1) * step)
    }

    /// Размер корабля в точках: клетки плюс зазоры между ними.
    func shipSize(length: Int, orientation: Orientation) -> CGSize {
        let long = cell * CGFloat(length) + gap * CGFloat(length - 1)
        return orientation == .horizontal ? CGSize(width: long, height: cell)
                                          : CGSize(width: cell, height: long)
    }

    /// В какую клетку попала точка внутри сетки. Возвращает `nil` за пределами
    /// поля — палец легко уходит с сетки, и молча зажимать его в край нельзя:
    /// корабль встал бы не туда, куда его отпустили.
    func cell(at point: CGPoint) -> Coordinate? {
        let column = Int(floor(point.x / step)) + 1
        let row = Int(floor(point.y / step)) + 1
        let coordinate = Coordinate(row: row, column: column)
        return coordinate.isOnBoard ? coordinate : nil
    }
}

// MARK: - Буквы поля

/// Буквы столбцов. В русской раскладке ряд без Ё и Й — так в макете и так
/// привычно игрокам; в латинской A–J. Выбор по языку, а не по стране.
enum BoardAlphabet: Sendable {
    case cyrillic
    case latin

    static let cyrillicLetters = ["А", "Б", "В", "Г", "Д", "Е", "Ж", "З", "И", "К"]
    static let latinLetters = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]

    var letters: [String] {
        switch self {
        case .cyrillic: Self.cyrillicLetters
        case .latin: Self.latinLetters
        }
    }

    /// Русский интерфейс получает русские буквы, английский и нидерландский —
    /// латинские.
    static func forLanguage(_ code: String?) -> BoardAlphabet {
        code?.hasPrefix("ru") == true ? .cyrillic : .latin
    }

    static var current: BoardAlphabet {
        forLanguage(Locale.current.language.languageCode?.identifier)
    }
}

// MARK: - Метка клетки

/// Что лежит поверх клетки своим слоем. Для отрисовки поля не нужна — только
/// для значения клетки в VoiceOver.
enum BoardMark: Equatable, Sendable {
    /// Клетка, которую подсветила подсказка.
    case hint
    /// Прицел: выстрел назван и ждёт подтверждения или ответа. В игре на
    /// бумаге на своём поле — клетка, которую назвал соперник.
    case aim

    var accessibilityTitle: LocalizedStringKey {
        switch self {
        case .hint: "hint"
        case .aim: "aimed"
        }
    }
}

// MARK: - Поле

struct BoardView: View {

    /// Ровно 100 клеток, по строкам сверху вниз.
    let cells: [BoardCellState]
    /// Чьё поле: от этого зависит только цвет подложки.
    let role: Side
    let metrics: BoardMetrics
    /// Поле, по которому сейчас стреляют, — у него горит рамка. Ровно одно
    /// поле на экране может быть активным, но следит за этим вызывающий.
    var isActive: Bool = false
    /// Названная клетка: её буква и цифра подсвечиваются латунью.
    var aim: (column: Int, row: Int)?
    /// Последний выстрел по этому полю. Чужое событие сюда не передавать:
    /// цвет кольца закреплён за полем, а не за стрелявшим.
    var event: CellEvent?
    /// Метки поверх клеток — прицел и подсказка. Рисует их вызывающий своим
    /// слоем; сюда они приходят только ради VoiceOver: картинку поверх поля
    /// он не свяжет с клеткой, а значение клетки — свяжет.
    var marks: [Coordinate: BoardMark] = [:]
    var onTap: ((_ column: Int, _ row: Int) -> Void)?

    private var alphabet: BoardAlphabet = .current

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

    init(cells: [BoardCellState], role: Side, metrics: BoardMetrics,
         isActive: Bool = false, aim: (column: Int, row: Int)? = nil,
         alphabet: BoardAlphabet = .current,
         event: CellEvent? = nil,
         marks: [Coordinate: BoardMark] = [:],
         onTap: ((_ column: Int, _ row: Int) -> Void)? = nil) {
        self.cells = cells
        self.role = role
        self.metrics = metrics
        self.isActive = isActive
        self.aim = aim
        self.alphabet = alphabet
        self.event = event
        self.marks = marks
        self.onTap = onTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.axisGap) {
            if metrics.showsCoordinates { letters }
            HStack(alignment: .top, spacing: metrics.axisGap) {
                if metrics.showsCoordinates { digits }
                board
            }
        }
        // VoiceOver: поле — контейнер из ста клеток. Буквы и цифры по краям
        // скрыты: координата есть у каждой клетки, а лишние двадцать
        // элементов только удлиняют обход. Своего имени у контейнера нет —
        // поле называет подпись над ним (заголовок на каждом экране боя),
        // и имя звучало бы дважды подряд.
        .accessibilityElement(children: .contain)
        .onChange(of: event?.id, initial: true) { announce(event) }
    }

    // MARK: VoiceOver

    /// Старше этого событие уже не объявляется: на iPhone одно и то же поле
    /// показывает то своё, то чужое, и переключение полей меняет `event` на
    /// давний выстрел — его повторять не надо.
    static let announceWindow: TimeInterval = 1

    /// Исход выстрела вслух. Клетка меняет значение и без этого, но фокус
    /// VoiceOver стоит на ней не всегда, а выстрелы компьютера приходят на
    /// поле, которого игрок в этот момент не трогает.
    private func announce(_ event: CellEvent?) {
        guard let event, Date.now.timeIntervalSince(event.start) < Self.announceWindow else { return }
        let cell = ShotChip.label(event.target, alphabet: alphabet)
        let outcome = String(game: ShotChip.outcomeResource(event.outcome), locale: locale)
        let text = role == .you
            ? String(game: "Shot at you: \(cell), \(outcome)", locale: locale)
            : "\(cell), \(outcome)"
        var announcement = AttributedString(text)
        // Высокий приоритет: объявление не обрывается сменой фокуса, а
        // следующее встаёт в очередь — компьютер стреляет сериями.
        announcement.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(announcement).post()
    }

    /// «не обстреляна» или «не обстреляна, подсказка».
    private func accessibilityValue(row: Int, column: Int) -> Text {
        let state = Text(Self.accessibilityState(state(row: row, column: column), on: role))
        guard let mark = marks[Coordinate(row: row + 1, column: column + 1)] else { return state }
        return state + Text(verbatim: ", ") + Text(mark.accessibilityTitle)
    }

    /// Что VoiceOver говорит значением клетки. Вода на поле противника — это
    /// «не обстреляна»: что там на самом деле, игрок не знает.
    static func accessibilityState(_ state: BoardCellState, on role: Side) -> LocalizedStringKey {
        switch state {
        case .water: role == .foe ? "not shot" : "water"
        case .miss: "miss"
        case .ship: "ship"
        case .hit, .hitMine: "hit"
        case .sunk: "sunk"
        case .shipDenied: "cannot be placed here"
        }
    }

    // MARK: Подложка и сетка

    private var timing: CellEventTiming { CellEventTiming(reduceMotion: reduceMotion) }

    private var board: some View {
        grid
            .overlay(alignment: .topLeading) { splash }
            .padding(metrics.inset)
            .background {
                RoundedRectangle(cornerRadius: metrics.radius, style: .continuous)
                    .fill(role == .you ? Color.boardFillYou : Color.boardFillFoe)
            }
            .overlay {
                RoundedRectangle(cornerRadius: metrics.radius, style: .continuous)
                    .strokeBorder(role == .you ? Color.boardStrokeYou : Color.boardStrokeFoe,
                                  lineWidth: 1)
            }
            // Рамка активного поля рисуется поверх обвязки и **всегда латунная**:
            // она говорит «сюда стреляют сейчас», а не «чьё это поле».
            // Смена хода (14c): рамка гаснет за 160 мс, вторая разгорается за
            // 240 после паузы — на iPhone это одно показанное поле.
            .overlay {
                RoundedRectangle(cornerRadius: metrics.radius, style: .continuous)
                    .strokeBorder(Color.roleYou, lineWidth: 2.5)
                    .shadow(color: .roleYouSoft, radius: 13)
                    .opacity(isActive ? 1 : 0)
                    .animation(turnAnimation, value: isActive)
                    .allowsHitTesting(false)
            }
    }

    private var turnAnimation: Animation {
        let fade = Motion.scaled(Motion.turnFade, reduceMotion: reduceMotion)
        return isActive
            ? .easeInOut(duration: Motion.scaled(Motion.turnRaise, reduceMotion: reduceMotion)).delay(fade)
            : .easeInOut(duration: fade)
    }

    /// Кольца и подсветка у клетки выстрела — слоем поверх сетки: кольцо
    /// шире клетки и не должно обрезаться соседями.
    @ViewBuilder
    private var splash: some View {
        if let event {
            let origin = metrics.cellOrigin(event.target)
            CellSplash(event: event, cell: metrics.cell, timing: timing)
                .id(event.id)
                .offset(x: origin.x, y: origin.y)
        }
    }

    private var grid: some View {
        VStack(spacing: metrics.gap) {
            ForEach(0..<BoardMetrics.columns, id: \.self) { row in
                HStack(spacing: metrics.gap) {
                    ForEach(0..<BoardMetrics.columns, id: \.self) { column in
                        cell(row: row, column: column)
                            // Бьют по клетке в сетке, а не по отдельной кнопке,
                            // поэтому размер меньше 44 pt здесь допустим.
                            .contentShape(Rectangle())
                            .onTapGesture { onTap?(column, row) }
                            .accessibilityElement()
                            .accessibilityLabel(Text(verbatim: ShotChip.label(
                                Coordinate(row: row + 1, column: column + 1), alphabet: alphabet)))
                            .accessibilityValue(accessibilityValue(row: row, column: column))
                            // Касание по клетке SwiftUI сам выдаёт за кнопку —
                            // на поле, по которому не бьют, признак снимается.
                            .accessibilityAddTraits(onTap == nil ? [] : .isButton)
                            .accessibilityRemoveTraits(onTap == nil ? .isButton : [])
                            .accessibilityAction { onTap?(column, row) }
                    }
                }
            }
        }
    }

    /// Клетка, которую задел последний выстрел, растворяется из прежнего
    /// состояния; остальные рисуются как есть. Когда событие сменилось,
    /// прежние клетки сразу стоят в конечном состоянии — анимации не копятся.
    @ViewBuilder
    private func cell(row: Int, column: Int) -> some View {
        let now = state(row: row, column: column)
        if let event, let change = event.change(at: Coordinate(row: row + 1, column: column + 1)) {
            SwappingCell(from: .forDisplay(change.from, on: role), to: now, change: change,
                         start: event.start, size: metrics.cell, timing: timing)
                .id(event.id)
        } else {
            BoardCell(now, size: metrics.cell)
        }
    }

    private func state(row: Int, column: Int) -> BoardCellState {
        let index = row * BoardMetrics.columns + column
        return cells.indices.contains(index) ? cells[index] : .water
    }

    // MARK: Координаты

    private var letters: some View {
        HStack(spacing: metrics.gap) {
            ForEach(Array(alphabet.letters.enumerated()), id: \.offset) { index, letter in
                axisLabel(letter, highlighted: aim?.column == index)
                    .frame(width: metrics.cell, height: metrics.lettersHeight)
            }
        }
        .padding(.leading, metrics.digitsWidth + metrics.axisGap + metrics.inset)
        .accessibilityHidden(true)
    }

    private var digits: some View {
        VStack(spacing: metrics.gap) {
            ForEach(0..<BoardMetrics.columns, id: \.self) { index in
                axisLabel("\(index + 1)", highlighted: aim?.row == index)
                    .frame(width: metrics.digitsWidth, height: metrics.cell)
            }
        }
        .padding(.top, metrics.inset)
        .accessibilityHidden(true)
    }

    private func axisLabel(_ text: String, highlighted: Bool) -> some View {
        Text(text)
            .font(.system(size: 10, weight: highlighted ? .bold : .regular, design: .monospaced))
            .foregroundStyle(highlighted ? Color.roleYou : Color.inkSecondary)
            .monospacedDigit()
    }
}

// MARK: - Превью

private struct BoardDemo: View {
    let coordinates: Bool
    let role: Side

    var body: some View {
        ZStack {
            SeaBackground()
            BoardView(cells: Self.sample, role: role,
                      metrics: BoardMetrics(cell: coordinates ? Geometry.Cell.iPhoneCoords
                                                              : Geometry.Cell.iPhone,
                                            coordinates: coordinates),
                      isActive: role == .foe,
                      aim: coordinates ? (column: 4, row: 6) : nil,
                      alphabet: .cyrillic)
        }
    }

    /// Поле в середине партии: промахи, раненый корабль, потопленный и свои
    /// корабли — чтобы на одном снимке было видно всё, что рисует клетка.
    static let sample: [BoardCellState] = {
        var cells = [BoardCellState](repeating: .water, count: 100)
        for i in [3, 4, 5, 6] { cells[i] = .sunk }
        for i in [13, 27, 52, 58, 66, 81, 88, 92, 97] { cells[i] = .miss }
        for i in [31, 41] { cells[i] = .hit }
        for i in [15, 25, 35, 62, 63, 90] { cells[i] = .ship }
        cells[47] = .hitMine
        return cells
    }()
}

#Preview("Поле B1 · чужое, активное") {
    BoardDemo(coordinates: false, role: .foe)
        .preferredColorScheme(.dark)
}

#Preview("Поле B1 · своё") {
    BoardDemo(coordinates: false, role: .you)
        .preferredColorScheme(.dark)
}

#Preview("Поле B2 · координаты, игра на бумаге") {
    BoardDemo(coordinates: true, role: .foe)
        .preferredColorScheme(.dark)
}

#Preview("Поле B1 · светлая") {
    BoardDemo(coordinates: false, role: .foe)
        .preferredColorScheme(.light)
}
