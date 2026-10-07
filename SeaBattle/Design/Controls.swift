//
//  Controls.swift
//  Sea Battle — контролы дизайн-системы, часть первая
//
//  Главная кнопка, строка режима, сегментированный переключатель и тумблер.
//  Вторая часть (`StatBar`, `AchievementRow`, `PlayerCard` с окошками значка и
//  цвета, `LanguageMenu`) — отдельной задачей: они крупнее и нужны только на
//  мета-экранах.
//
//  Правило спеки, которое здесь главное: **главная кнопка одна на всю игру**.
//  Плоских заливок без бевеля в системе нет, поэтому любая заметная кнопка —
//  это `PrimaryButton`, а не своя вёрстка на месте.
//

import SwiftUI

// MARK: - Числа контролов

/// Размеры, которые задаёт спека. Отдельным типом — чтобы сверять с документом
/// тестом, а не перечитывать вёрстку глазами.
enum ControlMetrics {
    /// Главная кнопка.
    enum Button {
        static let radius = Geometry.Radius.button       // 18
        static let minHeight: CGFloat = 50
        static let font = Font.scalable(size: 15.5, weight: .bold, design: .rounded)
        /// Неактивная кнопка гаснет целиком, а не по частям: подложка, кант и
        /// надпись вместе. Так она остаётся кнопкой, просто выключенной.
        static let disabledOpacity: Double = 0.38
        /// Нажатие: кнопка чуть уходит вглубь. При Reduce Motion масштаба нет —
        /// кнопка на миг гаснет (спека 4: масштаб → прозрачность).
        static let pressedScale: CGFloat = 0.98
        static let pressedOpacity: Double = 0.8
        static let haloRadius: CGFloat = 22
        static let shadowRadius: CGFloat = 9             // CSS 0 6 18
        static let shadowOffsetY: CGFloat = 6
        /// Поля надписи — нужны только перенесённой крупной надписи.
        static let textInset: CGFloat = 16
        static let textInsetV: CGFloat = 8
    }

    /// Строка режима в меню. Все размеры приходят из `Geometry.SizeClass`
    /// (таблица 3.3 спеки) — здесь только то, чего в пакете нет.
    enum ModeRow {
        static let lockOpacity: Double = 0.75
        /// Зазор между названием и подписью.
        static let textGap: CGFloat = 2
        /// Поля сверху и снизу у строки, выросшей с Dynamic Type.
        static let grownPadding: CGFloat = 8
    }

    /// Строка выбора `ChoiceRow`, спека 2.13. Числа одни на оба размера:
    /// в таблице 3.3 её нет, а высота растёт по подписи.
    enum ChoiceRow {
        static let radius: CGFloat = 18
        static let minHeight: CGFloat = 58
        static let verticalPadding: CGFloat = 13
        static let horizontalPadding: CGFloat = 14
        static let spacing: CGFloat = 12
        static let iconSize: CGFloat = 30
        static let markSize: CGFloat = 22
        static let textGap: CGFloat = 3
        static let title = Font.scalable(size: 15.5, weight: .semibold, design: .rounded)
        static let subtitle = Font.scalable(size: 12)
        /// Межстрочный 1,4 при кегле 12 — это 16,8 pt, то есть +4,8 к строке.
        static let subtitleLineSpacing: CGFloat = 12 * 0.4
        /// Свечение выбранной строки вместо тени.
        static let selectedGlow: CGFloat = 11        // CSS 0 0 22
    }

    /// Сегментированный переключатель.
    enum Segment {
        static let radius: CGFloat = 13
        static let padding = Geometry.Segment.trackInset
        static let font = Font.scalable(size: 12.5, weight: .semibold)
        /// 44 pt — видимая высота сегмента. В макетах переключатель 40 pt, это
        /// ошибка макета: спека требует 44 pt везде, кроме клетки поля.
        /// Подтверждено дизайном, значение пришло в пакет как
        /// `Geometry.Segment.height`.
        static let minHeight = Geometry.Segment.height
        static var minLabelHeight: CGFloat { minHeight }
    }
}

// MARK: - Главная кнопка

