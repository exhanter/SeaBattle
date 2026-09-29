//
//  PadMenuScreen.swift
//  Sea Battle — меню на iPad (R2.6, раунд 7)
//
//  Спека 4.2 «iPad», макеты 22a (вертикально) и 22b (горизонтально); 19a, 19b
//  и 20a–20c отменены. Три зоны сверху вниз, прокрутки нет:
//
//  1. Арт во всю ширину от верхнего края, без мата; низ растворяется в море
//     маской. Название лежит на арте слева.
//  2. Режимы плитками — там, куда достают пальцы.
//  3. Нижний ряд на рамке 24: «Статистика» и «Настройки» квадратами в углах,
//     между ними «Продолжить партию», если есть незакрытая партия.
//
//  Экран ничего не решает сам, как и `MenuScreen` на iPhone: получает готовые
//  ответы и отдаёт наружу нажатия.
//

import SwiftUI

// MARK: - Геометрия

/// Где что стоит по вертикали — чистая функция от высоты экрана, под тестом.
/// Все зоны считаются **от нижнего ряда вверх**: плитки должны быть под
/// пальцами на любом iPad, а арт забирает всё, что осталось сверху.
struct PadMenuGeometry: Equatable, Sendable {
    let orientation: PadOrientation
    /// Верх нижнего ряда квадратов.
    let bottomRowTop: CGFloat
    /// Верх и высота блока плиток.
    let tilesTop: CGFloat
    let tilesHeight: CGFloat
    /// Высота арта: до верхней кромки плиток плюс 40 — плитки лежат на
    /// растворяющейся части.
    let artHeight: CGFloat
    /// Верх названия.
    let titleTop: CGFloat

    typealias M = Geometry.PadMenu

    init(size: CGSize, safeBottom: CGFloat = 0) {
        let orientation = PadOrientation.of(size)
        let bottom = max(Geometry.Inset.padFrame, safeBottom)
        let bottomRowTop = size.height - bottom - Geometry.Inset.padTile
        let tilesHeight = orientation == .portrait
            ? M.wideTileHeight + M.gapPortrait + M.gridTileHeight * 2 + M.gapPortrait
            : M.rowTileHeight
        let tilesTop = bottomRowTop - M.aboveBottomRow - tilesHeight
        self.orientation = orientation
        self.bottomRowTop = bottomRowTop
        self.tilesTop = tilesTop
        self.tilesHeight = tilesHeight
        self.artHeight = tilesTop + M.artOverlap
        self.titleTop = tilesTop - (orientation == .portrait ? M.titleAboveTilesPortrait
                                                             : M.titleAboveTilesLandscape)
    }

    var titleSize: CGFloat {
        orientation == .portrait ? M.titlePortrait : M.titleLandscape
    }

    var tileGap: CGFloat {
        orientation == .portrait ? M.gapPortrait : M.gapLandscape
    }
}

// MARK: - Экран

struct PadMenuScreen: View {
    let isPremium: Bool
    /// Есть ли незакрытая партия — тогда в середине нижнего ряда стоит
    /// «Продолжить партию». Нет — середина пустая, ничего не сдвигается.
    let canContinue: Bool
    /// Уровень продолжаемой одиночной партии — подпись под «Продолжить
    /// партию». `nil` — партия не одиночная (или их две).
    var continueLevel: AppState.DifficultyLevel?
    var onMode: (MenuMode) -> Void = { _ in }
    var onContinue: () -> Void = {}
    var onTab: (ShellTab) -> Void = { _ in }

    typealias M = Geometry.PadMenu

