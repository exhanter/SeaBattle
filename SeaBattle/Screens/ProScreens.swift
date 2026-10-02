//
//  ProScreens.swift
//  Sea Battle — Pro: короткий лист, полный экран, «Pro активен» (R4.3)
//
//  Спека 4.12, кадры `screen12Locked`, `screen12Paywall`, `screen12ProActive`.
//  Входов два: строка с замком поднимает короткий лист про **этот** режим
//  (`PremiumIntent`), строка «Pro» в настройках — полный экран, а с Pro —
//  страницу «Pro активен» внутри таба. Полный экран открывается и второй
//  кнопкой листа.
//
//  Отступления от кадров — решения R4.3:
//  - **Строка «Pro не даёт баллов» стоит и на полном экране** (спека: «на обоих
//    экранах»), хотя в кадре `screen12Paywall` она только в подписи к кадру.
//    Там она первой строкой мелкого текста внизу: карточкой, как на «Pro
//    активен», она уводила месячный тариф под прокрутку.
//  - **Terms и Privacy — ссылками под пометкой о продлении.** В кадре их нет, а
//    App Store требует их у подписок. Адреса пока заглушки (задача заказчика).
//  - **«Управление в App Store» — только у подписки:** у покупки навсегда
//    управлять нечем, строка вела бы на пустой системный лист.
//  - «Pro активен» оставляет таб-бар, как кошелёк в «Статистике»: это страница
//    таба, а не экран партии.
//  - Подпись «Куплен навсегда · 4 марта 2026» — из права, которое отдаёт
//    StoreKit; у подписки вместо даты покупки — до какого числа оплачено.
//  - Бесплатный пробный период (если он есть у продукта и человеку положен)
//    пишется в строке условия и на кнопке — иначе кнопка «Купить за 4,99»
//    обещала бы списание, которого не будет.
//  - Короткий лист — свой слой поверх экрана, а не системный `.sheet`: на
//    iOS 26 системный лист рисует своё стекло и свои углы, и латунного канта
//    кадра на нём не получить. Закрывается нажатием мимо и жестом вниз.
//

import StoreKit
import SwiftUI

enum ProMetrics {
    // Шапка полного экрана (`sheetHead`)
    static let headTitle: CGFloat = 30
    static let headText: CGFloat = 13.5
    static let headGap: CGFloat = 6
    static let closeBox: CGFloat = 34
    static let closeRadius: CGFloat = 12
    static let closeIcon: CGFloat = 17
    static let headToFeatures: CGFloat = 16
    static let featuresToPlans: CGFloat = 10
    // Строка возможности (`proFeature`)
    static let featuresRadius: CGFloat = 20
    static let featurePaddingV: CGFloat = 9
    static let featureIconBox: CGFloat = 38
    static let featureIconRadius: CGFloat = 13
    static let featureIcon: CGFloat = 20
    static let featureName: CGFloat = 14.5
    static let featureText: CGFloat = 11.5
    static let featureCheck: CGFloat = 20
    static let brassFill: Double = 0.2
    // Условия (`planRow`)
    static let plansGap: CGFloat = 8
    static let capLabel: CGFloat = 10.5
    static let planRadius: CGFloat = 18
    static let planPaddingV: CGFloat = 13
    static let planRadio: CGFloat = 24
    static let planCheck: CGFloat = 14
    static let planTitle: CGFloat = 15
    static let planNote: CGFloat = 11.5
    static let planPrice: CGFloat = 16
    static let badgeText: CGFloat = 10.5
    static let fineText: CGFloat = 10.5
    static let noteText: CGFloat = 12
    static let noteRadius: CGFloat = 16
    // «Pro активен»
    static let statusRadius: CGFloat = 20
    static let statusPadding: CGFloat = 16
    static let statusIconBox: CGFloat = 44
    static let statusIconRadius: CGFloat = 15
    static let statusIcon: CGFloat = 22
    static let statusTitle: CGFloat = 18
    static let statusText: CGFloat = 12.5
    // Короткий лист (`screen12Locked`)
    static let sheetRadius: CGFloat = 28
    static let sheetPaddingV: CGFloat = 18
    static let sheetPaddingH: CGFloat = 16
    static let sheetGap: CGFloat = 12
    static let grabberWidth: CGFloat = 42
    static let grabberHeight: CGFloat = 4
    static let sheetIconBox: CGFloat = 40
    static let sheetIconRadius: CGFloat = 14
    static let sheetTitle: CGFloat = 17
    static let sheetText: CGFloat = 12.5
    static let sheetShadowRadius: CGFloat = 20     // CSS 0 −18 40
    static let sheetShadowY: CGFloat = -18
    /// Жест вниз длиннее этого закрывает лист.
    static let dismissDrag: CGFloat = 90
}

