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
        static let font = Font.system(size: 15.5, weight: .bold, design: .rounded)
        /// Неактивная кнопка гаснет целиком, а не по частям: подложка, кант и
        /// надпись вместе. Так она остаётся кнопкой, просто выключенной.
        static let disabledOpacity: Double = 0.38
        static let haloRadius: CGFloat = 22
        static let shadowRadius: CGFloat = 9             // CSS 0 6 18
        static let shadowOffsetY: CGFloat = 6
    }

    /// Строка режима в меню. Все размеры приходят из `Geometry.SizeClass`
    /// (таблица 3.3 спеки) — здесь только то, чего в пакете нет.
    enum ModeRow {
        static let lockOpacity: Double = 0.75
        /// Зазор между названием и подписью.
        static let textGap: CGFloat = 2
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
        static let title = Font.system(size: 15.5, weight: .semibold, design: .rounded)
        static let subtitle = Font.system(size: 12)
        /// Межстрочный 1,4 при кегле 12 — это 16,8 pt, то есть +4,8 к строке.
        static let subtitleLineSpacing: CGFloat = 12 * 0.4
        /// Свечение выбранной строки вместо тени.
        static let selectedGlow: CGFloat = 11        // CSS 0 0 22
    }

    /// Сегментированный переключатель.
    enum Segment {
        static let radius: CGFloat = 13
        static let padding = Geometry.Segment.trackInset
        static let font = Font.system(size: 12.5, weight: .semibold)
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
    var radius: CGFloat = ControlMetrics.Button.radius
    /// Кнопка занимает всё предложенное место по обеим осям — квадрат 104 на
    /// нижней линии iPad (спека 3). Обычная кнопка растёт только в ширину.
    var fillsFrame = false

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return configuration.label
            .font(ControlMetrics.Button.font)
            .foregroundStyle(Color.inkPrimary)
            .shadow(color: .buttonTextShadow, radius: 1, y: 1)
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
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
            .opacity(isEnabled ? 1 : ControlMetrics.Button.disabledOpacity)
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

    var body: some View {
        Button(action: action) {
            HStack(spacing: size.modeRowGap) {
                Image(systemName: icon)
                    .font(.system(size: symbolFontSize(inBox: size.modeIcon)))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(width: size.modeIcon, height: size.modeIcon)

                VStack(alignment: .leading, spacing: ControlMetrics.ModeRow.textGap) {
                    Text(title)
                        .font(.system(size: size.modeName, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.inkPrimary)
                    Text(subtitle)
                        .font(.system(size: size.modeSub))
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: symbolFontSize(inBox: size.modeLock)))
                        .frame(height: size.modeLock)
                        .foregroundStyle(Color.inkPrimary)
                        .opacity(ControlMetrics.ModeRow.lockOpacity)
                }
            }
            .padding(.horizontal, size.modeRowPadding)
            .frame(height: size.modeRowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassPanel(.g2, radius: size.modeRowRadius)
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
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    var isSelected: Bool = false
    var isLocked: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: ControlMetrics.ChoiceRow.spacing) {
                Image(systemName: icon)
                    .font(.system(size: symbolFontSize(inBox: ControlMetrics.ChoiceRow.iconSize)))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(width: ControlMetrics.ChoiceRow.iconSize,
                           height: ControlMetrics.ChoiceRow.iconSize)

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
                .frame(maxWidth: .infinity, alignment: .leading)

                // Место справа занято всегда одним и тем же: иначе от выбора
                // строки текст в ней ехал бы по ширине.
                mark
                    .frame(width: ControlMetrics.ChoiceRow.markSize,
                           height: ControlMetrics.ChoiceRow.markSize)
            }
            .padding(.vertical, ControlMetrics.ChoiceRow.verticalPadding)
            .padding(.horizontal, ControlMetrics.ChoiceRow.horizontalPadding)
            .frame(minHeight: ControlMetrics.ChoiceRow.minHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassPanel(.g2, radius: ControlMetrics.ChoiceRow.radius,
                    highlight: isSelected ? .selected : .none)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var mark: some View {
        if isSelected {
            Image(systemName: "checkmark")
                .font(.system(size: symbolFontSize(inBox: ControlMetrics.ChoiceRow.markSize),
                              weight: .semibold))
                .foregroundStyle(Color.roleYou)
        } else if isLocked {
            Image(systemName: "lock.fill")
                .font(.system(size: symbolFontSize(inBox: ControlMetrics.ChoiceRow.markSize)))
                .foregroundStyle(Color.inkPrimary)
                .opacity(ControlMetrics.ModeRow.lockOpacity)
        } else {
            Color.clear
        }
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
    var radius: CGFloat = Geometry.SecondaryButton.radius
    /// См. `PrimaryButtonStyle.fillsFrame`.
    var fillsFrame = false
    /// Высота по спеке 2.15 — 44. Ответы игры на бумаге выше (56 / 52, кадр
    /// `answerBtn`, решение заказчика 30.09 по В29 — до шлифовки дизайна).
    var minHeight: CGFloat = Geometry.SecondaryButton.height

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return configuration.label
            .font(TypeScale.secondaryButton)
            .foregroundStyle(Color.inkPrimary)
            .padding(.horizontal, fillsFrame ? 0 : Geometry.SecondaryButton.padding)
            // В ряду кнопки делят ширину поровну (2.15).
            .frame(maxWidth: .infinity, minHeight: minHeight,
                   maxHeight: fillsFrame ? .infinity : nil)
            .background { shape.fill(LinearGradient.glassPanelFill) }
            .overlay { shape.strokeBorder(Color.glassStroke, lineWidth: 1) }
            .clipShape(shape)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
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
                .font(.system(size: symbolFontSize(inBox: Geometry.SecondaryButton.icon)))
                .frame(height: Geometry.SecondaryButton.icon)
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
                            RoundedRectangle(cornerRadius: ControlMetrics.Segment.radius,
                                             style: .continuous)
                                .fill(Color.roleYou)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(Motion.quick) { selection = option.value }
                    }
            }
        }
        .padding(ControlMetrics.Segment.padding)
        .glassPanel(.g2, radius: ControlMetrics.Segment.radius
                    + ControlMetrics.Segment.padding)
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
                Button("Старт") {}
                    .primaryButton()

                Button("Готово") {}
                    .primaryButton(enabled: false)

                SegmentedPick(options: [(0, "Поле противника"), (1, "Ваше поле")],
                              selection: $field)

                // Оба размера строки рядом: малый отличается не только высотой,
                // и в одиночку его отличий не видно.
                VStack(spacing: 8) {
                    ModeRow(icon: "target", title: "Одиночная игра",
                            subtitle: "Против компьютера, 4 уровня")
                    ModeRow(icon: "person.2", title: "Вдвоём на устройстве",
                            subtitle: "Передавайте телефон по очереди",
                            isLocked: true,
                            size: .compact)
                }

                // Строка выбора в трёх состояниях: подпись в две строки,
                // латунная обводка со свечением у выбранной, замок у закрытой.
                VStack(spacing: 8) {
                    ChoiceRow(icon: "safari", title: "Средне",
                              subtitle: "Добивает найденный корабль и не тратит выстрелы на воду вокруг него")
                    ChoiceRow(icon: "binoculars", title: "Сложно",
                              subtitle: "Бьёт через клетку и расставляет свой флот так, что его дольше искать",
                              isSelected: true)
                    ChoiceRow(icon: "scope", title: "Эксперт",
                              subtitle: "Считает, где корабли вероятнее всего, и прячет свой флот ещё лучше",
                              isLocked: true)
                }

                Toggle("Звук", isOn: $sound)
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
