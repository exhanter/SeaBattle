//
//  PadWelcomeScreen.swift
//  Sea Battle — первый запуск на iPad (этап 5, 14.10)
//
//  Как главный экран iPad: арт во всю ширину сверху, низ растворяется в море,
//  название крупно на арте. Под ним все пять режимов с полным описанием —
//  текстом между тонкими линиями, не кнопками: новичок видит, что умеет
//  приложение; у режимов Pro метка. Внизу квадраты по углам: «Восстановить
//  покупку» и главный «Начать», при своём поле справа — зеркально.
//

import SwiftUI

// MARK: - Полное описание режима

extension MenuMode {
    /// Что умеет режим — полностью, для первого запуска (14.10). В меню —
    /// короткая подпись `subtitle`.
    var fullDescription: LocalizedStringKey {
        switch mode {
        case .computer:
            "Play the computer at one of four levels, from a calm game to the Expert who finds a hidden fleet. Wins earn points, and points pay for hints."
        case .paper:
            "Your opponent has a sheet of paper: you call out cells to each other, and the app keeps both boards and the score."
        case .hotSeat:
            "Place your fleets in turn and pass the device after every move. A four-digit code keeps each fleet secret."
        case .nearby:
            "Two iPhones or iPads side by side play over Bluetooth and Wi-Fi — no internet needed."
        case .online:
            "Play a friend with a six-digit code, or let Game Center find a random opponent."
        }
    }
}

// MARK: - Экран

private enum PadWelcomeMetrics {
    static let maxWidth: CGFloat = 1000
    static let gap: CGFloat = 14
    /// Поля режима внутри сетки с линиями.
    static let cellPadding: CGFloat = 18
    /// Доля высоты экрана под арт меню, пока нет своего арта.
    static let artShare: CGFloat = 0.42
}

struct PadWelcomeScreen: View {
    var offersRestore: Bool = true
    var isPremium: Bool = false
    var onRestore: () async -> Bool = { false }
    var onPlay: () -> Void = {}

    @Environment(\.mirrorsBottomTiles) private var mirrored
    @State private var restoring = false
    @State private var notice: ProPurchaseNotice?

    private typealias M = PadWelcomeMetrics

    var body: some View {
        GeometryReader { proxy in
            let size = CGSize(width: proxy.size.width,
                              height: proxy.size.height + proxy.safeAreaInsets.top
                                  + proxy.safeAreaInsets.bottom)
            let wide = size.width > size.height
            ZStack(alignment: .top) {
                art(size: size, wide: wide)
                VStack(spacing: 0) {
                    title(wide: wide)
                        .padding(.top, proxy.safeAreaInsets.top + (wide ? 40 : 72))
                    Spacer(minLength: 16)
                    VStack(alignment: .leading, spacing: M.gap) {
                        Text("Familiar rules: a 10 × 10 board and ten ships.")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Color.inkPrimary)
                            .shadow(color: .inkTitleShadow, radius: NavMetrics.titleShadowRadius,
                                    y: NavMetrics.titleShadowOffsetY)
                            .padding(.leading, M.cellPadding)
                        tiles(wide: wide,
                              width: min(M.maxWidth, size.width
                                  - 2 * (Geometry.Inset.padFrame + Geometry.Nav.stackInset)))
                        if let notice {
                            Text(notice.text)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.inkSecondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: M.maxWidth)
                    .padding(.horizontal, Geometry.Inset.padFrame + Geometry.Nav.stackInset)
                    // Плитки — над нижним рядом, как в меню: картинке сверху
                    // достаётся всё остальное.
                    Spacer()
                        .frame(height: Geometry.PadMenu.aboveBottomRow)
                    bottomRow
                        .padding(.horizontal, Geometry.Inset.padFrame)
                        .padding(.bottom, max(Geometry.Inset.padFrame, proxy.safeAreaInsets.bottom))
                }
            }
            .frame(width: size.width, height: size.height, alignment: .top)
            .ignoresSafeArea()
        }
    }