/// Единственная заметная кнопка в игре: стекло с бевелем, латунная подложка,
/// латунный кант, белая надпись. Надпись именно `Ink/Primary`, а не
/// `Ink/OnBrass`: подложка полупрозрачная, тёмная надпись на ней тонет
/// (спека 2.6 в этом месте была исправлена дизайном).
struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled = true
    /// `nil` — по семейству форм; явный радиус — квадраты нижней линии iPad.
    var radius: CGFloat? = nil
    @Environment(\.shapeFamily) private var shapeFamily
    /// Кнопка занимает всё предложенное место по обеим осям — квадрат 104 на
    /// нижней линии iPad (спека 3). Обычная кнопка растёт только в ширину.
    var fillsFrame = false

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius ?? shapeFamily.radius(.control, legacy: ControlMetrics.Button.radius),
                                     style: .continuous)
        return configuration.label
            .font(ControlMetrics.Button.font)
            .foregroundStyle(Color.inkPrimary)
            .shadow(color: .buttonTextShadow, radius: 1, y: 1)
            // Крупный текст переносится — по центру и не вплотную к канту.
            // При стандартном тексте поля внутри высоты 50 и ничего не меняют.
            .multilineTextAlignment(.center)
            .padding(.horizontal, fillsFrame ? 0 : ControlMetrics.Button.textInset)
            .padding(.vertical, fillsFrame ? 0 : ControlMetrics.Button.textInsetV)
            .frame(maxWidth: .infinity, minHeight: ControlMetrics.Button.minHeight,
                   maxHeight: fillsFrame ? .infinity : nil)
            .background {
                shape.fill(LinearGradient.buttonBrass)
                    .background(Material.glassPanel, in: shape)
            }
            // Блик по верхней кромке и тень внутрь снизу — тот же бевель, что у
            // панелей и клеток, только на латуни.
            .overlay {
                shape.strokeBorder(LinearGradient(stops: [.init(color: .buttonSheen, location: 0),
                                                          .init(color: .clear, location: 0.3)],
                                                  startPoint: .top, endPoint: .bottom),
                                   lineWidth: 1)
            }
            .overlay {
                shape.fill(LinearGradient(stops: [.init(color: .clear, location: 0.7),
                                                  .init(color: .buttonShade, location: 1)],
                                          startPoint: .top, endPoint: .bottom))
                    .allowsHitTesting(false)
            }
            .overlay { shape.strokeBorder(Color.roleYou, lineWidth: 1) }
            .clipShape(shape)
            .shadow(color: .buttonShadow,
                    radius: ControlMetrics.Button.shadowRadius,
                    y: ControlMetrics.Button.shadowOffsetY)
            .shadow(color: .roleYouSoft, radius: ControlMetrics.Button.haloRadius)
            // Нажатие: кнопка чуть уходит вглубь. Масштаб, а не смена цвета, —
            // цвет здесь занят ролью.
            .modifier(PressDepth(isPressed: configuration.isPressed))
            .opacity(isEnabled ? 1 : ControlMetrics.Button.disabledOpacity)
    }
}

/// Отклик на нажатие у главной и вторичной кнопки. Отдельным модификатором,
/// потому что `ButtonStyle` сам окружение не читает, а Reduce Motion нужен.
struct PressDepth: ViewModifier {
    let isPressed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed && !reduceMotion ? ControlMetrics.Button.pressedScale : 1)
            .opacity(isPressed && reduceMotion ? ControlMetrics.Button.pressedOpacity : 1)
            .animation(Motion.quick.reduced(reduceMotion), value: isPressed)
    }
}

extension View {
    /// Главная кнопка. `enabled` гасит её целиком; отдельного «выключенного»
    /// набора цветов в системе нет.
    func primaryButton(enabled: Bool = true) -> some View {
        buttonStyle(PrimaryButtonStyle(isEnabled: enabled))
            .disabled(!enabled)
    }
}

// MARK: - Строка режима

/// Кегль символа внутри рамки. Значки в макетах заданы **стороной квадрата**
/// (`iconSlot`), а не кеглем: у разных символов при одном кегле разная высота,
/// и ряд из пяти строк от этого разъезжается. 0,73 — доля, при которой символ
/// заполняет квадрат (22 pt в рамке 30, 19 в рамке 26).
func symbolFontSize(inBox side: CGFloat) -> CGFloat {
    (side * 0.73).rounded()
}