/// Адреса условий и политики. ПЕРЕХОДНОЕ: заглушки, настоящие даёт заказчик.
enum ProLinks {
    static let terms = URL(string: "https://brapps.nl/seabattle/terms")!
    static let privacy = URL(string: "https://brapps.nl/seabattle/privacy")!
}

// MARK: - Что входит в Pro

/// Четыре строки «что входит» — одни и те же на полном экране и на «Pro
/// активен». Названия и значки — те же, что в меню и на экране уровня, чтобы
/// режим узнавался.
struct ProFeature: Identifiable {
    let intent: AppState.PremiumIntent
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    /// Подпись на «Pro активен».
    let unlocked: LocalizedStringKey
    /// Строка листа: «входит в Pro вместе с …» — остальные три.
    let sheetText: LocalizedStringKey

    var id: AppState.PremiumIntent { intent }

    static var all: [ProFeature] { [
        ProFeature(intent: .hotSeat, icon: "person.2",
                   title: "Two players on one device",
                   subtitle: "Play with someone on one iPhone or iPad",
                   unlocked: "Available",
                   sheetText: "This mode is part of Pro, along with nearby play, online play and the Expert level"),
        ProFeature(intent: .nearby, icon: "wifi",
                   title: "Nearby, no internet",
                   subtitle: "Two devices close together, no internet",
                   unlocked: "Available",
                   sheetText: "This mode is part of Pro, along with two players on one device, online play and the Expert level"),
        ProFeature(intent: .online, icon: "globe",
                   title: "Online",
                   subtitle: "Play by invite code or with a random opponent",
                   unlocked: "Available",
                   sheetText: "This mode is part of Pro, along with two players on one device, nearby play and the Expert level"),
        ProFeature(intent: .expert, icon: "scope",
                   title: "Expert level",
                   subtitle: "A computer that finishes off the fleet without mistakes",
                   unlocked: "Available in single player",
                   sheetText: "This level is part of Pro, along with the three modes for playing with people")
    ] }

    static func feature(for intent: AppState.PremiumIntent) -> ProFeature {
        all.first { $0.intent == intent } ?? all[0]
    }
}

/// Квадрат с латунной обводкой под значком — у строк возможностей, у листа и
/// у статуса «Pro активен» разного размера.
private struct BrassIconBox: View {
    let icon: String
    let box: CGFloat
    let radius: CGFloat
    let symbol: CGFloat
    var fill: Double = ProMetrics.brassFill

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ScaledSymbol(name: icon, box: box, glyphBox: symbol)
            .foregroundStyle(Color.inkPrimary)
            .background(Color.roleYou.opacity(fill), in: shape)
            .overlay { shape.strokeBorder(Color.roleYou, lineWidth: 1) }
            .accessibilityHidden(true)
    }
}

struct ProFeatureRow: View {
    let feature: ProFeature
    /// На «Pro активен»: подпись «Доступен» и галочка справа.
    var unlocked = false

