//
//  MenuScreen.swift
//  Sea Battle — главный экран (R2.1, шаг 5 порядка сборки)
//
//  Спека 4.2: один список из пяти равных строк по 58 pt, без групп; под
//  списком — «Продолжить партию», если есть незакрытая. Фото в деревянном мате
//  заменено артом во всю ширину по образцу iPad (решение заказчика 05.10).
//
//  Экран ничего не делает сам: он получает готовые ответы («куплен ли Pro»,
//  «есть ли незакрытая партия») и отдаёт наружу нажатия. Поэтому его целиком
//  видно в превью во всех состояниях, а решения живут в `AppShell`.
//

import SwiftUI

// MARK: - Строка меню

/// Один режим в списке меню: иконка, название, описание и то, платный он или
/// нет. Список строится из `GameMode.allCases`, а не набирается руками заново:
/// порядок режимов уже зафиксирован в модели (спека 4.2), и разъехаться двум
/// спискам нечем.
struct MenuMode: Identifiable {
    let mode: GameMode
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var id: GameMode { mode }

    /// Бесплатны первые две строки — одиночная игра и игра на бумаге; три
    /// режима игры с людьми под Pro (лог дизайна, «Бесплатно / Pro»).
    var isFree: Bool { mode == .computer || mode == .paper }

    /// Замок — только у платного режима у игрока без Pro. Сама строка при этом
    /// выглядит как обычная: по спеке закрытый режим остаётся приглашением, а
    /// не запретом, поэтому её не гасят.
    func isLocked(isPremium: Bool) -> Bool { !isFree && !isPremium }

    /// Порядок как в `GameMode`: одиночная · бумага · вдвоём · рядом · по сети.
    static var all: [MenuMode] { all(pad: false) }

    /// На iPad «телефон» неверен — там «устройство» (решение заказчика 30.09).
    static func all(pad: Bool) -> [MenuMode] {
        GameMode.allCases.map { mode in
            switch mode {
            case .computer:
                MenuMode(mode: mode, icon: "target",
                         title: "Single player",
                         subtitle: "Against the computer, four levels")
            case .paper:
                MenuMode(mode: mode, icon: "square.grid.2x2",
                         title: "Paper game",
                         subtitle: "Call out coordinates, the app keeps score")
            case .hotSeat:
                MenuMode(mode: mode, icon: "person.2",
                         title: "Two players on one device",
                         subtitle: pad ? "Pass the device around" : "Pass the phone around")
            case .nearby:
                MenuMode(mode: mode, icon: "wifi",
                         title: "Nearby, no internet",
                         subtitle: "Two devices close together")
            case .online:
                MenuMode(mode: mode, icon: "globe",
                         title: "Online",
                         subtitle: "A random opponent or a friend")
            }
        }
    }
}

// MARK: - Числа экрана

/// Числа, которых нет в таблице 3.3 пакета. Всё остальное приходит из
/// `Geometry.SizeClass` — два размера iPhone со всеми величинами сразу.
enum MenuMetrics {
    /// Арт уходит под верхнюю строку режимов — как на iPad
    /// (`Geometry.PadMenu.artOverlap`): строки лежат на растворяющейся части.
    static let artOverlap: CGFloat = Geometry.PadMenu.artOverlap
}

// MARK: - Экран

/// Раскладка по образцу iPad (решение заказчика 05.10, вместо фото в мате из
/// спеки 4.2): зоны считаются **снизу вверх**. Режимы и «Продолжить партию»
/// прижаты к таб-бару — там, куда достаёт большой палец; название лежит на
/// арте над ними; арт во всю ширину от верхнего края экрана забирает всё, что
/// осталось, и растворяется в море. На высоком телефоне арт крупнее, на
/// 375 × 667 — меньше, но строки на любом экране стоят у пальца.
struct MenuScreen: View {
    let isPremium: Bool
    let canContinue: Bool
    var onMode: (MenuMode) -> Void = { _ in }
    var onContinue: () -> Void = {}

