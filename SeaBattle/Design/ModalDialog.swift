//
//  ModalDialog.swift
//  Sea Battle — окно подтверждения (спека 2.17, макет 18a)
//
//  Пока одно применение: «Выйти из партии?» (3.1). Поверх всего экрана —
//  `Overlay/Scrim`; нажатие по нему **ничего не делает**, окно закрывается
//  только кнопками: случайное касание мимо не должно ни выводить из партии, ни
//  молча закрывать вопрос.
//

import SwiftUI

// MARK: - Числа

enum ModalMetrics {
    static let radius = Geometry.Radius.panelLarge   // 26
    static let screenInset: CGFloat = 24
    static let padding: CGFloat = 20
    static let titleGap: CGFloat = 6
    static let buttonsGap: CGFloat = 16
    /// Межстрочный 1,4 при кегле 13.
    static let messageLineSpacing: CGFloat = 13 * 0.4
    static let scrimFade: Double = 0.180
    static let windowAppear: Double = 0.220
    static let windowStartScale: CGFloat = 0.96
}

// MARK: - Окно

/// Стекло G3: заголовок, пояснение, кнопки столбиком — сверху главная
/// (безопасный выбор), под ней второстепенная.
struct ModalDialog: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let primary: LocalizedStringKey
    let secondary: LocalizedStringKey
    var onPrimary: () -> Void = {}
    var onSecondary: () -> Void = {}

    var body: some View {
        VStack(spacing: ModalMetrics.buttonsGap) {
            VStack(spacing: ModalMetrics.titleGap) {
                Text(title)
                    .font(TypeScale.headline)
                    .foregroundStyle(Color.inkPrimary)
                Text(message)
                    .font(TypeScale.footnote)
                    .lineSpacing(ModalMetrics.messageLineSpacing)
                    .foregroundStyle(Color.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: Geometry.Nav.stackGap) {
                Button {
                    onPrimary()
                } label: {
                    Text(primary)
                }
                .primaryButton()
                .accessibilityIdentifier("modalPrimary")

                Button {
                    onSecondary()
                } label: {
                    Text(secondary)
                }
                .secondaryButton()
                .accessibilityIdentifier("modalSecondary")
            }
        }
        .padding(ModalMetrics.padding)
        .glassPanel(.g3, radius: ModalMetrics.radius)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

// MARK: - Показ поверх экрана

extension View {
    /// Затемнение и окно поверх всего экрана. Появление: затемнение
    /// прозрачностью за 180 мс, окно прозрачностью и масштабом 0,96 → 1 за
    /// 220 мс; при Reduce Motion — только прозрачность.
    func modalDialog<Dialog: View>(isPresented: Bool,
                                   @ViewBuilder dialog: () -> Dialog) -> some View {
        overlay { ModalPresenter(isPresented: isPresented, dialog: dialog()) }
    }
}

private struct ModalPresenter<Dialog: View>: View {
    let isPresented: Bool
    let dialog: Dialog

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if isPresented {
                Color.overlayScrim
                    .ignoresSafeArea()
                    // Перехват касаний: под окном стрелять нельзя, а само
                    // затемнение окно не закрывает (2.17).
                    .contentShape(Rectangle())
                    .onTapGesture {}
                    .accessibilityHidden(true)
                    .transition(.opacity.animation(.easeOut(duration: ModalMetrics.scrimFade)))
            }
            if isPresented {
                dialog
                    // iPad: не шире 400 (2.17 после раунда 7) — вопрос и две
                    // кнопки, на всю ширину окно растягивалось бы, как лист.
                    // На iPhone ограничение не срабатывает: он уже.
                    .frame(maxWidth: Geometry.Nav.padDialog)
                    .padding(.horizontal, ModalMetrics.screenInset)
                    .transition(windowTransition)
            }
        }
        .animation(.easeOut(duration: ModalMetrics.windowAppear), value: isPresented)
    }

    private var windowTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .scale(scale: ModalMetrics.windowStartScale))
    }
}

// MARK: - Выход из партии

/// Тексты окна выхода (таблица 2.17): у сетевой партии выход — это сдача.
enum LeaveMatchKind: Sendable {
    case offline
    case network

    var title: LocalizedStringKey {
        switch self {
        case .offline: "Leave the match?"
        case .network: "Surrender and leave?"
        }
    }

    var message: LocalizedStringKey {
        switch self {
        case .offline: "The game is saved. You can continue it from the menu."
        case .network: "The match will count as your loss and your opponent's win."
        }
    }

    var confirm: LocalizedStringKey {
        switch self {
        case .offline: "Leave"
        case .network: "Surrender and leave"
        }
    }
}

extension ModalDialog {
    /// «Выйти из партии?»: главная кнопка — «Остаться», случайное касание
    /// «Меню» не должно стоить партии.
    static func leaveMatch(_ kind: LeaveMatchKind,
                           onStay: @escaping () -> Void,
                           onLeave: @escaping () -> Void) -> ModalDialog {
        ModalDialog(title: kind.title, message: kind.message,
                    primary: "Stay", secondary: kind.confirm,
                    onPrimary: onStay, onSecondary: onLeave)
    }
}

// MARK: - Превью

private struct ModalDemo: View {
    let kind: LeaveMatchKind

    var body: some View {
        ZStack {
            SeaBackground()
            BoardView(cells: [BoardCellState](repeating: .water, count: 100),
                      role: .foe, metrics: BoardMetrics(cell: Geometry.Cell.iPhone))
        }
        .modalDialog(isPresented: true) {
            ModalDialog.leaveMatch(kind, onStay: {}, onLeave: {})
        }
    }
}

#Preview("Окно · выход · тёмная") {
    ModalDemo(kind: .offline)
        .preferredColorScheme(.dark)
}

#Preview("Окно · выход · светлая") {
    ModalDemo(kind: .offline)
        .preferredColorScheme(.light)
}

#Preview("Окно · сдача") {
    ModalDemo(kind: .network)
        .preferredColorScheme(.dark)
}
