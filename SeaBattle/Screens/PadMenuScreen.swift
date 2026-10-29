//
//  PadMenuScreen.swift
//  Sea Battle — меню на iPad (R2.6, раунд 7)
//
//  Спека 4.2 «iPad», макеты 22a (вертикально) и 22b (горизонтально); 19a, 19b
//  и 20a–20c отменены. Три зоны сверху вниз, прокрутки нет:
//
//  1. Арт `PadShipArt`: корабль целиком в своей рамке (29.10) — вертикально
//     над названием, горизонтально справа от него, вода там до низа экрана.
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
    /// Верх названия.
    let titleTop: CGFloat
    /// Куда вписан корабль арта (29.10): вертикально — во всю ширину рамки
    /// над названием, горизонтально — справа от названия над рядом плиток.
    let shipBox: CGRect

    /// Высоты плиток: при крупном тексте растут на столько, на сколько вырос
    /// их текст (до X Large — выше меню не растёт).
    let wideTileHeight: CGFloat
    let gridTileHeight: CGFloat
    let rowTileHeight: CGFloat

    typealias M = Geometry.PadMenu

    /// `textScale` — во сколько раз текст крупнее стандартного (1 при Large).
    init(size: CGSize, safeTop: CGFloat = 0, safeBottom: CGFloat = 0, textScale: CGFloat = 1) {
        let orientation = PadOrientation.of(size)
        let bottom = max(Geometry.Inset.padFrame, safeBottom)
        let bottomRowTop = size.height - bottom - Geometry.Inset.padTile
        let grow = max(0, textScale - 1)
        wideTileHeight = M.wideTileHeight + M.wideTileText * grow
        gridTileHeight = M.gridTileHeight + M.gridTileText * grow
        rowTileHeight = M.rowTileHeight + M.rowTileText * grow
        let tilesHeight = orientation == .portrait
            ? wideTileHeight + M.gapPortrait + gridTileHeight * 2 + M.gapPortrait
            : rowTileHeight
        let tilesTop = bottomRowTop - M.aboveBottomRow - tilesHeight
        self.orientation = orientation
        self.bottomRowTop = bottomRowTop
        self.tilesTop = tilesTop
        self.tilesHeight = tilesHeight
        let titleTop = tilesTop - (orientation == .portrait ? M.titleAboveTilesPortrait
                                                            : M.titleAboveTilesLandscape)
        self.titleTop = titleTop
        // Под часами корабль не начинается.
        let shipTop = safeTop + M.shipBelowStatusBar
        let frame = Geometry.Inset.padFrame
        self.shipBox = orientation == .portrait
            ? CGRect(x: frame, y: shipTop, width: size.width - frame * 2,
                     height: titleTop - shipTop)
            : CGRect(x: size.width * M.shipLeftLandscape, y: shipTop,
                     width: size.width * (1 - M.shipLeftLandscape) - frame,
                     height: tilesTop - M.shipAboveTilesLandscape - shipTop)
    }

    var titleSize: CGFloat {
        orientation == .portrait ? M.titlePortrait : M.titleLandscape
    }

    var tileGap: CGFloat {
        orientation == .portrait ? M.gapPortrait : M.gapLandscape
    }

    /// Вертикально в сетке: верх названия от поля плитки — строка названия и
    /// строка подписи (42 при стандартном тексте) стоят по центру плитки.
    func rowTextTop(textScale: CGFloat) -> CGFloat {
        max(0, (gridTileHeight - M.rowTextLines * textScale) / 2 - M.tilePadding)
    }
}

// MARK: - Корабль в рамке

