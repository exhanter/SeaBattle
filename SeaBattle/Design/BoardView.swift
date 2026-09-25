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
    var onTap: ((_ column: Int, _ row: Int) -> Void)?

    private var alphabet: BoardAlphabet = .current

    init(cells: [BoardCellState], role: Side, metrics: BoardMetrics,
         isActive: Bool = false, aim: (column: Int, row: Int)? = nil,
         alphabet: BoardAlphabet = .current,
         onTap: ((_ column: Int, _ row: Int) -> Void)? = nil) {
        self.cells = cells
        self.role = role
        self.metrics = metrics
        self.isActive = isActive
        self.aim = aim
        self.alphabet = alphabet
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
    }

    // MARK: Подложка и сетка

    private var board: some View {
        grid
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
            .overlay {
                if isActive {
                    RoundedRectangle(cornerRadius: metrics.radius, style: .continuous)
                        .strokeBorder(Color.roleYou, lineWidth: 2.5)
                        .shadow(color: .roleYouSoft, radius: 13)
                }
            }
    }

    private var grid: some View {
        VStack(spacing: metrics.gap) {
            ForEach(0..<BoardMetrics.columns, id: \.self) { row in
                HStack(spacing: metrics.gap) {
                    ForEach(0..<BoardMetrics.columns, id: \.self) { column in
                        BoardCell(state(row: row, column: column), size: metrics.cell)
                            // Бьют по клетке в сетке, а не по отдельной кнопке,
                            // поэтому размер меньше 44 pt здесь допустим.
                            .contentShape(Rectangle())
                            .onTapGesture { onTap?(column, row) }
                    }
                }
            }
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
    }

    private var digits: some View {
        VStack(spacing: metrics.gap) {
            ForEach(0..<BoardMetrics.columns, id: \.self) { index in
                axisLabel("\(index + 1)", highlighted: aim?.row == index)
                    .frame(width: metrics.digitsWidth, height: metrics.cell)
            }
        }
        .padding(.top, metrics.inset)
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
