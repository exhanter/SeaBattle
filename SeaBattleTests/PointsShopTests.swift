//
//  PointsShopTests.swift
//  SeaBattleTests
//
//  03.11: points for money — the packs and their product ids, the calendar of
//  sales, the offers the sheet shows and the exactly-once credit. StoreKit
//  itself is not touched: everything here is plain values.
//

import Testing
import Foundation
@testable import SeaBattle

@Suite("Покупка баллов и акции")
struct PointsShopTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        return calendar
    }

    private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func promotion(on date: Date) -> String? {
        PointsPromotion.active(on: date, calendar: calendar)?.promotion.id
    }

    // MARK: Пакеты

    @Test("Пакет узнаётся по продукту — обычному, акционному и незнакомому варианту")
    func packFromProductID() {
        #expect(PointsPack(productID: "nl.brapps.SeaBattle.points.200") == .small)
        #expect(PointsPack(productID: "nl.brapps.SeaBattle.points.1000.sale") == .medium)
        #expect(PointsPack(productID: "nl.brapps.SeaBattle.points.10000.spring27") == .large,
                "вариант, заведённый позже, всё равно зачисляет свой пакет")
        #expect(PointsPack(productID: "nl.brapps.SeaBattle.points.500") == nil)
        #expect(PointsPack(productID: "nl.brapps.SeaBattle.premium.lifetime") == nil)
    }

    @Test("Магазин грузит три обычных продукта и два акционных")
    func allProductIDs() {
        let ids = PointsPack.allProductIDs
        #expect(ids == ["nl.brapps.SeaBattle.points.200",
                        "nl.brapps.SeaBattle.points.1000",
                        "nl.brapps.SeaBattle.points.10000",
                        "nl.brapps.SeaBattle.points.1000.sale",
                        "nl.brapps.SeaBattle.points.10000.sale"])
    }

    // MARK: Календарь

    @Test("Чёрная пятница — с пятницы после четвёртого четверга ноября по понедельник")
    func blackFriday() {
        #expect(promotion(on: day(2026, 11, 26)) == nil, "День благодарения — ещё нет")
        #expect(promotion(on: day(2026, 11, 27, hour: 0)) == "blackfriday")
        #expect(promotion(on: day(2026, 11, 30, hour: 23)) == "blackfriday")
        #expect(promotion(on: day(2026, 12, 1, hour: 0)) == nil)
        // 2027: 1 ноября — понедельник, четвёртый четверг — 25-е.
        #expect(promotion(on: day(2027, 11, 26)) == "blackfriday")
        #expect(promotion(on: day(2027, 11, 29)) == "blackfriday")
        #expect(promotion(on: day(2027, 11, 25)) == nil)
    }

    @Test("Последний день акции — для «до 30 ноября»")
    func lastDay() throws {
        let active = try #require(PointsPromotion.active(on: day(2026, 11, 28), calendar: calendar))
        let last = calendar.dateComponents([.month, .day], from: active.lastDay(calendar: calendar))
        #expect(last.month == 11 && last.day == 30)
    }

    @Test("Пасха — два окна: западная и православная, с пятницы по понедельник")
    func easter() {
        #expect(PromotionWindow.easterSunday(2026) == DateComponents(year: 2026, month: 4, day: 5))
        #expect(PromotionWindow.easterSunday(2027) == DateComponents(year: 2027, month: 3, day: 28))
        #expect(PromotionWindow.easterSunday(2028) == DateComponents(year: 2028, month: 4, day: 16))
        #expect(PromotionWindow.orthodoxEasterSunday(2026, calendar: calendar) == DateComponents(year: 2026, month: 4, day: 12))
        #expect(PromotionWindow.orthodoxEasterSunday(2027, calendar: calendar) == DateComponents(year: 2027, month: 5, day: 2))
        #expect(PromotionWindow.orthodoxEasterSunday(2028, calendar: calendar) == DateComponents(year: 2028, month: 4, day: 16))
        // 2026: 5.04 и 12.04 — 3–6.04 и 10–13.04, между ними без акции.
        #expect(promotion(on: day(2026, 4, 2)) == nil)
        #expect(promotion(on: day(2026, 4, 3)) == "easter")
        #expect(promotion(on: day(2026, 4, 6)) == "easter")
        #expect(promotion(on: day(2026, 4, 8)) == nil, "между двумя Пасхами")
        #expect(promotion(on: day(2026, 4, 10)) == "easter")
        #expect(promotion(on: day(2026, 4, 13)) == "easter")
        #expect(promotion(on: day(2026, 4, 14)) == nil)
        // 2027: 28.03 и 2.05 — два окна, а не пять недель.
        #expect(promotion(on: day(2027, 3, 26)) == "easter")
        #expect(promotion(on: day(2027, 3, 30)) == nil)
        #expect(promotion(on: day(2027, 4, 15)) == nil)
        #expect(promotion(on: day(2027, 4, 30)) == "easter")
        #expect(promotion(on: day(2027, 5, 3)) == "easter")
        #expect(promotion(on: day(2027, 5, 4)) == nil)
        // 2028: совпадают — четыре дня.
        #expect(promotion(on: day(2028, 4, 14)) == "easter")
        #expect(promotion(on: day(2028, 4, 17)) == "easter")
        #expect(promotion(on: day(2028, 4, 18)) == nil)
    }

    @Test("Рождество — 25 декабря и 7 января, Новый год между ними")
    func winterHolidays() {
        #expect(promotion(on: day(2026, 12, 24)) == nil)
        #expect(promotion(on: day(2026, 12, 25)) == "christmas")
        #expect(promotion(on: day(2026, 12, 26)) == nil)
        #expect(promotion(on: day(2026, 12, 31)) == "newyear")
        #expect(promotion(on: day(2027, 1, 6)) == "newyear")
        #expect(promotion(on: day(2027, 1, 7)) == "christmas")
        #expect(promotion(on: day(2027, 1, 8)) == nil)
    }

    @Test("Хеллоуин — четыре дня, обычный день — без акции")
    func halloweenAndOrdinaryDays() {
        #expect(promotion(on: day(2026, 10, 31)) == "halloween")
        #expect(promotion(on: day(2026, 11, 2)) == nil)
        #expect(promotion(on: day(2026, 11, 3)) == nil)
        #expect(promotion(on: day(2027, 6, 15)) == nil)
    }

    @Test("Разовая акция из обновления")
    func oneOff() {
        let window = PromotionWindow.once(start: DateComponents(year: 2027, month: 6, day: 1),
                                          end: DateComponents(year: 2027, month: 6, day: 3))
        #expect(window.interval(containing: day(2027, 6, 2), calendar: calendar) != nil)
        #expect(window.interval(containing: day(2027, 6, 4), calendar: calendar) == nil)
        #expect(window.interval(containing: day(2028, 6, 2), calendar: calendar) == nil)
    }

    // MARK: Предложения

    private let prices: [String: (display: String, value: Decimal)] = [
        "nl.brapps.SeaBattle.points.200": ("€0,99", Decimal(string: "0.99")!),
        "nl.brapps.SeaBattle.points.1000": ("€2,99", Decimal(string: "2.99")!),
        "nl.brapps.SeaBattle.points.10000": ("€9,99", Decimal(string: "9.99")!),
        "nl.brapps.SeaBattle.points.1000.sale": ("€1,99", Decimal(string: "1.99")!),
        "nl.brapps.SeaBattle.points.10000.sale": ("€4,99", Decimal(string: "4.99")!),
    ]

    @Test("Без акции — три пакета по обычной цене")
    func regularOffers() {
        let offers = PointsOffer.offers(prices: prices, promotion: nil)
        #expect(offers.map(\.price) == ["€0,99", "€2,99", "€9,99"])
        #expect(offers.allSatisfy { !$0.isOnSale })
    }

    @Test("В акцию два верхних пакета дешевле, старая цена и скидка при них")
    func saleOffers() throws {
        let black = try #require(PointsPromotion.active(on: day(2026, 11, 28), calendar: calendar))
        let offers = PointsOffer.offers(prices: prices, promotion: black.promotion)
        #expect(offers.map(\.price) == ["€0,99", "€1,99", "€4,99"])
        #expect(offers.map(\.regularPrice) == [nil, "€2,99", "€9,99"])
        #expect(offers.map(\.discountPercent) == [nil, 33, 50])
        #expect(offers[2].productID == "nl.brapps.SeaBattle.points.10000.sale")
    }

    @Test("Акционный продукт не пришёл из магазина — пакет по обычной цене, без пометки")
    func missingSaleProduct() throws {
        var partial = prices
        partial["nl.brapps.SeaBattle.points.10000.sale"] = nil
        let black = try #require(PointsPromotion.active(on: day(2026, 11, 28), calendar: calendar))
        let large = try #require(PointsOffer.offers(prices: partial, promotion: black.promotion).last)
        #expect(large.price == "€9,99")
        #expect(!large.isOnSale)
        #expect(large.productID == PointsPack.large.productID)
    }

    // MARK: Зачисление

    @Test("Покупка зачисляется один раз и пишет строку в историю")
    func creditOnce() {
        var stats = PlayerStats(points: 12)
        let first = stats.creditPurchase(transactionID: 7, points: 1_000)
        let again = stats.creditPurchase(transactionID: 7, points: 1_000)
        #expect(first)
        #expect(!again, "та же транзакция после сбоя")
        #expect(stats.points == 1_012)
        #expect(stats.ledger.entries.count == 1)
        #expect(stats.ledger.entries[0].kind == .topUp)
        #expect(stats.ledger.entries[0].amount == 1_000)
    }

    @Test("Память о транзакциях переживает запись и не растёт без конца")
    func creditedTransactionsPersist() throws {
        var stats = PlayerStats()
        for id in 1...60 { stats.creditPurchase(transactionID: UInt64(id), points: 200) }
        #expect(stats.creditedTransactions.count == PlayerStats.creditedTransactionsCapacity)
        #expect(stats.creditedTransactions.first == 60)

        let decoded = try JSONDecoder().decode(PlayerStats.self, from: JSONEncoder().encode(stats))
        #expect(decoded.creditedTransactions == stats.creditedTransactions)
        #expect(decoded.ledger.entries.first?.kind == .topUp)
        var again = decoded
        let credited = again.creditPurchase(transactionID: 60, points: 200)
        #expect(!credited)
    }
}
