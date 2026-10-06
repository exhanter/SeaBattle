//
//  NavigationChrome.swift
//  Sea Battle — верх и низ экранов без таб-бара
//
//  Спека 2.11–2.12 и правило 3.1. Таб-бар стоит **только** на корнях трёх
//  табов; всё, что начинается с выбора режима в меню, — это партия, и там
//  сверху `ScreenTitle`, снизу `BottomStack` с «Меню» в последнем ряду.
//
//  Компоненты пришли в пакет в раунде 3: в макетах они использовались 19–20
//  раз, но в спеке их не было вовсе, поэтому R2.1 собрал меню без них.
//

import SwiftUI

// MARK: - Заголовок экрана

/// Заголовок с необязательной строкой возврата. Подпись возврата — это
/// **название экрана, куда он ведёт**, а не слово «Назад»: игрок должен видеть,
/// куда попадёт, до нажатия.
///
/// Тень заголовка рисуется **всегда**: в тёмной теме токен `Ink/TitleShadow`
/// прозрачный, в светлой держит белый текст на светлом море. Ветки по теме тут
/// нет и быть не может (правило про `colorScheme`).
struct ScreenTitle: View {
    let title: LocalizedStringKey
    /// Название экрана, куда ведёт возврат. `nil` — строки возврата нет: так на
    /// корнях табов, в бою (оттуда выходят через «Меню») и в онбординге.
    var back: LocalizedStringKey?
    /// Подсказка фазы под названием (спека 2.11, раунд 4). До двух строк, без
    /// обрезки. **Текст ошибок сюда не пишется**: об ошибке говорит
    /// `WarningLine` под полем, рядом с розовым кораблём, — а написанное дважды
    /// читается как две разные беды.
    var subtitle: LocalizedStringKey?
    var onBack: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: Geometry.Nav.titleGap) {
            if let back {
                Button(action: onBack) {
                    HStack(spacing: NavMetrics.backGap) {
                        Image(systemName: "chevron.left")
                            .font(.scalable(size: symbolFontSize(inBox: NavMetrics.backChevron),
                                          weight: .semibold))
                        Text(back)
                            .font(.scalable(size: NavMetrics.backText, weight: .semibold))
                    }
                    .foregroundStyle(Color.roleYou)
                    // Цель нажатия — вся строка целиком, не один шеврон.
                    .frame(minHeight: Geometry.Hit.minTarget, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Text(title)
                .font(TypeScale.screenTitle)
                .tracking(TypeScale.screenTitleTracking)
                .foregroundStyle(Color.inkPrimary)
                .shadow(color: .inkTitleShadow,
                        radius: NavMetrics.titleShadowRadius,
                        y: NavMetrics.titleShadowOffsetY)

            if let subtitle {
                Text(subtitle)
                    .font(TypeScale.screenSubtitle)
                    .lineSpacing(NavMetrics.subtitleLineSpacing)
                    .foregroundStyle(Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .inkTitleShadow,
                            radius: NavMetrics.titleShadowRadius,
                            y: NavMetrics.titleShadowOffsetY)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Geometry.Nav.titleInset)
    }
}

/// То, чего нет в пакете токенов: кегли и мелочи строки возврата.
enum NavMetrics {
    static let backChevron: CGFloat = 19
    static let backText: CGFloat = 14
    static let backGap: CGFloat = 7
    static let titleShadowRadius: CGFloat = 2.5   // CSS 0 1 5
    static let titleShadowOffsetY: CGFloat = 1
    /// Межстрочный 1,4 при кегле 12,5 — это +40 % к строке.
    static let subtitleLineSpacing: CGFloat = 12.5 * 0.4
    static let menuIcon: CGFloat = 21
    static let menuText: CGFloat = 13.5
    static let menuGap: CGFloat = 8
    /// Значок кнопки-круга «Меню» в доке: кегль 19 — как у значков таб-бара
    /// (18) и подсказки рядом. Прежние 15 строки «Меню» в круге 50 читались
    /// мелко (замечание заказчика 06.10).
    static let menuButtonIcon: CGFloat = 26
    /// Верх заголовка отсчитан от края экрана (68 pt под полосой состояния),
    /// а не от безопасной зоны — как в макетах. Полоса на современных iPhone
    /// ≈ 59 pt, отсюда остаток.
    static let titleTopBelowSafeArea: CGFloat = Geometry.Nav.titleTop - 59
}

// MARK: - Низ экрана

/// Строка «Меню» — выход из партии. Правая половина в первой версии пуста: там
/// стояло «ⓘ Правила», и по решению раунда 3 экрана правил в первой версии нет,
/// а строку не перестраивают — вход вернётся на это же место.
struct NavRow: View {
    var onMenu: () -> Void = {}
    @Environment(\.shapeFamily) private var shapeFamily

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onMenu) {
                HStack(spacing: NavMetrics.menuGap) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: symbolFontSize(inBox: NavMetrics.menuIcon),
                                      weight: .semibold))
                        // Системная подпись символа — «Drag»: VoiceOver
                        // читал бы её рядом с «Меню».
                        .accessibilityHidden(true)
                    Text("Menu")
                        .font(.system(size: NavMetrics.menuText, weight: .semibold,
                                      design: .rounded))
                }
                .foregroundStyle(Color.inkPrimary)
                // Цель нажатия — вся левая половина строки (спека 2.12).
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("navMenuButton")
            .accessibilityShowsLargeContentViewer {
                Label("Menu", systemImage: "line.3.horizontal")
            }

            // Пустая половина занимает место, а не сжимается: иначе «Меню»
            // уедет в середину, и строка перестроится, когда правила появятся.
            Color.clear
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Geometry.Nav.rowPadding)
        .frame(height: Geometry.Nav.rowHeight)
        .glassPanel(.g2, radius: shapeFamily.radius(.control, legacy: Geometry.Nav.rowRadius), wood: .top)
    }
}