/// Арт iPad `war_ship8_pad` (4207 × 2755, 29.10): тот же крейсер, дорисованный
/// по бокам небом и морем, а снизу — водой почти на половину высоты.
/// Расставлен так, чтобы корабль вместе с ракетой целиком лёг в заданную рамку
/// экрана (21.10): где корабль — решает раскладка, картинка подстраивается
/// масштабом и сдвигом. Вода под кораблём растворяется в фоне или, если
/// `waterToBottom`, доходит до низа экрана — тогда плитки лежат на картинке.
struct PadShipArt: View {
    /// Куда на экране вписать корабль с ракетой.
    let shipBox: CGRect
    let canvas: CGSize
    /// Если корабль шире рамки (небо обязано дойти до верха экрана, и масштаб
    /// растёт): 0 — корабль у левого края рамки, 0,5 — по центру, 1 — у правого.
    var overflowAnchor: CGFloat = 0.5
    /// Вода не тает до низа экрана, а темнеет к нему: все блоки лежат на
    /// картинке (меню горизонтально, заказчик 29.10 — вариант Б3).
    var waterToBottom = false

    static let asset = "war_ship8_pad"
    static let aspect: CGFloat = 4207.0 / 2755.0
    /// Корабль с ракетой в долях файла (замерено 29.10): от кормы до носа и
    /// от острия ракеты до низа корпуса.
    static let ship = CGRect(x: 0.392, y: 0.099, width: 0.333, height: 0.444)
    /// За какую долю высоты экрана под корпусом вода растворяется в фоне.
    static let fadeLength: CGFloat = 0.14

    /// Колонка крупного текста вертикально: докуда сверху стоит корабль (под
    /// ним начинается текст) — доля экрана, но не ниже той, при которой
    /// картинка во всю ширину вмещает корабль целиком. Горизонтально — 0:
    /// корабль там справа, как в композиции, а текст идёт с самого верха
    /// (иначе на режимы осталась бы одна строка, 29.10, mini на AX5).
    static func accessibleBand(for size: CGSize) -> CGFloat {
        guard size.height >= size.width else { return 0 }
        let share = min(size.height * Geometry.PadMenu.accessibleArtShare,
                        Geometry.PadMenu.accessibleArtMax)
        let shipFits = size.width / aspect * (ship.maxY + 0.03)
        return max(share, shipFits)
    }

    /// Рамка картинки на экране — чистая функция, чтобы раскладка могла
    /// узнать, где окажется горизонт.
    static func imageFrame(shipBox box: CGRect, canvas: CGSize,
                           overflowAnchor: CGFloat = 0.5) -> CGRect {
        // Самый крупный масштаб, при котором корабль влезает в рамку…
        var height = min(box.width / (ship.width * aspect), box.height / ship.height)
        // …но над картинкой и по бокам не должно оставаться пустоты.
        height = max(height, box.maxY / ship.maxY, canvas.width / aspect)
        let width = aspect * height
        let shipWidth = ship.width * width
        let slack = box.width - shipWidth
        let shipMinX = box.minX + slack * (slack >= 0 ? 0.5 : overflowAnchor)
        let x = min(0, max(canvas.width - width, shipMinX - ship.minX * width))
        return CGRect(x: x, y: box.maxY - ship.maxY * height, width: width, height: height)
    }

