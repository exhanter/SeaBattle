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
    /// Отступ сверху **от безопасной зоны**: в кадрах он задан от края экрана
    /// (66 на 393 при полосе состояния 59, 28 на 375 при 20).
    static func topInset(compact: Bool) -> CGFloat { compact ? 8 : 7 }
}

// MARK: - Экран

struct MenuScreen: View {
    let isPremium: Bool
    let canContinue: Bool
    var onMode: (MenuMode) -> Void = { _ in }
    var onContinue: () -> Void = {}

    var body: some View {
        GeometryReader { proxy in
            let size = Geometry.SizeClass.forWidth(proxy.size.width)

            VStack(spacing: 0) {
                // Прокрутка нужна не всегда: на 393 × 852 заголовок, фотография
                // на 252 pt и пять строк укладываются, на 375 × 667 с
                // фотографией на 170 pt — почти вплотную. Она здесь как
                // страховка: при крупном системном шрифте список всё равно
                // перестанет влезать, и лучше его прокрутить, чем обрезать.
                ScrollView {
                    VStack(spacing: size.menuGap) {
                        title(size)

                        MenuHero(size: size)

                        modes(size)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, size.menuInset)
                    .padding(.top, MenuMetrics.topInset(compact: size.isCompact))
                    // Просвет под последней строкой — до «Продолжить».
                    .padding(.bottom, size.menuGap)
                }
                .scrollBounceBehavior(.basedOnSize)
                // Прокрученный список не заходит под часы: плашки над
                // полосой состояния нет, и строки ложились прямо под цифры.
                .clipped()

                // «Продолжить» стоит **вне** прокрутки: это единственный путь
                // назад в незакрытую партию, и уезжать за край экрана ему
                // нельзя. Когда содержимое короче экрана, прокрутка занимает
                // всё оставшееся место, и ссылка оказывается у низа — как в
                // макете. Просвет до таб-бара — тот же зазор блоков.
                if canContinue {
                    continueLink(size)
                        .padding(.bottom, size.menuGap)
                }
            }
        }
    }

    // MARK: Заголовок

    private func title(_ size: Geometry.SizeClass) -> some View {
        // Шрифт системный: по логу дизайна в игре только SF Rounded и SF Pro.
        Text("Sea Battle")
            .font(TypeScale.gameTitle(compact: size.isCompact))
            .tracking(TypeScale.gameTitleTracking(compact: size.isCompact))
            .foregroundStyle(Color.inkPrimary)
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

// MARK: - Фото в деревянном мате

/// Фото в мате: меню и приветствие первого запуска (кадр `screen13Welcome` —
/// те же 252 pt, тот же мат).
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
