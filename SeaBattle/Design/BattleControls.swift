//
//  BattleControls.swift
//  Sea Battle — компоненты боя (R2.3)
//
//  Спека 2.5, 2.7–2.9; числа из кадров `scorePanel2`, `segSwitch`, `smallSeg`,
//  `screen16Battle`, `screen4MyBoard` и `screenSmallBattle` — у каждого экрана
//  два кадра, 393 и 375, и числа на них разные по всем величинам.
//
//  Верхняя панель **показывает и не нажимается** (правило 5): всё нажимаемое —
//  внизу, в `BottomStack`.
//

import SwiftUI

// MARK: - Числа

/// Размеры боевых компонентов по двум размерам iPhone. В пакете их нет —
/// взяты из кадров, поэтому лежат здесь, а не в `DesignTokens.swift`.
struct BattleMetrics: Equatable, Sendable {
    // Панель счёта
    let scoreRadius: CGFloat
    let scorePaddingV: CGFloat
    let scorePaddingH: CGFloat
    let scoreInset: CGFloat
    let sideLabel: CGFloat
    let sideNumber: CGFloat
    let sideGap: CGFloat
    let dot: CGFloat
    let statusText: CGFloat
    let statusPaddingV: CGFloat
    let statusPaddingH: CGFloat
    let balanceText: CGFloat
    // Подпись поля
    let caption: CGFloat
    // Переключатель полей
    let switchRadius: CGFloat
    let segmentRadius: CGFloat
    let segmentText: CGFloat
    // Подсказка
    let hintRadius: CGFloat
    let hintPadding: CGFloat
    let hintGap: CGFloat
    let hintIcon: CGFloat
    let hintText: CGFloat
    // Точки флота
    var dotGap: CGFloat = 3

    static let regular = BattleMetrics(
        scoreRadius: 22, scorePaddingV: 11, scorePaddingH: 15, scoreInset: 12,
        sideLabel: 11, sideNumber: 20, sideGap: 5, dot: 7,
        statusText: 12, statusPaddingV: 5, statusPaddingH: 12, balanceText: 13,
        caption: 15,
        switchRadius: 18, segmentRadius: 14, segmentText: 13,
        hintRadius: 18, hintPadding: 14, hintGap: 7, hintIcon: 21, hintText: 12.5)

    static let compact = BattleMetrics(
        scoreRadius: 18, scorePaddingV: 9, scorePaddingH: 13, scoreInset: 10,
        sideLabel: 10, sideNumber: 17, sideGap: 4, dot: 6,
        statusText: 11, statusPaddingV: 4, statusPaddingH: 10, balanceText: 12,
        caption: 13.5,
        switchRadius: 16, segmentRadius: 12, segmentText: 12.5,
        hintRadius: 16, hintPadding: 11, hintGap: 6, hintIcon: 19, hintText: 11)

    /// iPad, обе ориентации — кадр `score11` (тур 11.2). Номера хода в
    /// центральном блоке нет (правило 9), баланс — со словом «баллов».
    /// Числа переключателя и подсказки не используются: на iPad их нет,
    /// подсказка — отдельная плашка `PadHintButton`.
    static let pad = BattleMetrics(
        scoreRadius: 22, scorePaddingV: 12, scorePaddingH: 18, scoreInset: 0,
        sideLabel: 12, sideNumber: 22, sideGap: 6, dot: 8,
        statusText: 13, statusPaddingV: 6, statusPaddingH: 14, balanceText: 12,
        caption: 20,
        switchRadius: 18, segmentRadius: 14, segmentText: 13,
        hintRadius: 22, hintPadding: 22, hintGap: 12, hintIcon: 24, hintText: 11,
        dotGap: 4)

    static func forSize(_ size: Geometry.SizeClass) -> BattleMetrics {
        size.isCompact ? .compact : .regular
    }

    /// Точек во флоте — по кораблю на точку.
    static let fleetDots = FleetLayout.shipCount
}

// MARK: - Панель счёта