    var body: some View {
        let f = Self.imageFrame(shipBox: shipBox, canvas: canvas, overflowAnchor: overflowAnchor)
        // Доли экрана: где кончается корпус и где кончается вода.
        let hull = (f.minY + f.height * Self.ship.maxY) / canvas.height
        let end = min(1, f.maxY / canvas.height)
        Image(Self.asset)
            .resizable()
            .frame(width: f.width, height: f.height)
            .offset(x: f.minX, y: f.minY)
            .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
            .mask {
                if waterToBottom {
                    Color.black
                } else {
                    // От корпуса вода быстро растворяется в фоне: дальше
                    // яркая дорожка отсвета легла бы под текст.
                    let clear = min(end, hull + Self.fadeLength)
                    LinearGradient(stops: [.init(color: .black, location: 0),
                                           .init(color: .black, location: min(hull + 0.03, clear)),
                                           .init(color: .clear, location: clear)],
                                   startPoint: .top, endPoint: .bottom)
                }
            }
            .overlay {
                if waterToBottom {
                    LinearGradient(stops: [.init(color: .clear, location: hull),
                                           .init(color: .black.opacity(0.4), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                }
            }
            .clipped()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension DynamicTypeSize {
    /// С этого размера первый запуск iPad — прокручиваемая колонка, а не
    /// композиция на весь экран (29.10, проверено на mini по-нидерландски: на
    /// XXX Large постер не вмещал колонку). Меню дальше X Large не растёт.
    var padNeedsColumn: Bool { self >= .xxLarge }
}

/// Затемнение слева под текстом постера первого запуска.
struct PosterScrim: View {
    var body: some View {
        LinearGradient(stops: [.init(color: .black.opacity(0.55), location: 0),
                               .init(color: .black.opacity(0.30), location: 0.32),
                               .init(color: .clear, location: 0.6)],
                       startPoint: .leading, endPoint: .trailing)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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

    @Environment(\.dynamicTypeSize) private var typeSize

    /// Самый крупный текст меню (заказчик 29.10): дальше композиция перестала
    /// бы быть собой; крупнее — по долгому нажатию, Large Content Viewer.
    static let maxTypeSize = DynamicTypeSize.xLarge

    /// Во сколько раз текст крупнее стандартного — плитки растут вместе с ним.
    /// Считается от размера с тем же потолком, что и сам текст: `@ScaledMetric`
    /// читал бы размер до `.dynamicTypeSize(...)`, и на AX5 плитки росли бы
    /// при тексте, застывшем на X Large.
    private var textScale: CGFloat {
        let size = min(typeSize, Self.maxTypeSize)
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(size))
        return UIFontMetrics(forTextStyle: .body).scaledValue(for: 1, compatibleWith: traits)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = CGSize(width: proxy.size.width,
                              height: proxy.size.height + proxy.safeAreaInsets.top
                                  + proxy.safeAreaInsets.bottom)
            composedMenu(size: size, safeTop: proxy.safeAreaInsets.top,
                         safeBottom: proxy.safeAreaInsets.bottom)
        }
        // Текст меню растёт только до X Large — дальше композиция на весь
        // экран перестала бы быть собой (заказчик 29.10: колонка строками на
        // огромном тексте — уже другой дизайн; на iPad X Large и так крупно).
        // Крупнее — по долгому нажатию, Large Content Viewer у каждой плитки.
        .dynamicTypeSize(...Self.maxTypeSize)
    }

    /// Композиция на весь экран: корабль, название, плитки под пальцами. Текст
    /// растёт до X Large, плитки — вместе с ним, корабль уступает место.
    private func composedMenu(size: CGSize, safeTop: CGFloat, safeBottom: CGFloat) -> some View {
        let g = PadMenuGeometry(size: size, safeTop: safeTop, safeBottom: safeBottom,
                                textScale: textScale)
        let frame = Geometry.Inset.padFrame
        return ZStack(alignment: .topLeading) {
                // Горизонтально вода картинки доходит до низа экрана и темнеет
                // к нему — плитки лежат на ней (Б3, 29.10); вертикально тает в
                // фон под названием.
                PadShipArt(shipBox: g.shipBox, canvas: size,
                           waterToBottom: g.orientation == .landscape)

                title(g)
                    .padding(.leading, frame * 2)
                    .padding(.top, g.titleTop)

                tiles(g)
                    .frame(width: size.width - frame * 2, height: g.tilesHeight)
                    .padding(.leading, frame)
                    .padding(.top, g.tilesTop)

                bottomRow(width: size.width - frame * 2)
                    .frame(width: size.width - frame * 2)
                    .padding(.leading, frame)
                    .padding(.top, g.bottomRowTop)
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .ignoresSafeArea()
    }

    private func title(_ g: PadMenuGeometry) -> some View {
        Text("Sea Battle")
            .font(.system(size: g.titleSize, weight: .semibold, design: .rounded))
            .tracking(-0.02 * g.titleSize)
            .foregroundStyle(Color.inkPrimary)
            .shadow(color: .inkTitleShadow,
                    radius: NavMetrics.titleShadowRadius,
                    y: NavMetrics.titleShadowOffsetY)
            .accessibilityIdentifier("titleMainText")
    }

    // MARK: Плитки режимов

    @ViewBuilder
    private func tiles(_ g: PadMenuGeometry) -> some View {
        let modes = MenuMode.all(pad: true)
        if g.orientation == .portrait, let first = modes.first {
            // «Одиночная игра» — самый частый режим — широкой плиткой, под ней
            // сетка 2 × 2.
            VStack(spacing: g.tileGap) {
                ModeTile(item: first, isLocked: first.isLocked(isPremium: isPremium),
                         isRow: true, isWide: true) { onMode(first) }
                    .frame(height: g.wideTileHeight)
                let rest = Array(modes.dropFirst())
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: g.tileGap) {
                        ForEach(rest[(row * 2)..<min(rest.count, row * 2 + 2)]) { item in
                            ModeTile(item: item, isLocked: item.isLocked(isPremium: isPremium),
                                     isRow: true, rowTextTop: g.rowTextTop(textScale: textScale)) {
                                onMode(item)
                            }
                        }
                    }
                    .frame(height: g.gridTileHeight)
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

    private func bottomRow(width: CGFloat) -> some View {
        ZStack {
            PadCornerTabs(current: .play, onSelect: onTab)
            if canContinue {
                continueTile(width: min(M.continueWidth,
                                        width - 2 * (Geometry.Inset.padTile + PadTileMetrics.pairGap)))
            }
        }
    }

    /// Ширина — как в макете (554), но не шире места между угловыми
    /// квадратами: на iPad mini вертикально карточка налезала на них (21.10).
    private func continueTile(width: CGFloat) -> some View {
        // Замыкание, а не ссылка: на `Button(action:)` спотыкается
        // инструментирование превью («ambiguous __designTimeSelection»).
        Button { onContinue() } label: {
            HStack(spacing: 14) {
                Image(systemName: "arrow.uturn.backward.circle")
                    .font(.system(size: symbolFontSize(inBox: 30)))
                    .foregroundStyle(Color.roleYou)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Continue game")
                        .font(.scalable(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.roleYou)
                    if let continueLevel {
                        (Text("Single player") + Text(verbatim: " · ")
                            + Text(LevelChoice.title(for: continueLevel)))
                            .font(.scalable(size: 12.5))
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 22)
            .frame(width: width, height: Geometry.Inset.padTile)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassPanel(.g2, radius: PadTileMetrics.radius, highlight: .selected)
        .accessibilityIdentifier("continueGameButton")
        .accessibilityShowsLargeContentViewer {
            Label("Continue game", systemImage: "arrow.uturn.backward.circle")
        }
    }
}

// MARK: - Плитка режима

/// Плитка режима (4.2 «iPad»): G2, радиус 24, поля 18; замок в правом верхнем
/// углу. Закрытая выглядит как обычная, как `ModeRow` на iPhone: режим
/// остаётся приглашением, а не запретом. Раскладка — по ориентации (заказчик
/// 29.10):
/// - **вертикально** (`isRow`) — значок слева, название и подпись справа, по
///   центру высоты: у всех пяти плиток текст начинается на одной оси (П2);
/// - **горизонтально** — значок сверху, название сразу под ним с постоянного
///   места: в ряду все названия на одной линии, сколько бы строк ни заняли (Т2).
private struct ModeTile: View {
    let item: MenuMode
    let isLocked: Bool
    var isRow = false
    /// Широкая «Одиночная игра» вертикально: название крупнее, подпись в строку.
    var isWide = false
    /// Верх названия в плитке сетки (`PadMenuGeometry.rowTextTop`).
    var rowTextTop: CGFloat = 0
    var action: () -> Void = {}

    typealias M = Geometry.PadMenu

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        button
        .glassPanel(.g2, radius: M.tileRadius)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isLocked ? Text("Pro") : Text(""))
        // Композиция меню iPad фиксирована (плитки на весь экран), кегли —
        // тоже: крупно — по долгому нажатию.
        .accessibilityShowsLargeContentViewer {
            Label(item.title, systemImage: item.icon)
        }
    }

    private var button: some View {
        Button { action() } label: {
            Group {
                if isWide {
                    HStack(spacing: 16) {
                        icon(M.rowIcon)
                        VStack(alignment: .leading, spacing: 4) {
                            name(M.wideTileName)
                            subtitle(lines: 1)
                        }
                        Spacer(minLength: 0)
                        lock
                    }
                } else if isRow {
                    // Название — с постоянного места: обычные строка названия
                    // и строка подписи стоят по центру плитки, а длинный
                    // перевод растёт вниз — в паре названия на одной линии.
                    HStack(alignment: .center, spacing: 16) {
                        icon(M.rowIcon)
                        VStack(alignment: .leading, spacing: 0) {
                            // Отступ сверху сжимается, если длинный перевод
                            // в две строки и названия, и подписи не влезает.
                            Spacer(minLength: 0)
                                .frame(maxHeight: rowTextTop)
                            name(M.tileName)
                            subtitle(lines: 2)
                                .padding(.top, 4)
                            Spacer(minLength: 0)
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
                        name(M.tileName)
                            .padding(.top, M.nameBelowIcon)
                        // Крупнее стандартного подпись берёт третью строку —
                        // плитка на неё и выросла (`rowTileText`).
                        subtitle(lines: typeSize > .large ? 3 : 2)
                            .padding(.top, 4)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(M.tilePadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Символ вписан в ячейку по большей стороне и прижат к её левому краю:
    /// квадратный `cpu` и широкие `iphone.radiowaves`, `figure.2` одного
    /// оптического размера, широкий не вылезает за ячейку, а левые края
    /// значка и текста совпадают.
    private func icon(_ side: CGFloat) -> some View {
        Image(systemName: item.icon)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: side, maxHeight: side * M.iconHeightShare)
            .foregroundStyle(Color.inkPrimary)
            .frame(width: side, height: side, alignment: .leading)
    }

    /// Длинное название («Вдвоём на устройстве») переносится на вторую строку,
    /// как в кадре 22b, а не ужимается шрифтом — иначе плитки в ряду читаются
    /// разным кеглем.
    private func name(_ size: CGFloat) -> some View {
        Text(item.title)
            .font(.scalable(size: size, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.inkPrimary)
            .lineLimit(isWide ? 1 : 2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func subtitle(lines: Int) -> some View {
        Text(item.subtitle)
            .font(.scalable(size: M.tileSub))
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

struct PadMenuPadPreview1: PreviewProvider {
    static var previews: some View {
        Group {
            ZStack {
                SeaBackground()
                    .ignoresSafeArea()
                PadMenuScreen(isPremium: false, canContinue: true, continueLevel: .hard)
            }
            .preferredColorScheme(.dark)
        }
        .padPreview(.portrait, "Меню iPad · вертикально")
    }
}

struct PadMenuPadPreview2: PreviewProvider {
    static var previews: some View {
        Group {
            ZStack {
                SeaBackground()
                    .ignoresSafeArea()
                PadMenuScreen(isPremium: false, canContinue: false)
            }
            .preferredColorScheme(.dark)
        }
        .padPreview(.landscapeLeft, "Меню iPad · горизонтально")
    }
}

struct PadMenuPadPreview3: PreviewProvider {
    static var previews: some View {
        Group {
            ZStack {
                SeaBackground()
                    .ignoresSafeArea()
                PadMenuScreen(isPremium: true, canContinue: true, continueLevel: .medium)
            }
            .preferredColorScheme(.light)
        }
        .padPreview(.portrait, "Меню iPad · светлая")
    }
}