/// Строка режима в меню: иконка, название, описание одной строкой, справа —
/// замок у закрытого режима. Закрытая строка **выглядит как обычная**: по спеке
/// её не гасят, чтобы режим оставался приглашением, а не запретом.
/// Подписи принимаются `LocalizedStringKey`, а не `String`: `Text` переводит
/// только литерал, а строковую переменную показывает как есть, поэтому со
/// `String` строки меню молча остались бы английскими на всех языках.
struct ModeRow: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    var isLocked: Bool = false
    var size: Geometry.SizeClass = .regular
    var action: () -> Void = {}

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.shapeFamily) private var shapeFamily

    var body: some View {
        Button(action: action) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    // AX1–AX5: значок и замок — строкой сверху, текст — под
                    // ними во всю ширину. Сбоку от значка название шло по
                    // слову на строку, а описание обрезалось.
                    VStack(alignment: .leading, spacing: ControlMetrics.ModeRow.textGap) {
                        HStack {
                            iconView
                            Spacer(minLength: 0)
                            lockView
                        }
                        texts
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(spacing: size.modeRowGap) {
                        iconView
                        texts
                            .frame(maxWidth: .infinity, alignment: .leading)
                        lockView
                    }
                }
            }
            .padding(.horizontal, size.modeRowPadding)
            // Не меньше высоты макета, но растёт с Dynamic Type — иначе
            // крупное название обрезалось бы рамкой. Вертикальные поля
            // нужны только выросшей строке: при стандартном тексте (≈ 34 pt)
            // с ними 50 — меньше высоты макета, и она не меняется.
            .padding(.vertical, ControlMetrics.ModeRow.grownPadding)
            .frame(minHeight: size.modeRowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassPanel(.g2, radius: shapeFamily.radius(.control, legacy: size.modeRowRadius))
    }

    private var iconView: some View {
        ScaledSymbol(name: icon, box: size.modeIcon)
            .foregroundStyle(Color.inkPrimary)
    }

    private var texts: some View {
        VStack(alignment: .leading, spacing: ControlMetrics.ModeRow.textGap) {
            Text(title)
                .font(.scalable(size: size.modeName, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.inkPrimary)
            Text(subtitle)
                .font(.scalable(size: size.modeSub))
                .foregroundStyle(Color.inkSecondary)
                .lineLimit(subtitleLines)
                .truncationMode(.tail)
        }
    }

    /// По макету одна строка; крупнее стандартного текста — две, на AX —
    /// сколько нужно: иначе от описания остаётся пара слов.
    private var subtitleLines: Int? {
        if dynamicTypeSize.isAccessibilitySize { return nil }
        return dynamicTypeSize > .large ? 2 : 1
    }

    @ViewBuilder
    private var lockView: some View {
        if isLocked {
            Image(systemName: "lock.fill")
                .font(.scalable(size: symbolFontSize(inBox: size.modeLock)))
                .frame(minHeight: size.modeLock)
                .foregroundStyle(Color.inkPrimary)
                .opacity(ControlMetrics.ModeRow.lockOpacity)
        }
    }
}

// MARK: - Строка выбора

