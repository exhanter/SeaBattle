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
                MenuMode(mode: mode, icon: "square.grid.2x2",
                         title: "Paper game",
                         subtitle: "Call out coordinates, the app keeps score")
            case .hotSeat:
                MenuMode(mode: mode, icon: "person.2",
                         title: "Two players on one device",
                         subtitle: "Pass the phone around")
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

/// Раскладка меню в одном из двух размеров. Отдельным типом — по той же
/// причине, что `ControlMetrics` и `BoardMetrics`: на скриншоте разница в две
/// точки не видна, а в ряду из пяти строк уже да.
///
/// **Размеров ровно два, и малый не выводится из большого.** Числа взяты из
/// `screen4Menu` (393) и `screenSmallMenu` (375) в макетах: там меняется всё
/// сразу — поля, зазоры, кегли, радиусы и сторона фотографии. Спека (раздел 3)
/// обещает «панели теряют 2–4 pt», но по кадрам строка теряет 6, а таб-бар 12,
/// поэтому источник здесь — кадры (вопрос В7 в `docs/DESIGN_QUESTIONS.md`).
struct MenuLayout: Equatable, Sendable {
    /// Поля экрана. Это не `Geometry.Inset.phoneSide` (12): тот отступ — для
    /// панелей в бою, которые идут почти во всю ширину.
    let sideInset: CGFloat
    /// Отступ сверху **от безопасной зоны**. В кадрах он задан от края экрана
    /// (66 на 393 при полосе состояния 59, 28 на 375 при 20), здесь пересчитан.
    let topInset: CGFloat
    /// Просвет между содержимым и таб-баром: без него ссылка «Продолжить»
    /// прижимается к деревянному канту панели навигации вплотную.
    let bottomGap: CGFloat
    /// Между блоками экрана: заголовок · фото · список.
    let blockGap: CGFloat
    /// Между строками режимов.
    let rowGap: CGFloat

    /// Заголовок игры. В `TypeScale` такого размера нет — самый крупный
    /// `display` 34 и без трекинга (вопрос В7).
    let titleSize: CGFloat
    /// Трекинг −0,02 em, как в кадрах.
    var titleTracking: CGFloat { titleSize * -0.02 }
    var titleFont: Font { .system(size: titleSize, weight: .semibold, design: .rounded) }

    /// Сторона мата вместе с фотографией: фото показывается **целиком**,
    /// квадратом.
    let heroSide: CGFloat
    /// Деревянный мат вокруг фотографии — единственное место, кроме канта
    /// панелей, где в системе есть дерево (спека, правило 2).
    let matPadding: CGFloat
    let matRadius: CGFloat
    /// Внутренний радиус взят из кадров как отдельное число (17 и 14), а не
    /// посчитан: так тест сверяет, что оба кадра согласованы между собой и что
    /// мы их верно переписали — в обоих это ровно `matRadius − matPadding`.
    let photoRadius: CGFloat
    let matShadowRadius: CGFloat
    let matShadowOffsetY: CGFloat

    let row: ModeRowSize

    /// «Продолжить партию» — ссылка, а не кнопка: главная кнопка в игре одна
    /// (спека, правило 6), и на меню её нет. Зона касания добирается до 44 pt.
    let continueSize: CGFloat
    var continueFont: Font {
        .system(size: continueSize, weight: .semibold, design: .rounded)
    }

    /// 393 pt и шире.
    static let regular = MenuLayout(
        sideInset: 20, topInset: 7, bottomGap: 14, blockGap: 14, rowGap: 8,
        titleSize: 36,
        heroSide: 252, matPadding: 5, matRadius: 22, photoRadius: 17,
        matShadowRadius: 14, matShadowOffsetY: 10,
        row: ControlMetrics.ModeRow.regular,
        continueSize: 15)

    /// 375 pt — iPhone SE / mini.
    static let compact = MenuLayout(
        sideInset: 16, topInset: 8, bottomGap: 12, blockGap: 12, rowGap: 7,
        titleSize: 28,
        heroSide: 170, matPadding: 4, matRadius: 18, photoRadius: 14,
        matShadowRadius: 11, matShadowOffsetY: 8,
        row: ControlMetrics.ModeRow.compact,
        continueSize: 13.5)