    var body: some View {
        HStack(spacing: 12) {
            BrassIconBox(icon: feature.icon, box: ProMetrics.featureIconBox,
                         radius: ProMetrics.featureIconRadius, symbol: ProMetrics.featureIcon)
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.scalable(size: ProMetrics.featureName, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.inkPrimary)
                Text(unlocked ? feature.unlocked : feature.subtitle)
                    .font(.scalable(size: ProMetrics.featureText))
                    .lineSpacing(ProMetrics.featureText * 0.35)
                    .foregroundStyle(Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if unlocked {
                ScaledSymbol(name: "checkmark", box: ProMetrics.featureCheck, weight: .semibold)
                    .foregroundStyle(Color.roleYou)
            }
        }
        .padding(.vertical, ProMetrics.featurePaddingV)
        .padding(.horizontal, ListMetrics.rowPaddingH)
        .accessibilityElement(children: .combine)
    }
}

/// «Баллов Pro не даёт» — строка на обоих экранах (спека 4.12).
private struct ProPointsNote: View {
    /// На полном экране — та же мысль одной строкой мелкого текста: карточкой
    /// она сталкивала месячный тариф под прокрутку на 6,3″.
    static var text: LocalizedStringKey { "Pro gives no points and does not make hints cheaper." }

    var body: some View {
        Text("Pro gives no points and does not make hints cheaper: points are earned by playing, the same for everyone.")
            .font(.scalable(size: ProMetrics.noteText))
            .lineSpacing(ProMetrics.noteText * 0.5)
            .foregroundStyle(Color.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 12)
            .padding(.horizontal, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel(.g2, radius: ProMetrics.noteRadius)
    }
}

// MARK: - Покупка: общее у листа и полного экрана

/// Что сказать под кнопкой после попытки купить или восстановить. Отмена
/// ничего не пишет: человек сам передумал.
enum ProPurchaseNotice: Equatable {
    case pending, failed, nothingToRestore, storeUnavailable

    var text: LocalizedStringKey {
        switch self {
        case .pending: "Waiting for approval. Pro opens as soon as the purchase goes through."
        case .failed: "The purchase did not go through. Please try again."
        case .nothingToRestore: "No Pro purchase was found for this Apple ID."
        case .storeUnavailable: "The App Store cannot be reached right now. Please try again later."
        }
    }

    init?(_ outcome: PurchaseOutcome) {
        switch outcome {
        case .pending: self = .pending
        case .failed: self = .failed
        case .purchased, .cancelled: return nil
        }
    }
}

private struct ProNoticeLine: View {
    let notice: ProPurchaseNotice?

    var body: some View {
        if let notice {
            Text(notice.text)
                .font(.scalable(size: ProMetrics.sheetText))
                .foregroundStyle(Color.inkPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.updatesFrequently)
        }
    }
}

/// Надпись главной кнопки: цена выбранного условия, пробный период, если он
/// положен, крутилка, пока магазин не ответил.
private struct BuyLabel: View {
    let offer: ProOffer?
    let loading: Bool
    /// «Открыть за …» на листе, «Купить за …» на полном экране.
    var unlock = false

    var body: some View {
        if let offer {
            if let trial = offer.freeTrial {
                Text("Try \(trial) free")
            } else if unlock {
                Text("Unlock for \(offer.price)")
            } else {
                Text("Buy for \(offer.price)")
            }
        } else if loading {
            ProgressView().tint(Color.inkPrimary)
        } else {
            Text("Not available")
        }
    }
}

// MARK: - Короткий лист

/// Лист про режим, на который нажали (кадр `screen12Locked`): название, «входит
/// в Pro», цена навсегда на кнопке, полный экран второй кнопкой.
struct ProLockedSheet: View {
    let intent: AppState.PremiumIntent
    let offers: [ProOffer]
    var hasLoaded = true
    var onBuy: (ProPlan) async -> PurchaseOutcome = { _ in .cancelled }
    var onMore: () -> Void = {}

    @State private var working = false
    @State private var notice: ProPurchaseNotice?

    private var feature: ProFeature { .feature(for: intent) }
    private var offer: ProOffer? { .preferred(in: offers) }