    /// Высота нижнего блока — от неё считается высота арта.
    @State private var blockHeight: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let size = Geometry.SizeClass.forWidth(proxy.size.width)
            let top = proxy.safeAreaInsets.top
            // Арт — от края экрана, под полосой состояния: высота считается
            // вместе с ней, а сам он поднят на неё вверх.
            let artHeight = top + max(0, proxy.size.height - blockHeight) + MenuMetrics.artOverlap

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                // При крупном системном шрифте блок перестаёт помещаться — тогда
                // он прокручивается, а не обрезается.
                ViewThatFits(in: .vertical) {
                    block(size)
                    ScrollView {
                        block(size)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { blockHeight = $0 }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(alignment: .top) {
                MenuArt(kind: .phone, width: proxy.size.width, height: artHeight)
                    .offset(y: -top)
            }
        }
    }

    /// Название, пять строк и «Продолжить партию» — одним блоком у низа.
    private func block(_ size: Geometry.SizeClass) -> some View {
        VStack(alignment: .leading, spacing: size.menuGap) {
            title(size)
            modes(size)
            // «Продолжить» — под строками, у самого таб-бара: это единственный
            // путь назад в незакрытую партию. Нет партии — строки опускаются
            // к таб-бару, а не висят над пустым местом.
            if canContinue {
                continueLink(size)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, size.menuInset)
        .padding(.bottom, size.menuGap)
    }

    // MARK: Заголовок

    private func title(_ size: Geometry.SizeClass) -> some View {
        // Шрифт системный: по логу дизайна в игре только SF Rounded и SF Pro.
        // Лежит на арте — с той же тенью, что название на iPad.
        Text("Sea Battle")
            .font(TypeScale.gameTitle(compact: size.isCompact))
            .tracking(TypeScale.gameTitleTracking(compact: size.isCompact))
            .foregroundStyle(Color.inkPrimary)
            .shadow(color: .inkTitleShadow,
                    radius: NavMetrics.titleShadowRadius,
                    y: NavMetrics.titleShadowOffsetY)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("titleMainText")
    }

    // MARK: Пять строк режимов

    private func modes(_ size: Geometry.SizeClass) -> some View {
        VStack(spacing: size.modeListGap) {
            ForEach(MenuMode.all) { item in
                ModeRow(icon: item.icon,
                        title: item.title,
                        subtitle: item.subtitle,
                        isLocked: item.isLocked(isPremium: isPremium),
                        size: size) {
                    onMode(item)
                }
            }
        }
    }

    // MARK: «Продолжить партию»

    private func continueLink(_ size: Geometry.SizeClass) -> some View {
        Button(action: onContinue) {
            Text("Continue game")
                .font(.scalable(size: size.continueText, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.roleYou)
                .underline()
                .frame(minHeight: Geometry.Hit.minTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("continueGameButton")
    }
}

// MARK: - Арт меню

/// Арт меню во всю ширину, без мата: `cover` от **верхнего** края (лишнее
/// срезается снизу, где картинка всё равно растворяется), по горизонтали —
/// по центру. Непрозрачен до 55 % своей высоты, к низу растворяется в море.
/// Один на iPhone и iPad; файлы — свои на каждую раскладку, требования к ним
/// — в `docs/STATUS.md`, раздел «Арт меню».
struct MenuArt: View {
    enum Kind {
        case phone, padPortrait, padLandscape

        var assetName: String {
            switch self {
            case .phone: "MenuArtPhone"
            case .padPortrait: "MenuArtPortrait"
            case .padLandscape: "MenuArtLandscape"
            }
        }
    }

    let kind: Kind
    let width: CGFloat
    let height: CGFloat

    /// Пока файла нет — квадратный снимок `war_ship8`, по центру: от верхнего
    /// края у него срезался бы низ корабля.
    private static let placeholder = "war_ship8"

    var body: some View {
        let hasArt = UIImage(named: kind.assetName) != nil
        Image(hasArt ? kind.assetName : Self.placeholder)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: max(0, height), alignment: hasArt ? .top : .center)
            .clipped()
            .mask {
                LinearGradient(stops: [.init(color: .black, location: 0),
                                       .init(color: .black, location: Geometry.PadMenu.artOpaqueUntil),
                                       .init(color: .clear, location: 1)],
                               startPoint: .top, endPoint: .bottom)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - Фото в деревянном мате

/// Фото в мате — приветствие первого запуска (кадр `screen13Welcome`). В меню
/// с 05.10 вместо него `MenuArt`.
struct MenuHero: View {
    let size: Geometry.SizeClass

    var body: some View {
        let photoSide = size.photo - size.mat * 2
        // Фото показывается целиком (`objectFit: contain` в кадрах), поэтому
        // `scaledToFit`, а не `scaledToFill`: сейчас снимок квадратный и разницы
        // нет, но заказчик может заменить арт неквадратным, и тогда обрезка
        // съест корабль молча.
        return Image("war_ship8")
            .resizable()
            .scaledToFit()
            .frame(width: photoSide, height: photoSide)
            .clipShape(RoundedRectangle(cornerRadius: size.photoInnerRadius,
                                        style: .continuous))
            .padding(size.mat)
            // Единственный градиент дерева в игре: `Chrome/Wood → WoodDeep`.
            // Кант панелей 2 pt остаётся ровным `Chrome/Wood`.
            .background {
                RoundedRectangle(cornerRadius: size.photoRadius, style: .continuous)
                    .fill(LinearGradient.woodMat)
            }
            // Тень мата пакет задаёт числами, а не токеном: альфа приходит
            // отдельным значением, поэтому здесь чёрный с этой альфой.
            .shadow(color: .black.opacity(size.matShadowAlpha),
                    radius: size.matShadowBlur / 2,
                    y: size.matShadowY)
            .accessibilityHidden(true)
    }
}

// MARK: - Превью

#Preview("Меню · тёмная") {
    ZStack {
        SeaBackground()
        MenuScreen(isPremium: false, canContinue: true)
    }
    .preferredColorScheme(.dark)
}

#Preview("Меню · светлая") {
    ZStack {
        SeaBackground()
        MenuScreen(isPremium: false, canContinue: true)
    }
    .preferredColorScheme(.light)
}

#Preview("Меню · Pro, без сохранённой партии") {
    ZStack {
        SeaBackground()
        MenuScreen(isPremium: true, canContinue: false)
    }
    .preferredColorScheme(.dark)
}

/// Малый экран в его настоящем размере — единственный способ увидеть вторую
/// раскладку: на канве большого телефона она не включается, а отличается в ней
/// всё, от полей до кегля подписей.
#Preview("Меню · 375 × 667") {
    ZStack {
        SeaBackground()
        MenuScreen(isPremium: false, canContinue: true)
    }
    .frame(width: 375, height: 667)
    .clipShape(RoundedRectangle(cornerRadius: Geometry.Radius.sheet, style: .continuous))
    .preferredColorScheme(.dark)
}

/// iPhone 12 / 13 mini вместе с таб-баром: компактная раскладка на высоком
/// экране — тот случай, где фото в мате оставляло пустой низ.
#Preview("Меню · 375 × 812 с таб-баром") {
    ZStack {
        SeaBackground()
        VStack(spacing: 0) {
            MenuScreen(isPremium: false, canContinue: true)
            SeaTabBar(selection: .constant(.play), size: .compact)
        }
        .padding(.top, 50)
        .padding(.bottom, 34)
    }
    .frame(width: 375, height: 812)
    .clipShape(RoundedRectangle(cornerRadius: Geometry.Radius.sheet, style: .continuous))
    .preferredColorScheme(.dark)
}
