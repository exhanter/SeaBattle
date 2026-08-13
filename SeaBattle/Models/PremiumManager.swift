//
//  PremiumManager.swift
//  SeaBattle
//
//  Phase 2: the single source of truth for premium entitlement, on StoreKit 2.
//  Monetization is an auto-renewable subscription. This object loads the
//  customer's current entitlements, listens for transaction updates (renewals,
//  purchases made on other devices, revocations) and exposes `isPremium` for
//  the rest of the app to gate premium features on.
//

import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class PremiumManager {

    /// Whether the customer currently has an active premium subscription
    /// (includes billing-retry / grace period, which `currentEntitlements`
    /// still reports as entitled).
    private(set) var isPremium = false

    /// The loaded subscription products (for the paywall).
    private(set) var products: [Product] = []

    /// Product identifiers of the premium subscription group. These must match
    /// the products in the StoreKit configuration file and App Store Connect.
    static let productIDs = [
        "nl.brapps.SeaBattle.premium.monthly",
        "nl.brapps.SeaBattle.premium.yearly"
    ]

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

    /// Loads the subscription products from the store.
    func loadProducts() async {
        products = (try? await Product.products(for: Self.productIDs)) ?? []
    }

    /// Purchases a product. RETURNS: whether the customer is now premium.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
                await refreshEntitlements()
                return isPremium
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    /// Recomputes `isPremium` from the customer's current entitlements.
    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if Self.productIDs.contains(transaction.productID),
               transaction.revocationDate == nil,
               (transaction.expirationDate ?? .distantFuture) > Date() {
                active = true
            }
        }
        isPremium = active
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