    var body: some View {
        VStack(spacing: ProMetrics.sheetGap) {
            Capsule()
                .fill(Color.inkTertiary)
                .frame(width: ProMetrics.grabberWidth, height: ProMetrics.grabberHeight)
                .accessibilityHidden(true)

            HStack(spacing: 11) {
                BrassIconBox(icon: feature.icon, box: ProMetrics.sheetIconBox,
                             radius: ProMetrics.sheetIconRadius, symbol: ProMetrics.featureIcon,
                             fill: 0.22)
                VStack(alignment: .leading, spacing: 3) {
                    Text(feature.title)
                        .font(.scalable(size: ProMetrics.sheetTitle, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.inkPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(feature.sheetText)
                        .font(.scalable(size: ProMetrics.sheetText))
                        .lineSpacing(ProMetrics.sheetText * 0.4)
                        .foregroundStyle(Color.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            ProNoticeLine(notice: notice)

            Button {
                guard let offer else { return }
                Task {
                    working = true
                    notice = ProPurchaseNotice(await onBuy(offer.plan))
                    working = false
                }
            } label: {
                BuyLabel(offer: offer, loading: !hasLoaded, unlock: true)
            }
            .primaryButton(enabled: offer != nil && !working)
            .padding(.top, 2)
            .accessibilityIdentifier("proSheetBuy")

            Button(action: onMore) {
                Label("What else Pro gives", systemImage: "crown")
            }
            .secondaryButton(enabled: !working)
            .accessibilityIdentifier("proSheetMore")
        }
    }
}

/// Слой листа поверх экрана: затемнение, панель снизу с латунным кантом,
/// закрытие нажатием мимо и жестом вниз.
private struct ProSheetLayer<Sheet: View>: View {
    let isPresented: Bool
    let onDismiss: () -> Void
    let sheet: Sheet

    @Environment(\.usesPadLayout) private var usesPadLayout
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drag: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            if isPresented {
                Color.overlayScrim
                    .ignoresSafeArea()
                    .onTapGesture(perform: onDismiss)
                    .accessibilityHidden(true)
                    .transition(.opacity)

                // Нижние углы панели уходят за край экрана: скруглены у кадра
                // только верхние.
                sheet
                    .padding(.vertical, ProMetrics.sheetPaddingV)
                    .padding(.horizontal, ProMetrics.sheetPaddingH)
                    .padding(.bottom, ProMetrics.sheetRadius)
                    .frame(maxWidth: usesPadLayout ? Geometry.Nav.padColumn : .infinity)
                    .glassPanel(.g2, radius: ProMetrics.sheetRadius, wood: .top)
                    .shadow(color: .black.opacity(0.45), radius: ProMetrics.sheetShadowRadius,
                            y: ProMetrics.sheetShadowY)
                    .padding(.bottom, -ProMetrics.sheetRadius)
                    .offset(y: max(drag, 0))
                    .gesture(DragGesture()
                        .onChanged { drag = $0.translation.height }
                        .onEnded { value in
                            if value.translation.height > ProMetrics.dismissDrag { onDismiss() }
                            withAnimation(Motion.quick.reduced(reduceMotion)) { drag = 0 }
                        })
                    // Без `.contain` черта и действие ложатся на детей по
                    // отдельности, и VoiceOver видел только последнюю кнопку.
                    .accessibilityElement(children: .contain)
                    .accessibilityAddTraits(.isModal)
                    .accessibilityAction(.escape, onDismiss)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom))
            }
        }
        .animation(reduceMotion ? Motion.quick : .smooth(duration: 0.3), value: isPresented)
    }
}

extension View {
    /// Короткий лист Pro про режим поверх экрана.
    func proLockedSheet(intent: AppState.PremiumIntent?, onDismiss: @escaping () -> Void,
                        @ViewBuilder sheet: (AppState.PremiumIntent) -> some View) -> some View {
        overlay {
            ProSheetLayer(isPresented: intent != nil, onDismiss: onDismiss,
                          sheet: intent.map(sheet))
        }
    }
}

// MARK: - Полный экран

/// Полный экран Pro (кадр `screen12Paywall`): что покупают, условия, кнопка с
/// ценой выбранного условия, восстановление.
struct ProPaywallScreen: View {
    let offers: [ProOffer]
    var hasLoaded = true
    var onBuy: (ProPlan) async -> PurchaseOutcome = { _ in .cancelled }
    /// Восстановление; вернуть — нашлась ли покупка.
    var onRestore: () async -> Bool = { false }
    var onClose: () -> Void = {}

    @State private var selected: ProPlan?
    @State private var working = false
    @State private var notice: ProPurchaseNotice?

