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

    /// Строка режима в меню.
    enum ModeRow {
        static let height: CGFloat = 58
        static let radius = Geometry.Radius.button       // 18
        static let horizontalPadding: CGFloat = 13
        static let spacing: CGFloat = 11
        static let iconSize: CGFloat = 30
        static let title = Font.system(size: 15, weight: .semibold, design: .rounded)
        static let subtitle = Font.system(size: 11.5)
        static let lockOpacity: Double = 0.75
    }

    /// Сегментированный переключатель.
    enum Segment {
        static let radius: CGFloat = 13
        static let padding: CGFloat = 3
        static let font = Font.system(size: 12.5, weight: .semibold)
        /// По числам макета сегмент выходил 40 pt — ниже минимальной цели
        /// нажатия 44 pt, которую требует сама спека («везде, кроме клетки
        /// поля»). Высота поднята до 44 за счёт сегмента, а не обоймы:
        /// растягивать обойму значило бы ломать её радиусы.
        static let minHeight: CGFloat = Geometry.Hit.minTarget
        static var minLabelHeight: CGFloat { minHeight - padding * 2 }
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

/// Строка режима в меню: иконка, название, описание одной строкой, справа —
/// замок у закрытого режима. Закрытая строка **выглядит как обычная**: по спеке
/// её не гасят, чтобы режим оставался приглашением, а не запретом.
struct ModeRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var isLocked: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: ControlMetrics.ModeRow.spacing) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(width: ControlMetrics.ModeRow.iconSize,
                           height: ControlMetrics.ModeRow.iconSize)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(ControlMetrics.ModeRow.title)
                        .foregroundStyle(Color.inkPrimary)
                    Text(subtitle)
                        .font(ControlMetrics.ModeRow.subtitle)
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.inkPrimary)
                        .opacity(ControlMetrics.ModeRow.lockOpacity)
                }
            }
            .padding(.horizontal, ControlMetrics.ModeRow.horizontalPadding)
            .frame(height: ControlMetrics.ModeRow.height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassPanel(.g2, radius: ControlMetrics.ModeRow.radius)
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

                VStack(spacing: 8) {
                    ModeRow(icon: "target", title: "Против компьютера",
                            subtitle: "Четыре уровня сложности")
                    ModeRow(icon: "pencil.and.outline", title: "Игра на бумаге",
                            subtitle: "Соперник рядом, поле у него своё")
                    ModeRow(icon: "person.2.fill", title: "Вдвоём на устройстве",
                            subtitle: "Два игрока, один телефон по очереди",
                            isLocked: true)
                }

                Toggle("Звук", isOn: $sound)
                    .font(TypeScale.body)
                    .foregroundStyle(Color.inkPrimary)
                    .seaToggleStyle()
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .glassPanel(.g2, radius: ControlMetrics.ModeRow.radius)

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