/// Спека 2.13. Отдельный компонент, а не вариант `ModeRow`: `ModeRow` ведёт на
/// другой экран, `ChoiceRow` выбирает одно значение из группы. Для VoiceOver это
/// тоже разные элементы — у выбранной стоит признак «выбрано».
///
/// Подпись занимает **до двух строк без обрезки**, поэтому высота задана
/// минимумом, а не жёстко: на трёх языках длина разная, и подрезанное описание
/// уровня хуже, чем строка выше на 18 pt.
struct ChoiceRow: View {
    let icon: String
    /// Заполненность значка-шкалы (уровни); `nil` — обычный символ.
    var iconValue: Double?
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    var isSelected: Bool = false
    var isLocked: Bool = false
    var action: () -> Void = {}

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.shapeFamily) private var shapeFamily

    var body: some View {
        Button(action: action) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    // AX1–AX5: значок и отметка — строкой сверху, текст под
                    // ними во всю ширину (как у `ModeRow`).
                    VStack(alignment: .leading, spacing: ControlMetrics.ChoiceRow.textGap) {
                        HStack {
                            iconView
                            Spacer(minLength: 0)
                            markView
                        }
                        texts
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(spacing: ControlMetrics.ChoiceRow.spacing) {
                        iconView
                        texts
                            .frame(maxWidth: .infinity, alignment: .leading)
                        // Место справа занято всегда одним и тем же: иначе от
                        // выбора строки текст в ней ехал бы по ширине.
                        markView
                    }
                }
            }
            .padding(.vertical, ControlMetrics.ChoiceRow.verticalPadding)
            .padding(.horizontal, ControlMetrics.ChoiceRow.horizontalPadding)
            .frame(minHeight: ControlMetrics.ChoiceRow.minHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassPanel(.g2, radius: shapeFamily.radius(.control, legacy: ControlMetrics.ChoiceRow.radius),
                    highlight: isSelected ? .selected : .none)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var iconView: some View {
        ScaledSymbol(name: icon, box: ControlMetrics.ChoiceRow.iconSize, variableValue: iconValue)
            .foregroundStyle(Color.inkPrimary)
    }

    private var texts: some View {
        VStack(alignment: .leading, spacing: ControlMetrics.ChoiceRow.textGap) {
            Text(title)
                .font(ControlMetrics.ChoiceRow.title)
                .foregroundStyle(Color.inkPrimary)
            Text(subtitle)
                .font(ControlMetrics.ChoiceRow.subtitle)
                .foregroundStyle(Color.inkSecondary)
                .lineSpacing(ControlMetrics.ChoiceRow.subtitleLineSpacing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var markView: some View {
        // Минимум, а не жёсткая рамка: отметка растёт с текстом строки.
        mark
            .frame(minWidth: ControlMetrics.ChoiceRow.markSize,
                   minHeight: ControlMetrics.ChoiceRow.markSize)
    }

    @ViewBuilder
    private var mark: some View {
        if isSelected {
            checkmark
                .foregroundStyle(Color.roleYou)
        } else if isLocked {
            Image(systemName: "lock.fill")
                .font(.scalable(size: symbolFontSize(inBox: ControlMetrics.ChoiceRow.markSize)))
                .foregroundStyle(Color.inkPrimary)
                .opacity(ControlMetrics.ModeRow.lockOpacity)
        } else {
            // Скрытая галочка, а не `Color.clear`: пустой цвет гибкий по ширине
            // и забирал у текста половину строки — описание невыбранного уровня
            // переносилось в узкую колонку (найдено живьём в R4.6).
            checkmark
                .hidden()
        }
    }

    private var checkmark: some View {
        Image(systemName: "checkmark")
            .font(.scalable(size: symbolFontSize(inBox: ControlMetrics.ChoiceRow.markSize),
                            weight: .semibold))
    }
}

// MARK: - Второстепенная кнопка

/// Спека 2.15: все второстепенные действия — «Перемешать», «Изменить», «Выйти»,
/// «Восстановить покупки», ответы в игре на бумаге. Стекло G2 **без бевеля,
/// блика, тени и латуни**: этим она и тише главной. Правило 6 её не касается —
/// после раунда 4 оно и сформулировано так: латунь и бевель есть только у
/// главной кнопки, а видов кнопок в игре ровно два.
struct SecondaryButtonStyle: ButtonStyle {
    var isEnabled = true
    /// `nil` — по семейству форм; явный радиус — квадраты нижней линии iPad.
    var radius: CGFloat? = nil
    @Environment(\.shapeFamily) private var shapeFamily
    /// См. `PrimaryButtonStyle.fillsFrame`.
    var fillsFrame = false
    /// Высота по спеке 2.15 — 44. Ответы игры на бумаге выше (56 / 52, кадр
    /// `answerBtn`, решение заказчика 30.09 по В29 — до шлифовки дизайна).
    var minHeight: CGFloat = Geometry.SecondaryButton.height
    @Environment(\.bottomChrome) private var chrome
    @Environment(\.inBottomStack) private var inBottomStack

    /// В новом низе (`BottomChrome`) у всех нижних кнопок одна высота.
    private var height: CGFloat {
        chrome == .legacy ? minHeight : max(minHeight, Geometry.Bottom.controlHeight)
    }

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius ?? shapeFamily.radius(.control, legacy: Geometry.SecondaryButton.radius),
                                     style: .continuous)
        return configuration.label
            .font(inBottomStack ? TypeScale.bottomLabel : TypeScale.secondaryButton)
            .foregroundStyle(Color.inkPrimary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, fillsFrame ? 0 : Geometry.SecondaryButton.padding)
            .padding(.vertical, fillsFrame ? 0 : ControlMetrics.Button.textInsetV)
            // В ряду кнопки делят ширину поровну (2.15).
            .frame(maxWidth: .infinity, minHeight: height,
                   maxHeight: fillsFrame ? .infinity : nil)
            .background { shape.fill(LinearGradient.glassPanelFill) }
            .overlay { shape.strokeBorder(Color.glassStroke, lineWidth: 1) }
            .clipShape(shape)
            .modifier(PressDepth(isPressed: configuration.isPressed))
            // Неактивная гаснет целиком, как главная: отдельного набора цветов
            // для выключенного состояния в системе нет.
            .opacity(isEnabled ? 1 : ControlMetrics.Button.disabledOpacity)
    }
}

extension View {
    /// Второстепенная кнопка. Значок в надписи задаётся `Label`; размер значка
    /// и зазор приходят из `Geometry.SecondaryButton`.
    func secondaryButton(enabled: Bool = true) -> some View {
        buttonStyle(SecondaryButtonStyle(isEnabled: enabled))
            .labelStyle(SecondaryLabelStyle())
            .disabled(!enabled)
    }
}

/// Значок 20 pt и зазор 8 — числа спеки 2.15. Своим стилем, а не отступами по
/// месту: кнопок с значком пять экранов, и разъехаться им незачем.
private struct SecondaryLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Geometry.SecondaryButton.gap) {
            configuration.icon
                .font(.scalable(size: symbolFontSize(inBox: Geometry.SecondaryButton.icon)))
                .frame(minHeight: Geometry.SecondaryButton.icon)
            configuration.title
        }
    }
}

