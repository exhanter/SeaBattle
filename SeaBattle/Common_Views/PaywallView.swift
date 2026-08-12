//
//  PaywallView.swift
//  SeaBattle
//
//  Phase 2: the subscription paywall. Uses StoreKit's `SubscriptionStoreView`,
//  which renders the localized products, prices, intro offers, the subscribe
//  button, a Restore Purchases button and the required Terms of Service /
//  Privacy Policy links. Premium entitlement itself is tracked by
//  `PremiumManager`; this view only merchandises the subscription.
//

import SwiftUI
import StoreKit

struct PaywallView: View {

    // TODO: replace with the real hosted Terms / Privacy URLs before shipping.
    private let termsURL = URL(string: "https://brapps.nl/seabattle/terms")!
    private let privacyURL = URL(string: "https://brapps.nl/seabattle/privacy")!

    var body: some View {
        SubscriptionStoreView(productIDs: PremiumManager.productIDs) {
            marketingContent
        }
        .storeButton(.visible, for: .restorePurchases)
        .subscriptionStorePolicyDestination(url: termsURL, for: .termsOfService)
        .subscriptionStorePolicyDestination(url: privacyURL, for: .privacyPolicy)
    }

    private var marketingContent: some View {
        VStack(spacing: 12) {
            Image("war_ship8")
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 140)
                .cornerRadius(12)

            Text("SeaBattle Premium")
                .font(.custom("Dorsa", size: 48))
                .foregroundStyle(Color(red: 248/255, green: 255/255, blue: 0/255))

            VStack(alignment: .leading, spacing: 8) {
                featureRow("brain.head.profile", "Expert difficulty — the smartest AI")
                featureRow("person.2.fill", "Two players on one device")
                featureRow("network", "Online & nearby multiplayer")
                featureRow("lightbulb.max.fill", "Hints powered by your points")
                featureRow("icloud.fill", "Cloud sync across your devices")
            }
            .padding(.horizontal)
        }
        .padding()
    }

    private func featureRow(_ systemImage: String, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .frame(width: 28)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .font(.body)
    }
}

#Preview {
    PaywallView()
}
