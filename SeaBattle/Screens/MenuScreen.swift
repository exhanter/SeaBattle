//
//  MenuScreen.swift
//  Sea Battle — главный экран (R2.1, шаг 5 порядка сборки)
//
//  Спека 4.2: фото корабля целиком, квадратом в деревянном мате; ниже — один
//  список из пяти равных строк по 58 pt, без групп; под списком — «Продолжить
//  партию», если есть незакрытая.
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
    static var all: [MenuMode] {
        GameMode.allCases.map { mode in
            switch mode {
            case .computer:
                MenuMode(mode: mode, icon: "target",
                         title: "Single player",
                         subtitle: "Against the computer, four levels")
            case .paper:
                MenuMode(mode: mode, icon: "pencil.and.outline",
                         title: "Paper game",
                         subtitle: "The opponent keeps a board of their own")
            case .hotSeat:
                MenuMode(mode: mode, icon: "person.2.fill",
                         title: "Two players",
                         subtitle: "One device, passed around")
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

/// Отдельным типом — по той же причине, что `ControlMetrics` и `BoardMetrics`:
/// на скриншоте разница в две точки не видна, а в ряду из пяти строк уже да.
enum MenuMetrics {
    /// Поля экрана. Это не `Geometry.Inset.phoneSide` (12): тот отступ — для
    /// панелей в бою, которые идут почти во всю ширину, а меню в макете стоит
    /// на 20 pt.
    static let sideInset: CGFloat = 20
    /// Между блоками экрана: заголовок · фото · список · «Продолжить».
    static let blockGap: CGFloat = 16
    /// Между строками режимов.
    static let rowGap: CGFloat = 9

    /// Деревянный мат вокруг фотографии — единственное место, кроме канта
    /// панелей, где в системе есть дерево (спека, правило 2).
    static let matPadding: CGFloat = 5
    static let matRadius = Geometry.Radius.panel          // 22
    /// Внутренний радиус повторяет внешний, уменьшенный на толщину мата: иначе
    /// угол фотографии либо вылезает за мат, либо оставляет в нём просвет.
    static var photoRadius: CGFloat { matRadius - matPadding }
    static let matShadowRadius: CGFloat = 14              // CSS 0 10 28
    static let matShadowOffsetY: CGFloat = 10

    /// Фото показывается **целиком**, квадратом: 252 pt на ширине 393 и
    /// 170 pt на 375 (лог дизайна). Это сторона мата вместе с фотографией.
    static let heroSideWide: CGFloat = 252
    static let heroSideNarrow: CGFloat = 170
    /// Ниже этой ширины экран считается малым (iPhone SE — 375).
    static let narrowWidth: CGFloat = 390

    static func heroSide(forWidth width: CGFloat) -> CGFloat {
        width < narrowWidth ? heroSideNarrow : heroSideWide
    }

    /// «Продолжить партию» — ссылка, а не кнопка: главная кнопка в игре одна
    /// (спека, правило 6), и на меню её нет. Зона касания добирается до 44 pt.
    static let continueFont = Font.system(size: 14, weight: .semibold)
    /// Просвет между содержимым и таб-баром. Без него ссылка «Продолжить»
    /// прижимается к деревянному канту панели навигации вплотную.
    static let bottomGap: CGFloat = 14
}

// MARK: - Экран

struct MenuScreen: View {
    let isPremium: Bool
    let canContinue: Bool
    var onMode: (MenuMode) -> Void = { _ in }
    var onContinue: () -> Void = {}

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                // Прокрутка нужна не всегда: на 393 × 852 заголовок, фотография
                // на 252 pt и пять строк укладываются, на 375 × 667 с
                // фотографией на 170 pt — почти вплотную. Она здесь как
                // страховка: при крупном системном шрифте список всё равно
                // перестанет влезать, и лучше его прокрутить, чем обрезать.
                ScrollView {
                    VStack(spacing: MenuMetrics.blockGap) {
                        title

                        hero(side: MenuMetrics.heroSide(forWidth: proxy.size.width))

                        modes
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, MenuMetrics.sideInset)
                }
                .scrollBounceBehavior(.basedOnSize)

                // «Продолжить» стоит **вне** прокрутки: это единственный путь
                // назад в незакрытую партию, и уезжать за край экрана ему
                // нельзя. Когда содержимое короче экрана, прокрутка занимает
                // всё оставшееся место, и ссылка оказывается у низа — как в
                // макете.
                if canContinue {
                    continueLink
                        .padding(.bottom, MenuMetrics.bottomGap)
                }
            }
        }
    }

    // MARK: Заголовок

    private var title: some View {
        // Шрифт системный — по логу дизайна в игре только SF Rounded и SF Pro.
        // В макете заголовок набран засечным Cormorant Garamond на 46 pt; это
        // расхождение макета с решением по шрифтам, поэтому берётся самый
        // крупный размер шкалы.
        Text("Sea Battle")
            .font(TypeScale.display)
            .foregroundStyle(Color.inkPrimary)
            .accessibilityIdentifier("titleMainText")
    }

    // MARK: Фото в деревянном мате

    private func hero(side: CGFloat) -> some View {
        Image("war_ship8")
            .resizable()
            .scaledToFill()
            .frame(width: side - MenuMetrics.matPadding * 2,
                   height: side - MenuMetrics.matPadding * 2)
            .clipShape(RoundedRectangle(cornerRadius: MenuMetrics.photoRadius,
                                        style: .continuous))
            .padding(MenuMetrics.matPadding)
            // Мат залит ровным `Chrome/Wood`. В макете это градиент от того же
            // тона к более тёмному `#4d3521`, но второго токена дерева в
            // каталоге нет, а придумывать цвет в коде правило 8 запрещает.
            // Вопрос отправлен дизайну вместе с остальными накопленными.
            .background {
                RoundedRectangle(cornerRadius: MenuMetrics.matRadius, style: .continuous)
                    .fill(Color.wood)
            }
            .shadow(color: .glassShadow,
                    radius: MenuMetrics.matShadowRadius,
                    y: MenuMetrics.matShadowOffsetY)
            .accessibilityHidden(true)
    }

    // MARK: Пять строк режимов

    private var modes: some View {
        VStack(spacing: MenuMetrics.rowGap) {
            ForEach(MenuMode.all) { item in
                ModeRow(icon: item.icon,
                        title: item.title,
                        subtitle: item.subtitle,
                        isLocked: item.isLocked(isPremium: isPremium)) {
                    onMode(item)
                }
            }
        }
    }

    // MARK: «Продолжить партию»

    private var continueLink: some View {
        Button(action: onContinue) {
            Text("Continue game")
                .font(MenuMetrics.continueFont)
                .foregroundStyle(Color.roleYou)
                .underline()
                .frame(minHeight: Geometry.Hit.minTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("continueGameButton")
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

/// Малый экран в его настоящем размере: пять строк с фотографией на 170 pt в
/// 667 pt высоты не укладываются, и это единственное место экрана, где нужна
/// прокрутка. Превью показывает её в деле — на канве большого телефона такой
/// раскладки не увидеть.
#Preview("Меню · 375 × 667") {
    ZStack {
        SeaBackground()
        MenuScreen(isPremium: false, canContinue: true)
    }
    .frame(width: 375, height: 667)
    .clipShape(RoundedRectangle(cornerRadius: Geometry.Radius.sheet, style: .continuous))
    .preferredColorScheme(.dark)
}