/// Спека 2.5. Три блока: ваш флот, статус хода с балансом, флот соперника.
/// Боковые колонки **равной ширины**: иначе длинный статус («Ход соперника»
/// на нидерландском) сдвигает счёт, и цифры прыгают от хода к ходу.
struct ScorePanel: View {
    /// Сколько ваших кораблей потоплено.
    let yourLosses: Int
    /// Сколько кораблей соперника потопили вы.
    let foeLosses: Int
    let isYourTurn: Bool
    let balance: Int
    var size: Geometry.SizeClass = .regular
    /// iPad: свои числа (`BattleMetrics.pad`) и слово «баллов» у баланса.
    var isPad = false
    /// Блок своего флота справа — на горизонтальном iPad, когда своё поле
    /// стоит справа (4.11): блоки счёта переезжают вместе с полями.
    var yoursOnTrailing = false
    /// iPad, стол до старта (4.4 после раунда 7): та же панель той же высоты,
    /// в центре капсула «Расстановка» на стекле, без латуни.
    var isArranging = false
    /// iPad: уровень компьютера капсулой во второй строке центра, слева от
    /// баланса (4.5 после раунда 7). В других режимах — `nil`, только баланс.
    var level: AppState.DifficultyLevel?
    /// Статус вместо «Ваш ход» / «Ход соперника» — игра на бумаге пишет здесь,
    /// что сказать: «Скажите: Д7» (4.6). Правило 3: режимы отличаются
    /// содержимым шапки, а не её устройством.
    var status: Text?

    private var m: BattleMetrics { isPad ? .pad : .forSize(size) }

    var body: some View {
        HStack(spacing: isPad ? 18 : 14) {
            if yoursOnTrailing {
                side("Opponent", color: .roleFoe, sunk: foeLosses, alignment: .leading)
            } else {
                side("Your fleet", color: .roleYou, sunk: yourLosses, alignment: .leading)
            }
            center
                .fixedSize()
            if yoursOnTrailing {
                side("Your fleet", color: .roleYou, sunk: yourLosses, alignment: .trailing)
            } else {
                side("Opponent", color: .roleFoe, sunk: foeLosses, alignment: .trailing)
            }
        }
        .padding(.vertical, m.scorePaddingV)
        .padding(.horizontal, m.scorePaddingH)
        .glassPanel(.g2, radius: m.scoreRadius, wood: .bottom)
        .padding(.horizontal, m.scoreInset)
        // Не нажимается — поэтому и для VoiceOver это текст, а не кнопки.
        .accessibilityElement(children: .combine)
    }

