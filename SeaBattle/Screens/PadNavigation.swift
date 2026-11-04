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
//    корне таба его собственный угол занимает «Главная» — каждый угол всегда
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

// MARK: - Превью на iPad

extension View {
    /// Превью экрана iPad на самом iPad. У `#Preview` нет трейта устройства:
    /// `.portrait` / `.landscapeLeft` берут устройство канваса, а оно идёт за
    /// целью запуска — при iPhone в схеме iPad-превью открывались на iPhone
    /// (13.10). `previewDevice` действует только в `PreviewProvider`.
    func padPreview(_ orientation: InterfaceOrientation, _ name: String,
                    device: String = "iPad Pro 11-inch (M5)") -> some View {
        previewDevice(PreviewDevice(rawValue: device))
            .previewInterfaceOrientation(orientation)
            .previewDisplayName(name)
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
    /// Квадрат моряка: аватар — сторона квадрата минус этот зазор.
    static let avatarInset: CGFloat = 24
}

/// Значок над подписью — содержимое любого квадрата.
struct PadTileLabel: View {
    let title: LocalizedStringKey
    var icon: String?
    /// Цвет значка. Ответы игры на бумаге красят значок в цвет результата.
    var iconTint: Color = .inkPrimary
    /// Квадрат «Моряк» (заказчик 04.11): аватар почти во весь квадрат и без
    /// подписи — название читают VoiceOver и долгое нажатие.
    var sailor: SailorLook?

    var body: some View {
        VStack(spacing: PadTileMetrics.gap) {
            if let sailor {
                SailorAvatar(look: sailor, size: PadTileMetrics.side - PadTileMetrics.avatarInset)
                    .accessibilityHidden(true)
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: symbolFontSize(inBox: PadTileMetrics.icon)))
                    .frame(height: PadTileMetrics.icon)
                    .foregroundStyle(iconTint)
                    // Плитку называет подпись; системное имя символа
                    // («Drag» у меню) VoiceOver читать незачем.
                    .accessibilityHidden(true)
            }
            if sailor == nil {
            Text(title)
                .font(.system(size: PadTileMetrics.label, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            }
        }
        .foregroundStyle(Color.inkPrimary)
        .padding(.horizontal, 6)
        // Кегль плитки фиксирован (квадрат 104): при крупном тексте долгое
        // нажатие показывает подпись крупно.
        .accessibilityShowsLargeContentViewer {
            if let icon { Label(title, systemImage: icon) } else { Text(title) }
        }
    }
}

/// Навигационный квадрат: стекло G2 **без деревянного канта** (раунд 8 — у
/// квадратов 104 канта нет нигде).
struct PadNavTile: View {
    let title: LocalizedStringKey
    let icon: String
    /// Квадрат таба «Моряк» — с аватаром.
    var sailor: SailorLook?
    var identifier: String?
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            PadTileLabel(title: title, icon: icon, sailor: sailor)
                .frame(width: PadTileMetrics.side, height: PadTileMetrics.side)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassPanel(.g2, radius: PadTileMetrics.radius)
        .accessibilityLabel(Text(title))
        .accessibilityIdentifier(identifier ?? "")
    }
}

extension PadNavTile {
    /// «Меню» — выход из партии; то, чем на iPhone служит `NavRow`.
    static func menu(_ action: @escaping () -> Void) -> PadNavTile {
        PadNavTile(title: "Menu", icon: "line.3.horizontal",
                   identifier: "navMenuButton", action: action)
    }

    @MainActor
    static func tab(_ tab: ShellTab, _ action: @escaping () -> Void) -> PadNavTile {
        PadNavTile(title: tab.title, icon: tab.icon,
                   sailor: tab == .sailor ? ProgressStore.shared.sailor.currentLook : nil,
                   identifier: "tab_\(tab.rawValue)", action: action)
    }
}

// MARK: - Углы корней табов

/// Какой таб стоит в каком углу. Чистая функция, под тестом: правило «свой
/// угол занимает „Главная“» легко перепутать местами.
enum PadCorners {
    static func tabs(on current: ShellTab) -> (leading: ShellTab, trailing: ShellTab) {
        (leading: current == .sailor ? .play : .sailor,
         trailing: current == .settings ? .play : .settings)
    }
}

/// Два квадрата корней табов в нижних углах, на рамке 24 pt. Середину ряда
/// занимает вызывающий («Продолжить партию» в меню) или она пустая.
struct PadCornerTabs: View {
    let current: ShellTab
    var onSelect: (ShellTab) -> Void = { _ in }

    /// Своё поле справа — квадраты меняются сторонами, как везде (14.10).
    @Environment(\.mirrorsBottomTiles) private var mirrored

    var body: some View {
        let corners = PadCorners.tabs(on: current)
        let left = mirrored ? corners.trailing : corners.leading
        let right = mirrored ? corners.leading : corners.trailing
        HStack(alignment: .bottom) {
            PadNavTile.tab(left) { onSelect(left) }
            Spacer(minLength: 0)
            PadNavTile.tab(right) { onSelect(right) }
        }
    }
}

// MARK: - Превью

#Preview("iPad · квадраты") {
    ZStack {
        SeaBackground()
        VStack(spacing: 40) {
            PadCornerTabs(current: .play)
            PadCornerTabs(current: .sailor)
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
