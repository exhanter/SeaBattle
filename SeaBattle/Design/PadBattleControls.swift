//
//  PadBattleControls.swift
//  Sea Battle — боевые компоненты iPad (R2.6)
//
//  Спека 2.8 и 2.9, кадры `hintPlate` и `shotColumn` (тур 11.2). На iPad оба
//  поля видны сразу, поэтому переключателя полей нет, а лента «По вам» стоит
//  столбиком у своего поля: сбоку от поля свободна высота, а не ширина.
//

import SwiftUI

// MARK: - Подсказка

/// Подсказка на iPad — плашка, а не капсула произвольной высоты (тур 11.1):
/// вертикально квадрат со стороной в ширину рельса (104 pt), горизонтально —
/// ровно по высоте нижней панели (68 pt) и в одних с ней линиях.
struct PadHintButton: View {
    let cost: Int
    let isEnabled: Bool
    /// Вертикальный iPad: квадрат 104 × 104, значок над подписью.
    let isTall: Bool
    var action: () -> Void = {}

    private var m: BattleMetrics { .pad }
    private var radius: CGFloat { isTall ? Geometry.Radius.panelLarge : m.hintRadius }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        Button(action: action) {
            let layout = isTall
                ? AnyLayout(VStackLayout(spacing: 8))
                : AnyLayout(HStackLayout(spacing: m.hintGap))
            layout {
                Image(systemName: "lightbulb.max")
                    .font(.system(size: symbolFontSize(inBox: m.hintIcon)))
                    .frame(height: m.hintIcon)
                    .foregroundStyle(Color.inkPrimary)
                VStack(alignment: isTall ? .center : .leading, spacing: 1) {
                    Text("Hint")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.inkPrimary)
                    Text(verbatim: "−\(cost)")
                        .font(.system(size: m.hintText, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.roleYou)
                }
                .lineLimit(1)
            }
            .padding(.horizontal, isTall ? 8 : m.hintPadding)
            .frame(width: isTall ? Geometry.Inset.railWidth : nil,
                   height: isTall ? Geometry.Inset.railWidth : Geometry.Inset.hintHeightLandscape)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassPanel(.g2, radius: radius)
        .overlay { shape.strokeBorder(Color.roleYou, lineWidth: 1).allowsHitTesting(false) }
        .opacity(isEnabled ? 1 : ControlMetrics.Button.disabledOpacity)
        .disabled(!isEnabled)
        .accessibilityLabel(Text("Hint, \(cost) points"))
        .accessibilityIdentifier("hintButton")
    }
}

// MARK: - Лента столбиком

/// Числа столбика — отдельно от вида: по ним стол считает место под ленту,
/// а статики `View` в Swift 6 привязаны к главному потоку.
enum ShotColumnMetrics {
    /// Высота строки капсулы и зазор — из кадра (33 и 8).
    static let rowHeight: CGFloat = 33
    static let rowGap: CGFloat = 8
    /// Маска гасит низ столбика: до 62 % высоты капсулы плотные.
    static let solidShare: CGFloat = 0.62
    /// Подпись «По вам» над капсулами.
    static let titleHeight: CGFloat = 14
    static let visible = 3

    /// Полная высота: подпись, зазор и окно на `visible` капсул.
    static var height: CGFloat {
        titleHeight + rowGap + CGFloat(visible) * rowHeight + CGFloat(visible - 1) * rowGap
    }
}

/// Лента «По вам» на iPad (2.8, лог дизайна «Лента выстрелов на iPad»):
/// **столбик без панели, только капсулы**, последний выстрел **сверху** на
/// подложке `Role/YouSoft`, старые уходят вниз под маску. Три выстрела видно
/// сразу; на iPhone порядок прежний — строка, последний справа.
struct ShotColumn: View {
    let entries: [ShotFeedEntry]
    let width: CGFloat
    var alphabet: BoardAlphabet = .current
    /// Сколько капсул видно без промотки.
    var visible = ShotColumnMetrics.visible

    static var rowHeight: CGFloat { ShotColumnMetrics.rowHeight }
    static var rowGap: CGFloat { ShotColumnMetrics.rowGap }
    static var solidShare: CGFloat { ShotColumnMetrics.solidShare }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Высота окна капсул — постоянная, чтобы столбик не рос с каждым
    /// выстрелом и не наезжал на поле.
    var windowHeight: CGFloat {
        CGFloat(visible) * Self.rowHeight + CGFloat(visible - 1) * Self.rowGap
    }

    var body: some View {
        VStack(spacing: Self.rowGap) {
            Text("Shots at you")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.9)
                .textCase(.uppercase)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.inkSecondary)

            if entries.isEmpty {
                Text("No shots yet")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.inkTertiary)
                    .frame(height: Self.rowHeight)
                    .frame(maxHeight: windowHeight, alignment: .top)
            } else {
                chips
            }
        }
        .frame(width: width)
        .accessibilityElement(children: .combine)
    }

    private var chipArrival: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)
    }

    private var chips: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Self.rowGap) {
                // Последний сверху: новый выстрел въезжает на место первого.
                ForEach(Array(entries.enumerated().reversed()), id: \.element.id) { index, entry in
                    ShotChip(entry: entry, isLast: index == entries.count - 1,
                             alphabet: alphabet, isLarge: true)
                        .transition(chipArrival)
                }
            }
            .frame(maxWidth: .infinity)
            .animation(.easeOut(duration: Motion.scaled(Motion.feedChip, reduceMotion: reduceMotion)),
                       value: entries)
        }
        .defaultScrollAnchor(.top)
        .frame(height: windowHeight)
        // Затухание маской по самим капсулам — подложки под столбиком нет.
        .mask {
            LinearGradient(stops: [.init(color: .black, location: 0),
                                   .init(color: .black, location: Self.solidShare),
                                   .init(color: .clear, location: 1)],
                           startPoint: .top, endPoint: .bottom)
        }
    }
}

// MARK: - Превью

#Preview("iPad · подсказка и лента") {
    ZStack {
        SeaBackground()
        HStack(alignment: .bottom, spacing: 40) {
            ShotColumn(entries: [.init(id: 0, coordinate: .init(row: 3, column: 2), outcome: .miss),
                                 .init(id: 1, coordinate: .init(row: 9, column: 10), outcome: .miss),
                                 .init(id: 2, coordinate: .init(row: 7, column: 3), outcome: .miss),
                                 .init(id: 3, coordinate: .init(row: 4, column: 6), outcome: .hit)],
                       width: Geometry.Inset.feedWidthPortrait, alphabet: .cyrillic)
            ShotColumn(entries: [], width: Geometry.Inset.feedWidthLandscape)
            PadHintButton(cost: 10, isEnabled: true, isTall: true)
            PadHintButton(cost: 3, isEnabled: false, isTall: false)
        }
    }
    .preferredColorScheme(.dark)
}