    /// Ниже этой ширины экран считается малым (iPhone SE — 375, iPhone 14 — 390).
    static let compactWidthLimit: CGFloat = 390

    static func forWidth(_ width: CGFloat) -> MenuLayout {
        width < compactWidthLimit ? .compact : .regular
    }
}

// MARK: - Экран

struct MenuScreen: View {
    let isPremium: Bool
    let canContinue: Bool
    var onMode: (MenuMode) -> Void = { _ in }
    var onContinue: () -> Void = {}

    var body: some View {
        GeometryReader { proxy in
            let layout = MenuLayout.forWidth(proxy.size.width)

            VStack(spacing: 0) {
                // Прокрутка нужна не всегда: на 393 × 852 заголовок, фотография
                // на 252 pt и пять строк укладываются, на 375 × 667 с
                // фотографией на 170 pt — почти вплотную. Она здесь как
                // страховка: при крупном системном шрифте список всё равно
                // перестанет влезать, и лучше его прокрутить, чем обрезать.
                ScrollView {
                    VStack(spacing: layout.blockGap) {
                        title(layout)

                        hero(layout)

                        modes(layout)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, layout.sideInset)
                    .padding(.top, layout.topInset)
                }
                .scrollBounceBehavior(.basedOnSize)

                // «Продолжить» стоит **вне** прокрутки: это единственный путь
                // назад в незакрытую партию, и уезжать за край экрана ему
                // нельзя. Когда содержимое короче экрана, прокрутка занимает
                // всё оставшееся место, и ссылка оказывается у низа — как в
                // макете.
                if canContinue {
                    continueLink(layout)
                        .padding(.bottom, layout.bottomGap)
                }
            }
        }
    }

    // MARK: Заголовок

    private func title(_ layout: MenuLayout) -> some View {
        // Шрифт системный: по логу дизайна в игре только SF Rounded и SF Pro.
        Text("Sea Battle")
            .font(layout.titleFont)
            .tracking(layout.titleTracking)
            .foregroundStyle(Color.inkPrimary)
            .accessibilityIdentifier("titleMainText")
    }

    // MARK: Фото в деревянном мате

    private func hero(_ layout: MenuLayout) -> some View {
        let photoSide = layout.heroSide - layout.matPadding * 2
        // Фото показывается целиком (`objectFit: contain` в кадрах), поэтому
        // `scaledToFit`, а не `scaledToFill`: сейчас снимок квадратный и разницы
        // нет, но заказчик может заменить арт неквадратным, и тогда обрезка
        // съест корабль молча.
        return Image("war_ship8")
            .resizable()
            .scaledToFit()
            .frame(width: photoSide, height: photoSide)
            .clipShape(RoundedRectangle(cornerRadius: layout.photoRadius,
                                        style: .continuous))
            .padding(layout.matPadding)
            // Мат залит ровным `Chrome/Wood`. В кадрах это градиент от того же
            // тона к более тёмному `#4d3521`, но второго токена дерева в
            // каталоге нет, а придумывать цвет в коде правило 8 запрещает.
            // Вопрос В6 в `docs/DESIGN_QUESTIONS.md`.
            .background {
                RoundedRectangle(cornerRadius: layout.matRadius, style: .continuous)
                    .fill(Color.wood)
            }
            .shadow(color: .glassShadow,
                    radius: layout.matShadowRadius,
                    y: layout.matShadowOffsetY)
            .accessibilityHidden(true)
    }

    // MARK: Пять строк режимов

    private func modes(_ layout: MenuLayout) -> some View {
        VStack(spacing: layout.rowGap) {
            ForEach(MenuMode.all) { item in
                ModeRow(icon: item.icon,
                        title: item.title,
                        subtitle: item.subtitle,
                        isLocked: item.isLocked(isPremium: isPremium),
                        size: layout.row) {
                    onMode(item)
                }
            }
        }
    }

    // MARK: «Продолжить партию»

    private func continueLink(_ layout: MenuLayout) -> some View {
        Button(action: onContinue) {
            Text("Continue game")
                .font(layout.continueFont)
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
