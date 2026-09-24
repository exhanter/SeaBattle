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

    /// Строка режима в меню. Размеров два, и малый **не выводится** из
    /// большого: строка теряет 6 pt, значок 4, радиус 2 — это две таблицы из
    /// макетов (`screen4Menu` на 393 и `screenSmallMenu` на 375), а не
    /// коэффициент. Спека в 2.11 называет только 58 pt, числа малого размера
    /// вычитаны из исходника макета (вопрос В7 дизайну).
    enum ModeRow {
        static let lockOpacity: Double = 0.75
        /// 393 pt и шире.
        static let regular = ModeRowSize(
            height: 58, radius: Geometry.Radius.button, horizontalPadding: 13,
            spacing: 11, iconSize: 30, lockSize: 21,
            titleSize: 15, subtitleSize: 11.5)
        /// 375 pt (iPhone SE / mini).
        static let compact = ModeRowSize(
            height: 52, radius: 16, horizontalPadding: 11,
            spacing: 10, iconSize: 26, lockSize: 19,
            titleSize: 14, subtitleSize: 10.5)
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

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: ControlMetrics.Button.radius,
                                     style: .continuous)
        return configuration.label
            .font(ControlMetrics.Button.font)
            .foregroundStyle(Color.inkPrimary)
            .shadow(color: .buttonTextShadow, radius: 1, y: 1)
            .frame(maxWidth: .infinity, minHeight: ControlMetrics.Button.minHeight)
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

/// Один размер строки режима. Значок задан **стороной рамки**, как в макетах
/// (`iconSlot` — квадрат), а не кеглем: у разных символов при одном кегле
/// разная высота, и ряд из пяти строк от этого разъезжается.
struct ModeRowSize: Equatable, Sendable {
    let height: CGFloat
    let radius: CGFloat
    let horizontalPadding: CGFloat
    let spacing: CGFloat
    let iconSize: CGFloat
    let lockSize: CGFloat
    let titleSize: CGFloat
    let subtitleSize: CGFloat

    /// Кегль символа внутри рамки: доля, при которой SF Symbol заполняет
    /// квадрат макета (22 pt в рамке 30, 19 в рамке 26).
    var iconFontSize: CGFloat { (iconSize * 0.73).rounded() }

    var title: Font { .system(size: titleSize, weight: .semibold, design: .rounded) }
    var subtitle: Font { .system(size: subtitleSize) }
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
    var size: ModeRowSize = ControlMetrics.ModeRow.regular
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: size.spacing) {
                Image(systemName: icon)
                    .font(.system(size: size.iconFontSize))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(width: size.iconSize, height: size.iconSize)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(size.title)
                        .foregroundStyle(Color.inkPrimary)
                    Text(subtitle)
                        .font(size.subtitle)
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: (size.lockSize * 0.73).rounded()))
                        .frame(height: size.lockSize)
                        .foregroundStyle(Color.inkPrimary)
                        .opacity(ControlMetrics.ModeRow.lockOpacity)
                }
            }
            .padding(.horizontal, size.horizontalPadding)
            .frame(height: size.height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassPanel(.g2, radius: size.radius)
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
                    ModeRow(icon: "square.grid.2x2", title: "Игра на бумаге",
                            subtitle: "Координаты вслух, счёт ведёт приложение")
                    ModeRow(icon: "person.2", title: "Вдвоём на устройстве",
                            subtitle: "Передавайте телефон по очереди",
                            isLocked: true,
                            size: ControlMetrics.ModeRow.compact)
                }

                Toggle("Звук", isOn: $sound)
                    .font(TypeScale.body)
                    .foregroundStyle(Color.inkPrimary)
                    .seaToggleStyle()
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .glassPanel(.g2, radius: ControlMetrics.ModeRow.regular.radius)

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