/// Колонка действий у нижнего края: вспомогательные действия фазы → главная
/// кнопка → «Меню». **«Меню» всегда в последнем ряду**, поэтому оно часть
/// контейнера, а не его содержимого: забыть его или поставить не туда нельзя.
/// iPhone — док: последний ряд в стеклянной панели размером с таб-бар,
/// «Меню» в нём слева (06.10). iPad — строка `NavRow` под действиями.
struct BottomStack<Content: View>: View {
    var onMenu: () -> Void = {}
    @ViewBuilder var content: Content

    @Environment(\.bottomChrome) private var chrome
    @Environment(\.shapeFamily) private var shapeFamily

    var body: some View {
        Group {
            switch chrome {
            case .legacy:
                VStack(spacing: Geometry.Nav.stackGap) {
                    content
                    NavRow(onMenu: onMenu)
                }
            case .dock:
                // Последний ряд содержимого — главный: он ложится в док рядом
                // с «Меню», остальные ряды — над доком.
                Group(subviews: content) { rows in
                    VStack(spacing: Geometry.Nav.stackGap) {
                        ForEach(rows.dropLast()) { $0 }
                        dock(rows.last)
                    }
                }
            }
        }
        .environment(\.inBottomStack, chrome == .dock)
        .padding(.horizontal, Geometry.Nav.stackInset)
        .padBottomFrame()
    }

    private func dock(_ row: Subview?) -> some View {
        HStack(spacing: Geometry.Nav.stackGap) {
            // Только значок, как у подсказки: подпись «Меню» в доке не
            // помещалась (замечание заказчика 06.10).
            MenuDockButton(onMenu: onMenu)
            row
        }
        // Минимум, а не высота: с крупным шрифтом кнопки растут. Во всю
        // ширину — и тогда, когда в ряду одно «Меню» («Рядом» во время поиска).
        .frame(maxWidth: .infinity, minHeight: Geometry.Bottom.controlHeight, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(Geometry.Bottom.dockPadding)
        .glassPanel(.g2, radius: shapeFamily.radius(.dock, legacy: Geometry.SizeClass.regular.tabRadius),
                    wood: .top)
    }
}

/// «Меню» кругом в доке. Подписи нет — её говорит VoiceOver и показывает
/// крупный просмотр.
private struct MenuDockButton: View {
    var onMenu: () -> Void
    @Environment(\.shapeFamily) private var shapeFamily

    var body: some View {
        Button(action: onMenu) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: symbolFontSize(inBox: NavMetrics.menuButtonIcon), weight: .semibold))
                .foregroundStyle(Color.inkPrimary)
                // Круг, а не столбик: с крупным шрифтом ряд дока растёт, а
                // «Меню» остаётся кругом 50 по центру ряда.
                .frame(width: Geometry.Bottom.controlHeight, height: Geometry.Bottom.controlHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassPanel(.g2, radius: shapeFamily.radius(.control, legacy: Geometry.Nav.rowRadius))
        .accessibilityLabel(Text("Menu"))
        .accessibilityIdentifier("navMenuButton")
        .accessibilityShowsLargeContentViewer {
            Label("Menu", systemImage: "line.3.horizontal")
        }
    }
}

extension View {
    /// Низ нижнего ряда. iPhone — 10 pt над безопасной зоной; iPad — на рамке
    /// 24 pt от края экрана (спека 3 после раунда 7), а не от безопасной зоны.
    func padBottomFrame() -> some View {
        modifier(BottomFrameModifier())
    }
}

private struct BottomFrameModifier: ViewModifier {
    @Environment(\.usesPadLayout) private var usesPadLayout

    func body(content: Content) -> some View {
        if usesPadLayout {
            content
                .padding(.bottom, Geometry.Inset.padFrame)
                .ignoresSafeArea(edges: .bottom)
        } else {
            content
                .padding(.bottom, Geometry.Nav.stackBottom)
        }
    }
}

// MARK: - Предупреждение

/// Спека 2.16. **Строка текста, а не капсула:** фон, рамка и свечение обещают
/// нажатие, а нажимать тут нечего — заказчик отклонил капсулу именно за это.
/// Появляется и гаснет вместе с розовым кораблём.
struct WarningLine: View {
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: Geometry.Warning.gap) {
            Image(systemName: "exclamationmark.triangle")
                .font(.scalable(size: symbolFontSize(inBox: Geometry.Warning.icon)))
                .frame(minHeight: Geometry.Warning.icon)
                .foregroundStyle(Color.warnIcon)
            Text(text)
                .font(TypeScale.warning)
                .foregroundStyle(Color.warnText)
                // Перенос, а не обрезка: на трёх языках длина разная, а
                // недосказанное предупреждение хуже двух строк.
                .fixedSize(horizontal: false, vertical: true)
        }
        .shadow(color: .inkTitleShadow,
                radius: NavMetrics.titleShadowRadius,
                y: NavMetrics.titleShadowOffsetY)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Превью

private struct NavigationChromeDemo: View {
    var body: some View {
        ZStack {
            SeaBackground()

            VStack(spacing: 0) {
                ScreenTitle(title: "Single player", back: "Play")
                    .padding(.top, NavMetrics.titleTopBelowSafeArea)

                Spacer()

                BottomStack {
                    Button(action: {}) {
                        Text("Shuffle")
                    }
                    .primaryButton()
                }
            }
        }
    }
}

#Preview("Верх и низ · тёмная") {
    NavigationChromeDemo()
        .preferredColorScheme(.dark)
}

#Preview("Верх и низ · светлая") {
    NavigationChromeDemo()
        .preferredColorScheme(.light)
}