    // MARK: Арт и название

    /// Свой арт первого запуска — на весь экран: корабль над текстом, под
    /// текстом его море (требования — `docs/STATUS.md`, «Арт первого
    /// запуска»). Пока файлов нет — арт меню верхней полосой.
    @ViewBuilder
    private func art(size: CGSize, wide: Bool) -> some View {
        let own: MenuArt.Kind = wide ? .welcomeLandscape : .welcomePortrait
        if own.isAvailable {
            MenuArt(kind: own, width: size.width, height: size.height)
        } else {
            MenuArt(kind: wide ? .padLandscape : .padPortrait,
                    width: size.width, height: size.height * M.artShare + 80)
        }
    }

    private func title(wide: Bool) -> some View {
        let font = wide ? Geometry.PadMenu.titleLandscape : Geometry.PadMenu.titlePortrait
        return Text("Sea Battle")
            .font(.system(size: font, weight: .semibold, design: .rounded))
            .tracking(-0.02 * font)
            .foregroundStyle(Color.inkPrimary)
            .shadow(color: .inkTitleShadow, radius: NavMetrics.titleShadowRadius,
                    y: NavMetrics.titleShadowOffsetY)
            .frame(maxWidth: M.maxWidth, alignment: .leading)
            // Левый край — по тексту режимов.
            .padding(.horizontal, Geometry.Inset.padFrame + Geometry.Nav.stackInset + M.cellPadding)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("titleMainText")
    }

    // MARK: Режимы

