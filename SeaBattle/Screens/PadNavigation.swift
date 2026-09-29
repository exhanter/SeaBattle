//
//  PadNavigation.swift
//  Sea Battle — навигация iPad (R2.6, шаг 10 порядка сборки)
//
//  Спека 3: вертикально — боковой рельс вместо таб-бара, укорочен до
//  содержимого и прижат к низу слева, 104 pt; горизонтально — панель
//  навигации по центру низа с подписями. Кадры `screen11Port` и
//  `screen11Land` (тур 11.2): одна рамка 24 pt от всех четырёх краёв.
//
//  Правило 3.1 то же, что на iPhone: табы — только на корнях трёх табов. В
//  партии (стол, уровень, итоги) навигация сжимается до одного «Меню».
//  В кадрах боя тура 11 в рельсе стоят и табы — спека позднее, по ней
//  (вопрос В21 в `docs/DESIGN_QUESTIONS.md`).
//

import SwiftUI

// MARK: - Какая раскладка

extension EnvironmentValues {
    /// Раскладка iPad: рельс или нижняя панель, стол на два поля, колонки.
    /// Ставится корнем приложения по устройству, а не по ширине: на iPhone
    /// Pro Max в горизонтали ширина тоже большая, а раскладка iPad там не нужна.
    @Entry var usesPadLayout = false
}

/// Две ориентации iPad. Считается по пропорции области, а не по датчику:
/// в Split View «горизонтальный» iPad бывает выше, чем шире.
enum PadOrientation: Equatable, Sendable {
    case portrait
    case landscape

    static func of(_ size: CGSize) -> PadOrientation {
        size.width > size.height ? .landscape : .portrait
    }
}

/// Числа навигации из кадров `screen11Port` (`railItem`) и `screen11Land`
/// (`navItem`). В пакете токенов есть только ширина рельса и рамка.
enum PadNavMetrics {
    // Рельс
    static let railRadius: CGFloat = Geometry.Radius.panelLarge
    static let railPaddingTop: CGFloat = 20
    static let railPaddingBottom: CGFloat = 22
    static let railGap: CGFloat = 22
    static let railIcon: CGFloat = 26
    static let railLabel: CGFloat = 10.5
    static let railLabelGap: CGFloat = 6
    // Нижняя панель
    static let barHeight: CGFloat = Geometry.Inset.hintHeightLandscape
    static let barRadius: CGFloat = 24
    static let barPadding: CGFloat = 22
    static let barGap: CGFloat = 22
    static let barIcon: CGFloat = 25
    static let barLabel: CGFloat = 14
    static let barLabelGap: CGFloat = 8
    // «Меню» в партии
    static let menuLabel: CGFloat = 14.5
    static let menuIconRow: CGFloat = 22
}

// MARK: - Табы

/// Навигация на корнях трёх табов: рельс вертикально, панель горизонтально.
struct PadTabNavigation: View {
    @Binding var selection: ShellTab
    let orientation: PadOrientation

    var body: some View {
        if orientation == .portrait {
            VStack(spacing: PadNavMetrics.railGap) {
                ForEach(ShellTab.allCases, id: \.self) { tab in
                    item(tab, row: false)
                }
            }
            .padding(.top, PadNavMetrics.railPaddingTop)
            .padding(.bottom, PadNavMetrics.railPaddingBottom)
            .frame(width: Geometry.Inset.railWidth)
            .glassPanel(.g2, radius: PadNavMetrics.railRadius, wood: .trailing)
        } else {
            HStack(spacing: PadNavMetrics.barGap) {
                ForEach(ShellTab.allCases, id: \.self) { tab in
                    item(tab, row: true)
                }
            }
            .padding(.horizontal, PadNavMetrics.barPadding)
            .frame(height: PadNavMetrics.barHeight)
            .glassPanel(.g2, radius: PadNavMetrics.barRadius, wood: .top)
        }
    }

    private func item(_ tab: ShellTab, row: Bool) -> some View {
        let isSelected = tab == selection
        let layout = row
            ? AnyLayout(HStackLayout(spacing: PadNavMetrics.barLabelGap))
            : AnyLayout(VStackLayout(spacing: PadNavMetrics.railLabelGap))
        let icon = row ? PadNavMetrics.barIcon : PadNavMetrics.railIcon
        return Button {
            withAnimation(Motion.quick) { selection = tab }
        } label: {
            layout {
                Image(systemName: tab.icon)
                    .font(.system(size: symbolFontSize(inBox: icon)))
                    .frame(height: icon)
                    .foregroundStyle(Color.inkPrimary)
                Text(tab.title)
                    .font(.system(size: row ? PadNavMetrics.barLabel : PadNavMetrics.railLabel,
                                  weight: isSelected ? .bold : .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isSelected ? Color.roleYou : Color.inkPrimary)
            }
            .frame(minWidth: Geometry.Hit.minTarget, minHeight: Geometry.Hit.minTarget)
            .opacity(isSelected ? 1 : TabBarMetrics.inactiveOpacity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tab_\(tab.rawValue)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - «Меню» в партии

/// Выход из партии на iPad — то, чем на iPhone служит `NavRow`. Вертикально
/// это ячейка рельса шириной 104 pt у левого нижнего угла, горизонтально —
/// панель по центру низа. Высоту задаёт вызывающий: в бою вертикально это
/// квадрат (пара к квадрату подсказки), на расстановке — высота ряда кнопок.
struct PadMenuButton: View {
    let orientation: PadOrientation
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Group {
                if orientation == .portrait {
                    VStack(spacing: 5) {
                        icon(PadNavMetrics.railIcon)
                        label(PadNavMetrics.railLabel, weight: .medium)
                    }
                    .frame(width: Geometry.Inset.railWidth)
                    .frame(maxHeight: .infinity)
                } else {
                    HStack(spacing: 9) {
                        icon(PadNavMetrics.menuIconRow)
                        label(PadNavMetrics.menuLabel, weight: .bold)
                    }
                    .padding(.horizontal, PadNavMetrics.barPadding + 8)
                    .frame(maxHeight: .infinity)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassPanel(.g2,
                    radius: orientation == .portrait ? PadNavMetrics.railRadius : PadNavMetrics.barRadius,
                    wood: orientation == .portrait ? .trailing : .top)
        .accessibilityIdentifier("navMenuButton")
    }

    private func icon(_ box: CGFloat) -> some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: symbolFontSize(inBox: box), weight: .semibold))
            .frame(height: box)
            .foregroundStyle(Color.inkPrimary)
    }

    private func label(_ size: CGFloat, weight: Font.Weight) -> some View {
        Text("Menu")
            .font(.system(size: size, weight: weight, design: .rounded))
            .foregroundStyle(Color.inkPrimary)
    }
}

// MARK: - Превью

private struct PadNavigationDemo: View {
    @State private var tab: ShellTab = .play
    let orientation: PadOrientation

    var body: some View {
        ZStack {
            SeaBackground()
            VStack(spacing: 40) {
                PadTabNavigation(selection: $tab, orientation: orientation)
                PadMenuButton(orientation: orientation)
                    .frame(height: orientation == .portrait ? Geometry.Inset.railWidth
                                                            : PadNavMetrics.barHeight)
            }
        }
    }
}

#Preview("iPad · рельс") {
    PadNavigationDemo(orientation: .portrait)
        .preferredColorScheme(.dark)
}

#Preview("iPad · нижняя панель") {
    PadNavigationDemo(orientation: .landscape)
        .preferredColorScheme(.light)
}