    private func side(_ label: LocalizedStringKey, color: Color, sunk: Int,
                      alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: m.sideGap) {
            Text(label)
                .font(.system(size: m.sideLabel, weight: .semibold))
                .foregroundStyle(Color.inkSecondary)
                .lineLimit(1)
            Text(verbatim: "\(sunk) / \(BattleMetrics.fleetDots)")
                .font(.system(size: m.sideNumber, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
            FleetDots(sunk: sunk, color: color, dot: m.dot, gap: m.dotGap)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    private var center: some View {
        VStack(spacing: m.sideGap) {
            (status ?? Text(isArranging ? "Arrangement" : isYourTurn ? "Your turn" : "Opponent's turn"))
                .font(.system(size: m.statusText, weight: .bold))
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
                .padding(.vertical, m.statusPaddingV)
                .padding(.horizontal, m.statusPaddingH)
                .background {
                    Capsule(style: .continuous)
                        .fill(isArranging ? Color.glassFill : Color.roleYouSoft)
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(isArranging ? Color.glassStroke : Color.roleYou,
                                              lineWidth: 1)
                        }
                }
            HStack(spacing: 10) {
                if isPad, let level {
                    LevelChip(level: level, size: .regular)
                }
                balanceView
            }
        }
    }

    private var balanceView: some View {
        Group {
            // На iPhone у баланса только значок и число: слово «баллов» не
            // вмещается (2.5). На iPad — со словом (лог дизайна, «Баланс баллов»).
            HStack(spacing: isPad ? 5 : 4) {
                Image(systemName: PointsSymbol.name)
                    .font(.system(size: symbolFontSize(inBox: m.balanceText + 3)))
                Group {
                    if isPad {
                        Text("\(balance) points")
                    } else {
                        Text(verbatim: "\(balance)")
                    }
                }
                .font(.system(size: m.balanceText, weight: .bold, design: .rounded))
                .monospacedDigit()
            }
            .foregroundStyle(Color.inkPrimary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(balance) points"))
        }
    }
}

/// Десять точек флота: закрашенные — потопленные корабли.
struct FleetDots: View {
    let sunk: Int
    let color: Color
    let dot: CGFloat
    var gap: CGFloat = 3

    var body: some View {
        HStack(spacing: gap) {
            ForEach(0..<BattleMetrics.fleetDots, id: \.self) { index in
                Circle()
                    .strokeBorder(color, lineWidth: 1)
                    .background { if index < sunk { Circle().fill(color) } }
                    .frame(width: dot, height: dot)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Переключатель полей

/// Спека 2.7. Только iPhone, только в бою. Растягивается на всю строку,
/// текст не сжимается. Видимый сегмент 44 pt, обойма 3 pt — всего 50;
/// зона касания равна сегменту.
///
/// Порядок и подписи — по кадрам `segSwitch` / `smallSeg` (своё поле слева,
/// «Противник» справа), а не по перечислению в тексте 2.7: кадры позже.
struct FieldSwitch: View {
    let selection: Side
    var size: Geometry.SizeClass = .regular
    var onSelect: (Side) -> Void = { _ in }

    private var m: BattleMetrics { .forSize(size) }

    var body: some View {
        HStack(spacing: Geometry.Segment.trackInset) {
            segment(.you, title: "My board")
            segment(.foe, title: "Opponent")
        }
        .padding(Geometry.Segment.trackInset)
        .glassPanel(.g2, radius: m.switchRadius)
    }

    private func segment(_ side: Side, title: LocalizedStringKey) -> some View {
        let isSelected = side == selection
        return Button {
            onSelect(side)
        } label: {
            Text(title)
                .font(.system(size: m.segmentText, weight: .semibold))
                .foregroundStyle(isSelected ? Color.inkOnBrass : Color.inkPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: Geometry.Segment.height)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: m.segmentRadius, style: .continuous)
                            .fill(Color.roleYou)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(side == .you ? "fieldSwitchYou" : "fieldSwitchFoe")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Подсказка

/// Спека 2.9. Цена хода написана на кнопке; на ходе соперника кнопка погашена.
/// Стоит в дальнем от руки углу — осознанный тормоз перед платным действием.
///
/// Имя не `HintButton`: оно занято старой кнопкой, на которой держится iPad до
/// R2.6.
struct BattleHintButton: View {
    let cost: Int
    let isEnabled: Bool
    var size: Geometry.SizeClass = .regular
    var action: () -> Void = {}

    private var m: BattleMetrics { .forSize(size) }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: m.hintRadius, style: .continuous)
        Button(action: action) {
            HStack(spacing: m.hintGap) {
                Image(systemName: "lightbulb.max")
                    .font(.system(size: symbolFontSize(inBox: m.hintIcon)))
                    .foregroundStyle(Color.inkPrimary)
                Text(verbatim: "−\(cost)")
                    .font(.system(size: m.hintText, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.roleYou)
            }
            .padding(.horizontal, m.hintPadding)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassPanel(.g2, radius: m.hintRadius)
        .overlay { shape.strokeBorder(Color.roleYou, lineWidth: 1).allowsHitTesting(false) }
        // Погашенная кнопка гаснет целиком, как главная и второстепенная.
        .opacity(isEnabled ? 1 : ControlMetrics.Button.disabledOpacity)
        .disabled(!isEnabled)
        .accessibilityLabel(Text("Hint, \(cost) points"))
        .accessibilityIdentifier("hintButton")
    }
}

// MARK: - Лента выстрелов

/// Спека 2.8. Капсулы без подложки под лентой, последняя выделена
/// `Role/YouSoft`, старые гаснут маской по самим капсулам. Последний выстрел
/// справа, при открытии лента прижата к концу, промотка свайпом.
struct ShotFeed: View {
    let title: LocalizedStringKey
    let entries: [ShotFeedEntry]
    var alphabet: BoardAlphabet = .current

    /// Высота панели постоянна — пустая лента и полная занимают одно место,
    /// поэтому поле над ней не прыгает, когда компьютер начинает стрелять.
    static let height: CGFloat = 72
    static let fadeWidth: CGFloat = 34

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10.5, weight: .bold))
                .tracking(1.05)
                .textCase(.uppercase)
                .foregroundStyle(Color.inkSecondary)

            if entries.isEmpty {
                Text("No shots yet")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.inkTertiary)
                    .frame(height: 24)
            } else {
                chips
            }
        }
        .padding(.top, 11)
        .padding(.bottom, 12)
        .padding(.leading, 14)
        .frame(maxWidth: .infinity, minHeight: Self.height, maxHeight: Self.height,
               alignment: .topLeading)
        .glassPanel(.g2, radius: 20)
        .accessibilityElement(children: .combine)
    }

    /// Reduce Motion: перемещение становится прозрачностью (спека 5).
    private var chipArrival: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 {
                        Text(verbatim: "→")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.inkTertiary)
                            .accessibilityHidden(true)
                    }
                    ShotChip(entry: entry, isLast: index == entries.count - 1,
                             alphabet: alphabet)
                        .transition(chipArrival)
                }
            }
            .padding(.trailing, 14)
            // Капсула въезжает с края, соседние сдвигаются (14c, 220 мс).
            .animation(.easeOut(duration: Motion.scaled(Motion.feedChip, reduceMotion: reduceMotion)),
                       value: entries)
        }
        // При открытии прижата к концу: последний выстрел — самый важный.
        .defaultScrollAnchor(.trailing)
        // Старые выстрелы гаснут маской по самим капсулам, а не цветной
        // заливкой поверх: подложки под лентой нет, и заливке не с чем
        // совпасть по цвету.
        .mask {
            HStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                    .frame(width: Self.fadeWidth)
                Color.black
            }
        }
    }
}