    /// Режимы — не плитками-кнопками, а текстом на море, разделённым тонкими
    /// линиями, как страница буклета: здесь только читают (14.10). Нажать
    /// хочется одно — латунный «Начать».
    @ViewBuilder
    private func tiles(wide: Bool, width: CGFloat) -> some View {
        let modes = MenuMode.all(pad: true)
        if let first = modes.first {
            let rest = Array(modes.dropFirst())
            if wide {
                // «Одиночная игра» (самое длинное описание) — колонкой во всю
                // высоту, остальные четыре — сеткой 2 × 2 рядом.
                HStack(spacing: 0) {
                    // Три колонки поровну: HStack сам поделил бы пополам.
                    WelcomeModeCell(item: first, isPremium: isPremium)
                        .frame(width: (width - 2) / 3)
                        .frame(maxHeight: .infinity, alignment: .top)
                    WelcomeRule(vertical: true)
                    grid(rest)
                }
                .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    WelcomeModeCell(item: first, isPremium: isPremium, isWide: true)
                    WelcomeRule(vertical: false)
                    grid(rest)
                }
            }
        }
    }

    /// Сетка 2 × 2 с линиями между ячейками; ряд — по самой высокой ячейке.
    /// Не `Grid`: тот меряет колонки по тексту в одну строку.
    private func grid(_ items: [MenuMode]) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<(items.count + 1) / 2, id: \.self) { row in
                if row > 0 { WelcomeRule(vertical: false) }
                HStack(spacing: 0) {
                    cell(items, row * 2)
                    WelcomeRule(vertical: true)
                    cell(items, row * 2 + 1)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func cell(_ items: [MenuMode], _ index: Int) -> some View {
        if index < items.count {
            WelcomeModeCell(item: items[index], isPremium: isPremium)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            Color.clear
        }
    }

    // MARK: Низ

    private var bottomRow: some View {
        HStack(alignment: .bottom) {
            if mirrored { playTile } else { restoreTileOrSpace }
            Spacer(minLength: 0)
            if mirrored { restoreTileOrSpace } else { playTile }
        }
    }

    /// Дальше — шаг имени, а не меню и не партия: «Начать», а не «Играть».
    private var playTile: some View {
        Button { onPlay() } label: { PadTileLabel(title: "Get started", icon: "arrow.right") }
            .buttonStyle(PrimaryButtonStyle(radius: PadTileMetrics.radius, fillsFrame: true))
            .frame(width: PadTileMetrics.side, height: PadTileMetrics.side)
            .accessibilityIdentifier("welcomePlay")
    }

    /// «Восстановить покупку» — только где Pro продаётся и пока его нет.
    @ViewBuilder
    private var restoreTileOrSpace: some View {
        if offersRestore && !isPremium {
            Button {
                Task {
                    restoring = true
                    notice = await onRestore() ? nil : .nothingToRestore
                    restoring = false
                }
            } label: {
                PadTileLabel(title: restoring ? "Restoring…" : "Restore purchase", icon: "arrow.clockwise")
            }
            .buttonStyle(SecondaryButtonStyle(radius: PadTileMetrics.radius, fillsFrame: true))
            .disabled(restoring)
            .frame(width: PadTileMetrics.side, height: PadTileMetrics.side)
            .accessibilityIdentifier("welcomeRestore")
        } else {
            Color.clear.frame(width: PadTileMetrics.side, height: 1)
        }
    }
}

// MARK: - Режим

/// Режим с полным описанием — без стекла и без нажатия: здесь знакомятся,
/// а выбирают в меню.
private struct WelcomeModeCell: View {
    let item: MenuMode
    let isPremium: Bool
    var isWide = false

    private var isPro: Bool { item.isLocked(isPremium: isPremium) }

    var body: some View {
        Group {
            if isWide {
                HStack(alignment: .top, spacing: 16) {
                    icon
                    VStack(alignment: .leading, spacing: 6) {
                        header
                        description
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    icon
                    header
                    description
                }
            }
        }
        .padding(PadWelcomeMetrics.cellPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }

    private var icon: some View {
        ScaledSymbol(name: item.icon, box: 30)
            .foregroundStyle(Color.roleYou)
            .frame(width: 30, height: 30)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(item.title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            if isPro {
                Text(verbatim: "Pro")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.inkPrimary)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 7)
                    .background(Color.roleYou.opacity(0.24), in: Capsule())
                    .overlay { Capsule().strokeBorder(Color.roleYou, lineWidth: 1) }
            }
        }
    }

    private var description: some View {
        Text(item.fullDescription)
            .font(.system(size: 13))
            .lineSpacing(2)
            .foregroundStyle(Color.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Тонкая линия между режимами.
private struct WelcomeRule: View {
    let vertical: Bool

    var body: some View {
        Rectangle()
            .fill(Color.glassStroke)
            .frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
            .frame(maxWidth: vertical ? nil : .infinity, maxHeight: vertical ? .infinity : nil)
            .padding(vertical ? .vertical : .horizontal, 10)
            .accessibilityHidden(true)
    }
}

// MARK: - Превью

private struct PadWelcomeDemo: View {
    var mirrored = false

    var body: some View {
        ZStack {
            SeaBackground()
                .ignoresSafeArea()
            PadWelcomeScreen()
        }
        .environment(\.usesPadLayout, true)
        .environment(\.mirrorsBottomTiles, mirrored)
        .phoneStyle(true)
        .preferredColorScheme(.dark)
    }
}

struct PadWelcome1_Previews: PreviewProvider {
    static var previews: some View {
        PadWelcomeDemo()
            .padPreview(.portrait, "1 · вертикально")
    }
}

struct PadWelcome2_Previews: PreviewProvider {
    static var previews: some View {
        PadWelcomeDemo()
            .padPreview(.landscapeLeft, "2 · горизонтально")
    }
}

struct PadWelcome3_Previews: PreviewProvider {
    static var previews: some View {
        PadWelcomeDemo(mirrored: true)
            .padPreview(.portrait, "3 · вертикально · своё поле справа")
    }
}

struct PadWelcome4_Previews: PreviewProvider {
    static var previews: some View {
        PadWelcomeDemo(mirrored: true)
            .padPreview(.landscapeLeft, "4 · горизонтально · своё поле справа")
    }
}

