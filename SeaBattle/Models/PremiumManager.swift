//
//  PremiumManager.swift
//  SeaBattle
//
//  Phase 2: the single source of truth for premium entitlement, on StoreKit 2.
//  R4.3: Pro is sold three ways — a one-time purchase «forever» (the default,
//  a non-consumable), a yearly and a monthly auto-renewable subscription. This
//  object loads the customer's current entitlements, listens for transaction
//  updates (renewals, purchases made on other devices, revocations) and
//  exposes `isPremium` for the rest of the app to gate premium features on.
//

import Foundation
import Observation
import StoreKit

/// Three ways to buy Pro, in the order the paywall lists them (spec 4.12):
/// «forever» first — it is selected by default and stands on the button.
enum ProPlan: String, CaseIterable, Sendable {
    case lifetime, yearly, monthly

    /// Must match the StoreKit configuration file and App Store Connect.
    var productID: String { "nl.brapps.SeaBattle.premium.\(rawValue)" }

    init?(productID: String) {
        guard let plan = Self.allCases.first(where: { $0.productID == productID }) else { return nil }
        self = plan
    }

    var isSubscription: Bool { self != .lifetime }
}

/// What the customer owns right now — for the «Pro is active» screen.
struct ProEntitlement: Equatable, Sendable {
    let plan: ProPlan
    let purchaseDate: Date
    /// `nil` for the purchase «forever».
    let expirationDate: Date?

    /// One transaction as `Transaction.currentEntitlements` reports it — a
    /// plain value, so the choice below is testable without StoreKit.
    struct Record: Sendable {
        let productID: String
        let purchaseDate: Date
        var expirationDate: Date?
        var revocationDate: Date?
    }

    /// The entitlement to show. «Forever» wins over any subscription: a
    /// customer who bought it and still has a running subscription owns Pro
    /// for good. Among subscriptions the one that lasts longest wins.
    /// Refunded, expired and unknown products are not an entitlement.
    static func best(of records: [Record], now: Date = .now) -> ProEntitlement? {
        let valid = records.compactMap { record -> ProEntitlement? in
            guard let plan = ProPlan(productID: record.productID),
                  record.revocationDate == nil,
                  (record.expirationDate ?? .distantFuture) > now else { return nil }
            return ProEntitlement(plan: plan, purchaseDate: record.purchaseDate,
                                  expirationDate: plan == .lifetime ? nil : record.expirationDate)
        }
        if let lifetime = valid.first(where: { $0.plan == .lifetime }) { return lifetime }
        return valid.max { ($0.expirationDate ?? .distantFuture) < ($1.expirationDate ?? .distantFuture) }
    }
}

/// A plan as the paywall shows it: prices already formatted by the store.
struct ProOffer: Identifiable, Equatable, Sendable {
    let plan: ProPlan
    let price: String
    /// The yearly price per month («66 ₽ a month»).
    var monthlyPrice: String?
    /// A free trial the customer is eligible for, as text («1 week»).
    var freeTrial: String?

    var id: ProPlan { plan }

    /// The plan the paywall selects first and the locked sheet sells:
    /// «forever» when the store has it, otherwise the first one there is.
    static func preferred(in offers: [ProOffer]) -> ProOffer? {
        offers.first { $0.plan == .lifetime } ?? offers.first
    }

    /// «1 week», «3 days» — in the current language.
    static func periodText(value: Int, unit: Product.SubscriptionPeriod.Unit) -> String? {
        var components = DateComponents()
        switch unit {
        case .day: components.day = value
        case .week: components.weekOfMonth = value
        case .month: components.month = value
        case .year: components.year = value
        @unknown default: return nil
        }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.day, .weekOfMonth, .month, .year]
        return formatter.string(from: components)
    }
}

/// How a purchase ended — the paywall says something only for the last two.
enum PurchaseOutcome: Sendable {
    case purchased, cancelled
    /// Ask to Buy or a payment that needs action: the purchase comes later
    /// through `Transaction.updates`.
    case pending
    case failed
}