/// Одна капсула ленты: клетка и чем кончился выстрел.
struct ShotChip: View {
    let entry: ShotFeedEntry
    let isLast: Bool
    var alphabet: BoardAlphabet = .current
    /// iPad: капсула столбика `ShotColumn` — кегли 14 / 13, поля 6 / 12
    /// (кадр `shotColumn`).
    var isLarge = false

    var body: some View {
        let color: Color = entry.outcome.isDamage ? .roleYou : .inkSecondary
        HStack(alignment: .firstTextBaseline, spacing: isLarge ? 7 : 5) {
            Text(verbatim: Self.label(entry.coordinate, alphabet: alphabet))
                .font(.system(size: isLarge ? 14 : 12.5, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.inkPrimary)
            Text(Self.outcomeTitle(entry.outcome))
                .font(.system(size: isLarge ? 13 : 12, weight: .semibold))
                .foregroundStyle(color)
        }
        .lineLimit(1)
        .padding(.vertical, isLarge ? 6 : 4)
        .padding(.horizontal, isLarge ? 12 : 10)
        .background {
            Capsule(style: .continuous)
                .fill(isLast ? Color.roleYouSoft : Color.clear)
                .overlay { Capsule(style: .continuous).strokeBorder(color, lineWidth: 1) }
        }
    }

    /// «Е4»: буква столбца по языку интерфейса и номер строки.
    static func label(_ coordinate: Coordinate, alphabet: BoardAlphabet) -> String {
        let letters = alphabet.letters
        let index = coordinate.column - 1
        let letter = letters.indices.contains(index) ? letters[index] : "?"
        return "\(letter)\(coordinate.row)"
    }

    static func outcomeTitle(_ outcome: FeedOutcome) -> LocalizedStringKey {
        switch outcome {
        case .miss: "miss"
        case .hit: "hit"
        case .sunk: "sunk"
        case .repeatHit: "repeat hit"
        case .repeatMiss: "repeat shot"
        }
    }
}

// MARK: - Превью

private struct BattleControlsDemo: View {
    var body: some View {
        ZStack {
            SeaBackground()
            VStack(spacing: 24) {
                ScorePanel(yourLosses: 4, foeLosses: 2, isYourTurn: true, balance: 240)
                ScorePanel(yourLosses: 1, foeLosses: 7, isYourTurn: false, balance: 12,
                           size: .compact)
                ShotFeed(title: "Shots at you this round",
                         entries: [.init(id: 0, coordinate: .init(row: 3, column: 7), outcome: .miss),
                                   .init(id: 1, coordinate: .init(row: 1, column: 1), outcome: .miss),
                                   .init(id: 2, coordinate: .init(row: 9, column: 10), outcome: .repeatMiss),
                                   .init(id: 3, coordinate: .init(row: 7, column: 3), outcome: .sunk),
                                   .init(id: 4, coordinate: .init(row: 4, column: 6), outcome: .hit)],
                         alphabet: .cyrillic)
                    .padding(.horizontal, 12)
                ShotFeed(title: "Shots at you this round", entries: [])
                    .padding(.horizontal, 12)
                HStack(spacing: 8) {
                    FieldSwitch(selection: .foe)
                    BattleHintButton(cost: 10, isEnabled: true)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                HStack(spacing: 8) {
                    FieldSwitch(selection: .you, size: .compact)
                    BattleHintButton(cost: 6, isEnabled: false, size: .compact)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
            }
        }
    }
}

#Preview("Бой · компоненты · тёмная") {
    BattleControlsDemo()
        .preferredColorScheme(.dark)
}

#Preview("Бой · компоненты · светлая") {
    BattleControlsDemo()
        .preferredColorScheme(.light)
}