    var body: some View {
        GeometryReader { proxy in
            let size = CGSize(width: proxy.size.width,
                              height: proxy.size.height + proxy.safeAreaInsets.top
                                  + proxy.safeAreaInsets.bottom)
            let g = PadMenuGeometry(size: size, safeBottom: proxy.safeAreaInsets.bottom)
            let frame = Geometry.Inset.padFrame

            ZStack(alignment: .topLeading) {
                art(width: size.width, height: g.artHeight)

                Text("Sea Battle")
                    .font(.system(size: g.titleSize, weight: .semibold, design: .rounded))
                    .tracking(-0.02 * g.titleSize)
                    .foregroundStyle(Color.inkPrimary)
                    .shadow(color: .inkTitleShadow,
                            radius: NavMetrics.titleShadowRadius,
                            y: NavMetrics.titleShadowOffsetY)
                    .accessibilityIdentifier("titleMainText")
                    .padding(.leading, frame * 2)
                    .padding(.top, g.titleTop)

                tiles(g)
                    .frame(width: size.width - frame * 2, height: g.tilesHeight)
                    .padding(.leading, frame)
                    .padding(.top, g.tilesTop)

                bottomRow
                    .frame(width: size.width - frame * 2)
                    .padding(.leading, frame)
                    .padding(.top, g.bottomRowTop)
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .ignoresSafeArea()
        }
    }

    // MARK: Арт

    /// Пока отдельных файлов `MenuArtPortrait` / `MenuArtLandscape` нет — тот
    /// же снимок, что на iPhone, с `cover` и маской (раунд 7).
    private func art(width: CGFloat, height: CGFloat) -> some View {
        Image("war_ship8")
            .resizable()
            .scaledToFill()
            .frame(width: width, height: max(0, height))
            .clipped()
            // Непрозрачен до 55 % высоты, к низу растворяется в море.
            .mask {
                LinearGradient(stops: [.init(color: .black, location: 0),
                                       .init(color: .black, location: M.artOpaqueUntil),
                                       .init(color: .clear, location: 1)],
                               startPoint: .top, endPoint: .bottom)
            }
            .accessibilityHidden(true)
    }

    // MARK: Плитки режимов

    @ViewBuilder
    private func tiles(_ g: PadMenuGeometry) -> some View {
        let modes = MenuMode.all
        if g.orientation == .portrait, let first = modes.first {
            // «Одиночная игра» — самый частый режим — широкой плиткой, под ней
            // сетка 2 × 2.
            VStack(spacing: g.tileGap) {
                ModeTile(item: first, isLocked: first.isLocked(isPremium: isPremium),
                         isWide: true) { onMode(first) }
                    .frame(height: M.wideTileHeight)
                let rest = Array(modes.dropFirst())
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: g.tileGap) {
                        ForEach(rest[(row * 2)..<min(rest.count, row * 2 + 2)]) { item in
                            ModeTile(item: item, isLocked: item.isLocked(isPremium: isPremium)) {
                                onMode(item)
                            }
                        }
                    }
                    .frame(height: M.gridTileHeight)
                }
            }
        } else {
            // Пять плиток в ряд одинаковой ширины, «Одиночная игра» первой.
            HStack(spacing: g.tileGap) {
                ForEach(modes) { item in
                    ModeTile(item: item, isLocked: item.isLocked(isPremium: isPremium)) {
                        onMode(item)
                    }
                }
            }
        }
    }

    // MARK: Нижний ряд

    private var bottomRow: some View {
        ZStack {
            PadCornerTabs(current: .play, onSelect: onTab)
            if canContinue {
                continueTile
            }
        }
    }

    private var continueTile: some View {
        Button(action: onContinue) {
            HStack(spacing: 14) {
                Image(systemName: "arrow.uturn.backward.circle")
                    .font(.system(size: symbolFontSize(inBox: 30)))
                    .foregroundStyle(Color.roleYou)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Continue game")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.roleYou)
                    if let continueLevel {
                        (Text("Single player") + Text(verbatim: " · ")
                            + Text(LevelChoice.title(for: continueLevel)))
                            .font(.system(size: 12.5))
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 22)
            .frame(width: M.continueWidth, height: Geometry.Inset.padTile)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassPanel(.g2, radius: PadTileMetrics.radius, highlight: .selected)
        .accessibilityIdentifier("continueGameButton")
    }
}

// MARK: - Плитка режима

/// Плитка режима (4.2 «iPad»): G2, радиус 24, поля 18; значок сверху, внизу
/// название и подпись до двух строк; замок в правом верхнем углу. Широкая
/// плитка — значок слева, подпись в строку. Закрытая выглядит как обычная, как
/// `ModeRow` на iPhone: режим остаётся приглашением, а не запретом.
private struct ModeTile: View {
    let item: MenuMode
    let isLocked: Bool
    var isWide = false
    var action: () -> Void = {}

    typealias M = Geometry.PadMenu

    var body: some View {
        Button(action: action) {
            Group {
                if isWide {
                    HStack(spacing: 16) {
                        icon(40)
                        VStack(alignment: .leading, spacing: 4) {
                            name(20)
                            subtitle(lines: 1)
                        }
                        Spacer(minLength: 0)
                        lock
                    }
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top) {
                            icon(M.tileIcon)
                            Spacer(minLength: 0)
                            lock
                        }
                        Spacer(minLength: 8)
                        name(M.tileName)
                        subtitle(lines: 2)
                            .padding(.top, 3)
                    }
                }
            }
            .padding(M.tilePadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassPanel(.g2, radius: M.tileRadius)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isLocked ? Text("Pro") : Text(""))
    }

    private func icon(_ side: CGFloat) -> some View {
        Image(systemName: item.icon)
            .font(.system(size: symbolFontSize(inBox: side)))
            .foregroundStyle(Color.inkPrimary)
            .frame(width: side, height: side)
    }

    /// Длинное название («Вдвоём на устройстве») переносится на вторую строку,
    /// как в кадре 22b, а не ужимается шрифтом — иначе плитки в ряду читаются
    /// разным кеглем.
    private func name(_ size: CGFloat) -> some View {
        Text(item.title)
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.inkPrimary)
            .lineLimit(isWide ? 1 : 2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func subtitle(lines: Int) -> some View {
        Text(item.subtitle)
            .font(.system(size: M.tileSub))
            .foregroundStyle(Color.inkSecondary)
            .lineLimit(lines)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var lock: some View {
        if isLocked {
            Image(systemName: "lock")
                .font(.system(size: symbolFontSize(inBox: 22)))
                .foregroundStyle(Color.inkPrimary)
                .frame(width: 22, height: 22)
        }
    }
}

// MARK: - Превью

#Preview("Меню iPad · вертикально", traits: .fixedLayout(width: 834, height: 1194)) {
    ZStack {
        SeaBackground()
            .ignoresSafeArea()
        PadMenuScreen(isPremium: false, canContinue: true, continueLevel: .hard)
    }
    .preferredColorScheme(.dark)
}

#Preview("Меню iPad · горизонтально", traits: .fixedLayout(width: 1194, height: 834)) {
    ZStack {
        SeaBackground()
            .ignoresSafeArea()
        PadMenuScreen(isPremium: false, canContinue: false)
    }
    .preferredColorScheme(.dark)
}

#Preview("Меню iPad · светлая", traits: .fixedLayout(width: 834, height: 1194)) {
    ZStack {
        SeaBackground()
            .ignoresSafeArea()
        PadMenuScreen(isPremium: true, canContinue: true, continueLevel: .medium)
    }
    .preferredColorScheme(.light)
}