// MARK: - Сегментированный переключатель

/// Два-три сегмента в стеклянной обойме. Выбранный — латунный с тёмной
/// надписью (единственное место, где применяется `Ink/OnBrass`: подложка здесь
/// плотная). Текст не сжимается: на трёх языках длина разная, и подрезанная
/// надпись хуже переноса всей строки.
struct SegmentedPick<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.shapeFamily) private var shapeFamily

    var body: some View {
        HStack(spacing: ControlMetrics.Segment.padding) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selection
                Text(option.title)
                    .font(ControlMetrics.Segment.font)
                    .foregroundStyle(isSelected ? Color.inkOnBrass : Color.inkPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity,
                           minHeight: ControlMetrics.Segment.minLabelHeight)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: shapeFamily.radius(.inner, legacy: ControlMetrics.Segment.radius),
                                             style: .continuous)
                                .fill(Color.roleYou)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(Motion.quick.reduced(reduceMotion)) { selection = option.value }
                    }
                    // Без этого VoiceOver читал сегменты простым текстом:
                    // ни что их можно нажать, ни какой выбран.
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                    .accessibilityAction { selection = option.value }
            }
        }
        .padding(ControlMetrics.Segment.padding)
        .glassPanel(.g2, radius: shapeFamily.radius(.control, legacy: ControlMetrics.Segment.radius
                                                        + ControlMetrics.Segment.padding))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Тумблер

extension View {
    /// Системный тумблер в цвете роли. Своего рисовать не стали намеренно:
    /// системный знаком, доступен и сам подстраивается под настройки, а
    /// дизайн-пакет отдельного вида для него не задаёт.
    func seaToggleStyle() -> some View {
        tint(Color.roleYou)
    }
}

// MARK: - Превью

private struct ControlsDemo: View {
    @State private var field = 0
    @State private var sound = true

    var body: some View {
        ZStack {
            SeaBackground()

            VStack(spacing: 16) {
                Button("Start") {}
                    .primaryButton()

                Button("Done") {}
                    .primaryButton(enabled: false)

                SegmentedPick(options: [(0, "Поле противника"), (1, "Ваше поле")],
                              selection: $field)

                // Оба размера строки рядом: малый отличается не только высотой,
                // и в одиночку его отличий не видно.
                VStack(spacing: 8) {
                    ModeRow(icon: "cpu", title: "Single player",
                            subtitle: "Against the computer, four levels")
                    ModeRow(icon: "figure.stand.line.dotted.figure.stand", title: "Two players on one device",
                            subtitle: "Pass the phone around",
                            isLocked: true,
                            size: .compact)
                }

                // Строка выбора в трёх состояниях: подпись в две строки,
                // латунная обводка со свечением у выбранной, замок у закрытой.
                VStack(spacing: 8) {
                    ChoiceRow(icon: LevelChoice.icon, iconValue: 0.5, title: "Medium",
                              subtitle: "Finishes off a ship it has found and never wastes shots on the water around it")
                    ChoiceRow(icon: LevelChoice.icon, iconValue: 0.75, title: "Hard",
                              subtitle: "Shoots every other cell and arranges its own fleet so it takes longer to find",
                              isSelected: true)
                    ChoiceRow(icon: LevelChoice.icon, iconValue: 1, title: "Expert",
                              subtitle: "Works out where the ships most likely are, and hides its own fleet even better",
                              isLocked: true)
                }

                Toggle("Sound", isOn: $sound)
                    .font(TypeScale.body)
                    .foregroundStyle(Color.inkPrimary)
                    .seaToggleStyle()
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .glassPanel(.g2, radius: Geometry.Radius.button)

                Spacer()
            }
            .padding(Geometry.Inset.phoneSide)
            .padding(.top, 60)
        }
    }
}

#Preview("Контролы · тёмная") {
    ControlsDemo()
        .preferredColorScheme(.dark)
}

#Preview("Контролы · светлая") {
    ControlsDemo()
        .preferredColorScheme(.light)
}