@MainActor
@Observable
final class PremiumManager {

    /// Whether the customer currently owns Pro — bought «forever» or an
    /// active subscription (includes billing-retry / grace period, which
    /// `currentEntitlements` still reports as entitled).
    private(set) var isPremium = false

    /// What exactly the customer owns; `nil` without Pro.
    private(set) var entitlement: ProEntitlement?

    /// Pro is sold only on iOS 26+ (the customer's decision, 01.10): its main
    /// feature, online play, is built on Game Center party codes, which need
    /// iOS 26. On iOS 18 no paywall opens — a locked row explains why instead.
    /// A purchase made on another device is still honoured there, except for
    /// online play itself.
    static var isOffered: Bool {
        if #available(iOS 26.0, *) { true } else { false }
    }

    /// Online play needs iOS 26 regardless of Pro.
    static var supportsOnline: Bool { isOffered }

    /// The loaded products in `ProPlan` order (for the old paywall).
    private(set) var products: [Product] = []

    /// The loaded products as the new paywall shows them, in `ProPlan` order.
    private(set) var offers: [ProOffer] = []

    /// The store has answered at least once. Until then the paywall shows a
    /// spinner on the button; after it, no offers means the store is out of
    /// reach.
    private(set) var hasLoadedProducts = false

    /// Product identifiers of Pro. These must match the products in the
    /// StoreKit configuration file and App Store Connect.
    static let productIDs = ProPlan.allCases.map(\.productID)

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    /// Begins listening for transaction updates, loads products and refreshes
    /// entitlement once. Call from the app's root `.task`.
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    /// Loads the products from the store.
    func loadProducts() async {
        let loaded = (try? await Product.products(for: Self.productIDs)) ?? []
        let order = { (product: Product) in
            ProPlan(productID: product.id).flatMap { ProPlan.allCases.firstIndex(of: $0) } ?? .max
        }
        products = loaded.sorted { order($0) < order($1) }
        var offers: [ProOffer] = []
        for product in products {
            guard let plan = ProPlan(productID: product.id) else { continue }
            offers.append(await Self.offer(for: product, plan: plan))
        }
        self.offers = offers
        hasLoadedProducts = true
    }

    private static func offer(for product: Product, plan: ProPlan) async -> ProOffer {
        var offer = ProOffer(plan: plan, price: product.displayPrice)
        if plan == .yearly {
            offer.monthlyPrice = (product.price / 12).formatted(product.priceFormatStyle)
        }
        if let subscription = product.subscription,
           let intro = subscription.introductoryOffer,
           intro.paymentMode == .freeTrial,
           await subscription.isEligibleForIntroOffer {
            offer.freeTrial = ProOffer.periodText(value: intro.period.value, unit: intro.period.unit)
        }
        return offer
    }

    /// Purchases a plan.
    @discardableResult
    func purchase(_ plan: ProPlan) async -> PurchaseOutcome {
        guard let product = products.first(where: { $0.id == plan.productID }) else { return .failed }
        return await purchase(product)
    }

    /// Purchases a product.
    @discardableResult
    func purchase(_ product: Product) async -> PurchaseOutcome {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return .failed }
                await transaction.finish()
                await refreshEntitlements()
                return isPremium ? .purchased : .failed
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    /// Recomputes `isPremium` from the customer's current entitlements.
    func refreshEntitlements() async {
        var records: [ProEntitlement.Record] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            records.append(.init(productID: transaction.productID,
                                 purchaseDate: transaction.purchaseDate,
                                 expirationDate: transaction.expirationDate,
                                 revocationDate: transaction.revocationDate))
        }
        entitlement = ProEntitlement.best(of: records)
        isPremium = entitlement != nil
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await transaction.finish()
        await refreshEntitlements()
    }

    /// Restores purchases by syncing with the App Store, then refreshes.
    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }
}
