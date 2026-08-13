//
//  PaywallView.swift
//  SeaBattle
//
//  Phase 2 (revised): a custom subscription paywall driven by PremiumManager, so
//  the Subscribe button is always clearly labelled with the price / free trial
//  and the sheet dismisses itself once the purchase (or restore) makes the
//  customer premium.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PremiumManager.self) private var premium

    @State private var working = false

    // TODO: replace with the real hosted Terms / Privacy URLs before shipping.
    private let termsURL = URL(string: "https://brapps.nl/seabattle/terms")!
    private let privacyURL = URL(string: "https://brapps.nl/seabattle/privacy")!

    private let accent = Color(red: 248/255, green: 255/255, blue: 0/255)

    private var product: Product? { premium.products.first }

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.11, green: 0.77, blue: 0.56).opacity(0.60),
                                                       Color(red: 0.04, green: 0.10, blue: 0.25).opacity(0.80)]),
                           startPoint: .bottom, endPoint: .top)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    Text("SeaBattle Premium")
                        .font(.custom("Dorsa", size: 52))
                        .foregroundStyle(accent)

                    VStack(alignment: .leading, spacing: 10) {
                        feature("brain.head.profile", "Expert difficulty — the smartest AI")
                        feature("person.2.fill", "Two players on one device")
                        feature("network", "Online & nearby multiplayer")
                        feature("lightbulb.max.fill", "Hints powered by your points")
                        feature("icloud.fill", "Cloud sync across your devices")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal)

                    if let product {
                        subscribeButton(product)
                    } else {
                        ProgressView().tint(.white).padding()
                    }

                    Button("Restore Purchases") {
                        Task {
                            working = true
                            await premium.restore()
                            working = false
                            if premium.isPremium { dismiss() }
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)

                    HStack(spacing: 24) {
                        Link("Terms of Service", destination: termsURL)
                        Link("Privacy Policy", destination: privacyURL)
                    }
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.8))
                }
                .padding(24)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.title).foregroundStyle(.white.opacity(0.8)).padding()
            }
        }
        .task {
            if premium.products.isEmpty { await premium.loadProducts() }
        }
        .onChange(of: premium.isPremium) { _, isPremium in
            if isPremium { dismiss() }
        }
    }

    private func subscribeButton(_ product: Product) -> some View {
        Button {
            Task {
                working = true
                await premium.purchase(product)
                working = false
                if premium.isPremium { dismiss() }
            }
        } label: {
            VStack(spacing: 2) {
                Text(subscribeTitle(product)).font(.headline)
                Text(priceLine(product)).font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(accent)
        .foregroundStyle(.black)
        .disabled(working)
        .padding(.horizontal)
    }

    private func subscribeTitle(_ product: Product) -> String {
        if let intro = product.subscription?.introductoryOffer, intro.paymentMode == .freeTrial {
            return "Start \(periodText(intro.period)) free trial"
        }
        return "Subscribe"
    }

    private func priceLine(_ product: Product) -> String {
        let per = product.subscription.map { " / \(periodText($0.subscriptionPeriod))" } ?? ""
        if product.subscription?.introductoryOffer?.paymentMode == .freeTrial {
            return "then \(product.displayPrice)\(per)"
        }
        return "\(product.displayPrice)\(per)"
    }

    private func periodText(_ period: Product.SubscriptionPeriod) -> String {
        let unit: String
        switch period.unit {
        case .day: unit = "day"
        case .week: unit = "week"
        case .month: unit = "month"
        case .year: unit = "year"
        @unknown default: unit = "period"
        }
        return period.value == 1 ? "1 \(unit)" : "\(period.value) \(unit)s"
    }

    private func feature(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).frame(width: 28).foregroundStyle(accent)
            Text(text).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    PaywallView()
        .environment(PremiumManager())
}
