//
//  ProTests.swift
//  SeaBattleTests
//
//  R4.3 — Pro. Проверяется то, что можно проверить без StoreKit: какое право
//  считается действующим (навсегда важнее подписки, возврат и истёкшее — не
//  право), идентификаторы продуктов, условие по умолчанию и тексты листа.
//

import Foundation
import Testing
@testable import SeaBattle

@Suite("Pro")
struct ProTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func days(_ n: Double) -> Date { now.addingTimeInterval(n * 86_400) }

    private func record(_ plan: ProPlan, bought: Double = -10, expires: Double? = nil,
                        revoked: Bool = false) -> ProEntitlement.Record {
        .init(productID: plan.productID, purchaseDate: days(bought),
              expirationDate: expires.map(days), revocationDate: revoked ? days(-1) : nil)
    }

    @Test("Без покупок права нет")
    func noRecordsNoEntitlement() {
        #expect(ProEntitlement.best(of: [], now: now) == nil)
    }

    @Test("Покупка навсегда важнее идущей подписки и не имеет срока")
    func lifetimeWinsOverSubscription() {
        let best = ProEntitlement.best(of: [record(.yearly, expires: 200),
                                            record(.lifetime, bought: -30)], now: now)
        #expect(best?.plan == .lifetime)
        #expect(best?.expirationDate == nil)
        #expect(best?.purchaseDate == days(-30))
    }

    @Test("Из двух подписок — та, что длится дольше")
    func longestSubscriptionWins() {
        let best = ProEntitlement.best(of: [record(.yearly, expires: 20),
                                            record(.monthly, expires: 25)], now: now)
        #expect(best?.plan == .monthly)
        #expect(best?.expirationDate == days(25))
    }

    @Test("Истёкшая подписка, возврат и чужой продукт — не право")
    func invalidRecordsAreIgnored() {
        let records: [ProEntitlement.Record] = [
            record(.yearly, expires: -1),
            record(.lifetime, revoked: true),
            .init(productID: "nl.brapps.SeaBattle.points.100", purchaseDate: days(-1))
        ]
        #expect(ProEntitlement.best(of: records, now: now) == nil)
    }

    @Test("Идентификаторы продуктов: три условия, «навсегда» первым")
    @MainActor
    func productIDs() {
        #expect(PremiumManager.productIDs == ["nl.brapps.SeaBattle.premium.lifetime",
                                              "nl.brapps.SeaBattle.premium.yearly",
                                              "nl.brapps.SeaBattle.premium.monthly"])
        for plan in ProPlan.allCases {
            #expect(ProPlan(productID: plan.productID) == plan)
        }
        #expect(ProPlan(productID: "nl.brapps.SeaBattle.other") == nil)
        #expect(!ProPlan.lifetime.isSubscription)
    }

    @Test("По умолчанию выбрано «навсегда», без него — первое, что есть")
    func preferredOffer() {
        let year = ProOffer(plan: .yearly, price: "790 ₽")
        let month = ProOffer(plan: .monthly, price: "149 ₽")
        let forever = ProOffer(plan: .lifetime, price: "1 490 ₽")
        #expect(ProOffer.preferred(in: [year, month, forever])?.plan == .lifetime)
        #expect(ProOffer.preferred(in: [year, month])?.plan == .yearly)
        #expect(ProOffer.preferred(in: []) == nil)
    }

    @Test("Пробный период пишется словами")
    func trialPeriodText() {
        #expect(ProOffer.periodText(value: 1, unit: .week) != nil)
        #expect(ProOffer.periodText(value: 3, unit: .day)?.contains("3") == true)
    }

    @Test("У каждого платного режима свой лист")
    func everyIntentHasItsFeature() {
        let intents: [AppState.PremiumIntent] = [.expert, .hotSeat, .nearby, .online]
        for intent in intents {
            #expect(ProFeature.feature(for: intent).intent == intent)
        }
        #expect(ProFeature.all.count == 4)
    }

    @Test("Отмена покупки молчит, ожидание и сбой — нет")
    func purchaseNotices() {
        #expect(ProPurchaseNotice(.cancelled) == nil)
        #expect(ProPurchaseNotice(.purchased) == nil)
        #expect(ProPurchaseNotice(.pending) == .pending)
        #expect(ProPurchaseNotice(.failed) == .failed)
    }
}