    private var selectedOffer: ProOffer? {
        offers.first { $0.plan == selected } ?? .preferred(in: offers)
    }

    var body: some View {
        VStack(spacing: 0) {
            head
                .padding(.horizontal, Geometry.Nav.stackInset)
                .padding(.top, NavMetrics.titleTopBelowSafeArea)

            ScrollView {
                VStack(spacing: ProMetrics.plansGap) {
                    VStack(spacing: 0) {
                        ForEach(ProFeature.all) { ProFeatureRow(feature: $0) }
                    }
                    .glassPanel(.g2, radius: ProMetrics.featuresRadius)
                    .padding(.bottom, ProMetrics.featuresToPlans)

                    plans
                }
                .padding(.horizontal, Geometry.Nav.stackInset)
                .padding(.top, ProMetrics.headToFeatures)
                .padding(.bottom, ProMetrics.plansGap)
            }
            .scrollBounceBehavior(.basedOnSize)

            bottom
                .padding(.horizontal, Geometry.Nav.stackInset)
                .padding(.top, ProMetrics.plansGap)
                .padBottomFrame()
        }
    }

    private var head: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: ProMetrics.headGap) {
                Text(verbatim: "Pro")
                    .font(.scalable(size: ProMetrics.headTitle, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.inkPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Three modes for playing with people and a fourth computer level. Works on all your devices with the same Apple ID.")
                    .font(.scalable(size: ProMetrics.headText))
                    .lineSpacing(ProMetrics.headText * 0.45)
                    .foregroundStyle(Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: symbolFontSize(inBox: ProMetrics.closeIcon), weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(width: ProMetrics.closeBox, height: ProMetrics.closeBox)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .glassPanel(.g2, radius: ProMetrics.closeRadius)
            // Квадрат 34 меньше 44 — точка нажатия шире самого квадрата.
            .frame(width: Geometry.Hit.minTarget, height: Geometry.Hit.minTarget)
            .contentShape(Rectangle())
            .accessibilityLabel(Text("Close"))
            .accessibilityIdentifier("proClose")
        }
    }

    @ViewBuilder
    private var plans: some View {
        VStack(alignment: .leading, spacing: ProMetrics.plansGap) {
            Text("Choose a plan")
                .font(.scalable(size: ProMetrics.capLabel, weight: .bold))
                .tracking(ProMetrics.capLabel * 0.11)
                .textCase(.uppercase)
                .foregroundStyle(Color.inkTertiary)
                .padding(.leading, ListMetrics.overlineInset)
                .accessibilityAddTraits(.isHeader)

            if offers.isEmpty {
                if hasLoaded {
                    ProNoticeLine(notice: .storeUnavailable)
                        .padding(.vertical, 12)
                } else {
                    ProgressView()
                        .tint(Color.inkPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
            }
            ForEach(offers) { offer in
                ProPlanRow(offer: offer, isSelected: offer.plan == selectedOffer?.plan) {
                    selected = offer.plan
                    notice = nil
                }
            }
        }
    }

    private var bottom: some View {
        VStack(spacing: Geometry.Nav.stackGap) {
            ProNoticeLine(notice: notice)

            Button {
                guard let offer = selectedOffer else { return }
                Task {
                    working = true
                    notice = ProPurchaseNotice(await onBuy(offer.plan))
                    working = false
                }
            } label: {
                BuyLabel(offer: selectedOffer, loading: !hasLoaded)
            }
            .primaryButton(enabled: selectedOffer != nil && !working)
            .accessibilityIdentifier("proBuy")

            Button {
                Task {
                    working = true
                    notice = await onRestore() ? nil : .nothingToRestore
                    working = false
                }
            } label: {
                Label("Restore purchase", systemImage: "arrow.clockwise")
            }
            .secondaryButton(enabled: !working)
            .accessibilityIdentifier("proRestore")

            fineprint
        }
    }

    /// «Pro не даёт баллов», пометка о продлении (только если подписки есть в
    /// продаже) и ссылки.
    private var fineprint: some View {
        VStack(spacing: 3) {
            Text(ProPointsNote.text)
                .foregroundStyle(Color.inkSecondary)
            if offers.contains(where: \.plan.isSubscription) {
                Text("Subscriptions renew automatically; cancel in Apple ID settings.")
            }
            HStack(spacing: 6) {
                Link("Terms of Use", destination: ProLinks.terms)
                Text(verbatim: "·")
                Link("Privacy Policy", destination: ProLinks.privacy)
            }
            .underline()
        }
        .font(.scalable(size: ProMetrics.fineText))
        .lineSpacing(ProMetrics.fineText * 0.45)
        .foregroundStyle(Color.inkTertiary)
        .tint(Color.inkTertiary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Строка условия (`planRow`): кружок выбора, название с меткой, пояснение,
/// цена справа. Выбранная — с латунной обводкой и свечением, как `ChoiceRow`.
struct ProPlanRow: View {
    let offer: ProOffer
    let isSelected: Bool
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                radio
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.scalable(size: ProMetrics.planTitle, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.inkPrimary)
                        if offer.plan == .lifetime { badge }
                    }
                    Text(note)
                        .font(.scalable(size: ProMetrics.planNote))
                        .foregroundStyle(Color.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(verbatim: offer.price)
                    .font(.scalable(size: ProMetrics.planPrice, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? Color.roleYou : Color.inkPrimary)
            }
            .padding(.vertical, ProMetrics.planPaddingV)
            .padding(.horizontal, ListMetrics.rowPaddingH)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassPanel(.g2, radius: ProMetrics.planRadius, highlight: isSelected ? .selected : .none)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("proPlan-\(offer.plan.rawValue)")
    }

    private var title: LocalizedStringKey {
        switch offer.plan {
        case .lifetime: "Forever"
        case .yearly: "Year"
        case .monthly: "Month"
        }
    }

    private var note: LocalizedStringKey {
        if let trial = offer.freeTrial { return "\(trial) free, then renews" }
        switch offer.plan {
        case .lifetime: return "One purchase, no renewal"
        case .yearly:
            if let monthly = offer.monthlyPrice { return "\(monthly) a month, renews" }
            return "Renews every year"
        case .monthly: return "Renews, cancel any time"
        }
    }

    private var radio: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.roleYou.opacity(0.24) : Color.inkPrimary.opacity(0.06))
            Circle()
                .strokeBorder(isSelected ? Color.roleYou : Color.glassStroke, lineWidth: 1)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: symbolFontSize(inBox: ProMetrics.planCheck), weight: .bold))
                    .foregroundStyle(Color.inkPrimary)
            }
        }
        .frame(width: ProMetrics.planRadio, height: ProMetrics.planRadio)
    }

