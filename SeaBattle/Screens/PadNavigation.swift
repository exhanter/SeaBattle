//
//  PadNavigation.swift
//  Sea Battle — навигация iPad (R2.6, раунд 7)
//
//  Спека 3 после раунда 7: **на iPad нет таб-бара, рельса и панели
//  навигации.** Все кнопки нижней линии — отдельные квадраты 104 × 104 на
//  рамке 24 pt: значок 26 над подписью, стекло G2, радиус 22, без деревянного
//  канта (раунд 8). Квадраты расставляются по месту, а не собираются в панель.
//
//  - Корни табов: в меню слева внизу «Статистика», справа «Настройки». На
//    корне таба его собственный угол занимает «Играть» — каждый угол всегда
//    ведёт в одно место, кроме текущего экрана. Выбранного состояния нет.
//  - В партии — один квадрат «Меню» (правило 3.1, как на iPhone).
//

import SwiftUI

// MARK: - Какая раскладка

extension EnvironmentValues {
    /// Раскладка iPad: квадраты вместо таб-бара, стол на два поля, колонки.
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

// MARK: - Квадрат

/// Числа квадрата — кадр `tile21` (тур 21) и спека 3.
enum PadTileMetrics {
    static let side = Geometry.Inset.padTile
    static let radius: CGFloat = 22
    static let icon: CGFloat = 26
    static let label: CGFloat = 14
    static let gap: CGFloat = 7
    /// Зазор между соседними квадратами («Изменить» и «Начать»).
    static let pairGap: CGFloat = 12
}

/// Значок над подписью — содержимое любого квадрата.
struct PadTileLabel: View {
    let title: LocalizedStringKey
    var icon: String?
    /// Цвет значка. Ответы игры на бумаге красят значок в цвет результата.
    var iconTint: Color = .inkPrimary

    var body: some View {
        VStack(spacing: PadTileMetrics.gap) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: symbolFontSize(inBox: PadTileMetrics.icon)))
                    .frame(height: PadTileMetrics.icon)
                    .foregroundStyle(iconTint)
            }
            Text(title)
                .font(.system(size: PadTileMetrics.label, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(Color.inkPrimary)
        .padding(.horizontal, 6)
    }
}

/// Навигационный квадрат: стекло G2 **без деревянного канта** (раунд 8 — у
/// квадратов 104 канта нет нигде).
struct PadNavTile: View {
    let title: LocalizedStringKey
    let icon: String
    var identifier: String?
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            PadTileLabel(title: title, icon: icon)
                .frame(width: PadTileMetrics.side, height: PadTileMetrics.side)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassPanel(.g2, radius: PadTileMetrics.radius)
        .accessibilityIdentifier(identifier ?? "")
    }
}

extension PadNavTile {
    /// «Меню» — выход из партии; то, чем на iPhone служит `NavRow`.
    static func menu(_ action: @escaping () -> Void) -> PadNavTile {
        PadNavTile(title: "Menu", icon: "line.3.horizontal",
                   identifier: "navMenuButton", action: action)
    }

    static func tab(_ tab: ShellTab, _ action: @escaping () -> Void) -> PadNavTile {
        PadNavTile(title: tab.title, icon: tab.icon,
                   identifier: "tab_\(tab.rawValue)", action: action)
    }
}

// MARK: - Углы корней табов

/// Какой таб стоит в каком углу. Чистая функция, под тестом: правило «свой
/// угол занимает „Играть“» легко перепутать местами.
enum PadCorners {
    static func tabs(on current: ShellTab) -> (leading: ShellTab, trailing: ShellTab) {
        (leading: current == .statistics ? .play : .statistics,
         trailing: current == .settings ? .play : .settings)
    }
}

/// Два квадрата корней табов в нижних углах, на рамке 24 pt. Середину ряда
/// занимает вызывающий («Продолжить партию» в меню) или она пустая.
struct PadCornerTabs: View {
    let current: ShellTab
    var onSelect: (ShellTab) -> Void = { _ in }

    var body: some View {
        let corners = PadCorners.tabs(on: current)
        HStack(alignment: .bottom) {
            PadNavTile.tab(corners.leading) { onSelect(corners.leading) }
            Spacer(minLength: 0)
            PadNavTile.tab(corners.trailing) { onSelect(corners.trailing) }
        }
    }
}

// MARK: - Превью

#Preview("iPad · квадраты") {
    ZStack {
        SeaBackground()
        VStack(spacing: 40) {
            PadCornerTabs(current: .play)
            PadCornerTabs(current: .statistics)
            HStack(spacing: PadTileMetrics.pairGap) {
                PadNavTile.menu {}
                Button(action: {}) { PadTileLabel(title: "Change", icon: "hand.draw") }
                    .buttonStyle(SecondaryButtonStyle(radius: PadTileMetrics.radius, fillsFrame: true))
                    .frame(width: PadTileMetrics.side, height: PadTileMetrics.side)
                Button(action: {}) { Text("Start") }
                    .buttonStyle(PrimaryButtonStyle(radius: PadTileMetrics.radius, fillsFrame: true))
                    .frame(width: PadTileMetrics.side, height: PadTileMetrics.side)
            }
        }
        .padding(24)
    }
    .preferredColorScheme(.dark)
}
