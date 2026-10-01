//
//  ListControls.swift
//  Sea Battle — списки мета-экранов (R4.1)
//
//  Группа строк с подписью, строка со значением и шевроном, карточка пустого
//  состояния. В макетах это `setGroup`, `setRow` / `valueChev` и `emptyState`:
//  ими собраны статистика, кошелёк, сброс и настройки, поэтому они вынесены
//  из экранов. Чисел в пакете токенов для них нет — они в `ListMetrics`.
//

import SwiftUI

enum ListMetrics {
    // Группа (`setGroup`)
    static let overline: CGFloat = 11
    static let overlineTracking: CGFloat = 11 * 0.11
    static let overlineInset: CGFloat = 4
    static let groupGap: CGFloat = 6
    static let groupRadius: CGFloat = 18
    // Строка (`setRow`, `valueChev`)
    static let rowPaddingV: CGFloat = 11
    static let rowPaddingH: CGFloat = 14
    static let rowTitle: CGFloat = 14.5
    static let rowSubtitle: CGFloat = 11.5
    static let rowValue: CGFloat = 13.5
    static let chevron: CGFloat = 18
    static let valueGap: CGFloat = 7
    // Пустое состояние (`emptyState`)
    static let emptyRadius: CGFloat = 22
    static let emptyPaddingV: CGFloat = 26
    static let emptyPaddingH: CGFloat = 20
    static let emptyGap: CGFloat = 12
    static let emptyIconBox: CGFloat = 58
    static let emptyIconRadius: CGFloat = 20
    static let emptyIcon: CGFloat = 26
    static let emptyTitle: CGFloat = 19
    static let emptyText: CGFloat = 13.5
    static let emptyTextWidth: CGFloat = 280
}

// MARK: - Группа

/// Подпись капителью и стеклянная карточка G2; строки разделены волосяной
/// линией с полями строки. Разделители ставит группа, а не строки: строка не
/// знает, первая ли она.
struct ListGroup<Content: View>: View {
    let title: LocalizedStringKey?
    @ViewBuilder var content: Content

    init(_ title: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ListMetrics.groupGap) {
            if let title {
                Text(title)
                    .font(.system(size: ListMetrics.overline, weight: .bold))
                    .tracking(ListMetrics.overlineTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.leading, ListMetrics.overlineInset)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: 0) {
                Group(subviews: content) { rows in
                    ForEach(rows.indices, id: \.self) { index in
                        if index > 0 { ListDivider() }
                        rows[index]
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .glassPanel(.g2, radius: ListMetrics.groupRadius)
        }
    }
}

/// Волосяная линия между строками группы.
struct ListDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.glassStroke)
            .frame(height: 1)
            .padding(.horizontal, ListMetrics.rowPaddingH)
    }
}

// MARK: - Строка

/// Строка группы: название, под ним необязательное пояснение, справа значение
/// и шеврон. С действием — кнопка во всю строку; без действия шеврона нет:
/// он обещает переход, а переходить некуда (так у «Витрины · скоро»).
struct ListRow: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    var value: Text?
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) { label(chevron: true) }
                .buttonStyle(.plain)
        } else {
            label(chevron: false)
        }
    }

    private func label(chevron: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: ListMetrics.rowTitle, weight: .medium))
                    .foregroundStyle(Color.inkPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: ListMetrics.rowSubtitle))
                        .foregroundStyle(Color.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: ListMetrics.valueGap) {
                if let value {
                    value
                        .font(.system(size: ListMetrics.rowValue))
                        .monospacedDigit()
                        .foregroundStyle(Color.inkSecondary)
                }
                if chevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: symbolFontSize(inBox: ListMetrics.chevron), weight: .semibold))
                        .foregroundStyle(Color.inkTertiary)
                        .frame(height: ListMetrics.chevron)
                }
            }
        }
        .padding(.vertical, ListMetrics.rowPaddingV)
        .padding(.horizontal, ListMetrics.rowPaddingH)
        .frame(minHeight: Geometry.Hit.minTarget)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Пустое состояние

/// Спека 4.10: одна карточка со значком, фразой о том, чем экран заполнится,
/// и действием. Вместо нулей в таблице — одно понятное состояние.
struct EmptyStateCard<Action: View>: View {
    let icon: String
    let title: LocalizedStringKey
    let text: LocalizedStringKey
    @ViewBuilder var action: Action

    var body: some View {
        VStack(spacing: ListMetrics.emptyGap) {
            Image(systemName: icon)
                .font(.system(size: symbolFontSize(inBox: ListMetrics.emptyIcon)))
                .foregroundStyle(Color.inkPrimary)
                .frame(width: ListMetrics.emptyIconBox, height: ListMetrics.emptyIconBox)
                .background {
                    RoundedRectangle(cornerRadius: ListMetrics.emptyIconRadius, style: .continuous)
                        .fill(Color.glassFill2)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: ListMetrics.emptyIconRadius, style: .continuous)
                        .strokeBorder(Color.roleYou, lineWidth: 1)
                }
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: ListMetrics.emptyTitle, weight: .bold, design: .rounded))
                .foregroundStyle(Color.inkPrimary)
            Text(text)
                .font(.system(size: ListMetrics.emptyText))
                .lineSpacing(ListMetrics.emptyText * 0.5)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: ListMetrics.emptyTextWidth)
                .fixedSize(horizontal: false, vertical: true)
            action
        }
        .padding(.vertical, ListMetrics.emptyPaddingV)
        .padding(.horizontal, ListMetrics.emptyPaddingH)
        .frame(maxWidth: .infinity)
        .glassPanel(.g2, radius: ListMetrics.emptyRadius)
    }
}

extension EmptyStateCard where Action == EmptyView {
    init(icon: String, title: LocalizedStringKey, text: LocalizedStringKey) {
        self.init(icon: icon, title: title, text: text) { EmptyView() }
    }
}

// MARK: - Превью

#Preview("Списки") {
    ZStack {
        SeaBackground()
            .ignoresSafeArea()
        VStack(spacing: 14) {
            ListGroup("Группа") {
                ListRow(title: "Строка со значением", value: Text(verbatim: "126"), action: {})
                ListRow(title: "Без перехода", subtitle: "Пояснение под строкой", value: Text("Soon"))
            }
            EmptyStateCard(icon: "chart.bar", title: "No games yet",
                           text: "Play your first one — wins, the win rate and the split by mode will appear here.") {
                Button("Play") {}
                    .primaryButton()
            }
        }
        .padding(12)
    }
    .preferredColorScheme(.dark)
}