    private var badge: some View {
        Text("best value")
            .font(.scalable(size: ProMetrics.badgeText, weight: .bold))
            .tracking(ProMetrics.badgeText * 0.04)
            .foregroundStyle(Color.inkPrimary)
            .padding(.vertical, 2)
            .padding(.horizontal, 8)
            .background(Color.roleYou.opacity(0.24), in: Capsule())
            .overlay { Capsule().strokeBorder(Color.roleYou, lineWidth: 1) }
    }
}

// MARK: - Pro активен

/// Страница таба «Настройки» с Pro (кадр `screen12ProActive`): статус, что
/// открыто, управление покупкой.
struct ProActiveScreen: View {
    let entitlement: ProEntitlement?
    var onBack: () -> Void = {}
    /// Восстановление; вернуть — нашлась ли покупка.
    var onRestore: () async -> Bool = { true }

    @State private var managing = false
    @State private var working = false
    @State private var notice: ProPurchaseNotice?

    var body: some View {
        VStack(spacing: 0) {
            ScreenTitle(title: "Pro", back: "Settings", onBack: onBack)
                .padding(.top, NavMetrics.titleTopBelowSafeArea)

            ScrollView {
                VStack(spacing: 12) {
                    status

                    ListGroup("Unlocked") {
                        ForEach(ProFeature.all) { ProFeatureRow(feature: $0, unlocked: true) }
                    }

                    ListGroup("Purchase") {
                        if entitlement?.plan.isSubscription == true {
                            ListRow(title: "Manage in the App Store") { managing = true }
                                .accessibilityIdentifier("proManage")
                        }
                        ListRow(title: "Restore purchase") {
                            guard !working else { return }
                            Task {
                                working = true
                                notice = await onRestore() ? nil : .nothingToRestore
                                working = false
                            }
                        }
                        .accessibilityIdentifier("proActiveRestore")
                    }

                    ProNoticeLine(notice: notice)
                    ProPointsNote()
                }
                .padding(.horizontal, Geometry.Nav.stackInset)
                .padding(.top, Geometry.Nav.titleGap * 2)
                .padding(.bottom, 12)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .manageSubscriptionsSheet(isPresented: $managing)
    }

    private var status: some View {
        HStack(spacing: 13) {
            BrassIconBox(icon: "crown", box: ProMetrics.statusIconBox,
                         radius: ProMetrics.statusIconRadius, symbol: ProMetrics.statusIcon,
                         fill: 0.22)
            VStack(alignment: .leading, spacing: 3) {
                Text("Pro is active")
                    .font(.scalable(size: ProMetrics.statusTitle, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.inkPrimary)
                if let line = statusLine {
                    line
                        .font(.scalable(size: ProMetrics.statusText))
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(ProMetrics.statusPadding)
        .glassPanel(.g2, radius: ProMetrics.statusRadius, highlight: .selected)
        .accessibilityElement(children: .combine)
    }

    private static let dateStyle = Date.FormatStyle(date: .long, time: .omitted)

    private var statusLine: Text? {
        guard let entitlement else { return nil }
        switch entitlement.plan {
        case .lifetime:
            // Даты — через `format:`: так их пишет `\.locale` игры, а не системный язык.
            return Text("Bought forever · \(entitlement.purchaseDate, format: Self.dateStyle)")
        case .yearly, .monthly:
            let plan: LocalizedStringKey = entitlement.plan == .yearly ? "Yearly plan" : "Monthly plan"
            guard let until = entitlement.expirationDate else { return Text(plan) }
            return Text(plan) + Text(verbatim: " · ") + Text("paid until \(until, format: Self.dateStyle)")
        }
    }
}

// MARK: - Превью

/// Цены кадра: рубли, как в макете, — проверка, что вёрстка держит длинную
/// цену с пробелом внутри.
private let previewOffers = [
    ProOffer(plan: .lifetime, price: "1 490 ₽"),
    ProOffer(plan: .yearly, price: "790 ₽", monthlyPrice: "66 ₽"),
    ProOffer(plan: .monthly, price: "149 ₽")
]

#Preview("Полный экран") {
    ZStack {
        SeaBackground().ignoresSafeArea()
        ProPaywallScreen(offers: previewOffers)
    }
    .preferredColorScheme(.dark)
}

#Preview("Полный экран · только навсегда") {
    ZStack {
        SeaBackground().ignoresSafeArea()
        ProPaywallScreen(offers: [previewOffers[0]])
    }
    .preferredColorScheme(.dark)
}

#Preview("Полный экран · магазин молчит") {
    ZStack {
        SeaBackground().ignoresSafeArea()
        ProPaywallScreen(offers: [], hasLoaded: true)
    }
    .preferredColorScheme(.dark)
}

#Preview("Лист · вдвоём") {
    ZStack {
        SeaBackground().ignoresSafeArea()
        MenuScreen(isPremium: false, canContinue: false)
    }
    .proLockedSheet(intent: .hotSeat, onDismiss: {}) {
        ProLockedSheet(intent: $0, offers: previewOffers)
    }
    .preferredColorScheme(.dark)
}

#Preview("Pro активен") {
    ZStack {
        SeaBackground().ignoresSafeArea()
        ProActiveScreen(entitlement: ProEntitlement(plan: .lifetime, purchaseDate: .now,
                                                    expirationDate: nil))
    }
    .preferredColorScheme(.dark)
}

#Preview("Pro активен · год") {
    ZStack {
        SeaBackground().ignoresSafeArea()
        ProActiveScreen(entitlement: ProEntitlement(plan: .yearly, purchaseDate: .now,
                                                    expirationDate: .now.addingTimeInterval(86_400 * 300)))
    }
    .preferredColorScheme(.dark)
}
