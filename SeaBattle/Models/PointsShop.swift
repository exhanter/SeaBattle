//
//  PointsShop.swift
//  SeaBattle
//
//  03.11: points are sold for money — three consumable packs, separately from
//  Pro (decision 10). Prices are the customer's (03.11): 200 for 0.99,
//  1 000 for 2.99, 10 000 for 9.99.
//
//  Sales. Consumables have no introductory or promotional offers in the App
//  Store (those are for subscriptions), so a sale is a SECOND product with the
//  lower price — `nl.brapps.SeaBattle.points.1000.sale` at 1.99 — always on
//  sale in App Store Connect. The app decides when to show it: the calendar
//  of promotions lives here in code (`PointsPromotion.all`), the store only
//  holds the prices. A pack bought through any of its products gives the same
//  points: the product id says which pack it is.
//
//  Crediting is exactly-once: the transaction id is remembered in
//  `PlayerStats` together with the balance (one write, one iCloud record), and
//  the transaction is finished only after that. A purchase interrupted between
//  the two comes back through `Transaction.unfinished` on the next launch and
//  is finished without a second credit.
//

import Foundation
import Observation
import StoreKit

// MARK: - Packs

enum PointsPack: Int, CaseIterable, Comparable, Sendable {
    case small = 200
    case medium = 1_000
    case large = 10_000

    var points: Int { rawValue }

    static let productPrefix = "nl.brapps.SeaBattle.points."

    /// The regular product — must match App Store Connect and the StoreKit
    /// configuration file.
    var productID: String { Self.productPrefix + String(points) }

    /// A sale product of this pack: the regular id plus a suffix («.sale»).
    func productID(sale suffix: String) -> String { productID + "." + suffix }

    /// The pack a product belongs to — regular or any sale variant, also one
    /// this build does not show (a sale added in App Store Connect later still
    /// credits the right number of points).
    init?(productID: String) {
        guard productID.hasPrefix(Self.productPrefix) else { return nil }
        let rest = productID.dropFirst(Self.productPrefix.count)
        guard let number = rest.split(separator: ".").first.flatMap({ Int($0) }),
              let pack = Self(rawValue: number) else { return nil }
        self = pack
    }

    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    /// Every product the shop loads: the regular ones and every sale variant a
    /// promotion in this build refers to.
    static var allProductIDs: [String] {
        var ids = allCases.map(\.productID)
        for promotion in PointsPromotion.all {
            for (pack, suffix) in promotion.sales.sorted(by: { $0.key < $1.key }) {
                let id = pack.productID(sale: suffix)
                if !ids.contains(id) { ids.append(id) }
            }
        }
        return ids
    }
}

// MARK: - Promotions

/// When a promotion runs. Days are whole days in the device's time zone, the
/// last one included.
enum PromotionWindow: Sendable {
    /// The same dates every year; may run over New Year (31.12 – 7.01).
    case yearly(start: (month: Int, day: Int), end: (month: Int, day: Int))
    /// Black Friday to Cyber Monday: the Friday after the fourth Thursday of
    /// November and the three days after it.
    case blackFriday
    /// Good Friday to Easter Monday of Western Easter.
    case westernEaster
    /// Good Friday to Easter Monday of Orthodox Easter. Customer 04.11: each
    /// Easter its own window — one window from the earlier to the later ran
    /// over five weeks in 2027 (28.03 and 2.05).
    case orthodoxEaster
    /// A one-off promotion shipped with an update: first and last day.
    case once(start: DateComponents, end: DateComponents)

    /// The window running on `date` — its first moment and the moment after
    /// its last day — or `nil`.
    func interval(containing date: Date, calendar: Calendar) -> DateInterval? {
        let year = calendar.component(.year, from: date)
        // A yearly window over New Year started the year before.
        for candidate in [year - 1, year] {
            guard let (first, last) = days(in: candidate, calendar: calendar),
                  let start = calendar.date(from: first).map({ calendar.startOfDay(for: $0) }),
                  let lastDay = calendar.date(from: last).map({ calendar.startOfDay(for: $0) }),
                  let end = calendar.date(byAdding: .day, value: 1, to: lastDay),
                  start < end else { continue }
            let interval = DateInterval(start: start, end: end)
            // `contains` counts the end itself; the end is the next day's start.
            if date >= interval.start && date < interval.end { return interval }
        }
        return nil
    }

    /// The first and the last day of the window that STARTS in `year`.
    private func days(in year: Int, calendar: Calendar) -> (DateComponents, DateComponents)? {
        switch self {
        case .yearly(let start, let end):
            let endYear = (end.month, end.day) < (start.month, start.day) ? year + 1 : year
            return (DateComponents(year: year, month: start.month, day: start.day),
                    DateComponents(year: endYear, month: end.month, day: end.day))
        case .blackFriday:
            guard let thanksgiving = Self.fourthThursdayOfNovember(year, calendar: calendar) else { return nil }
            return (Self.shift(thanksgiving, by: 1, calendar: calendar),
                    Self.shift(thanksgiving, by: 4, calendar: calendar))
        case .westernEaster:
            return Self.easterWeekend(Self.easterSunday(year), calendar: calendar)
        case .orthodoxEaster:
            return Self.easterWeekend(Self.orthodoxEasterSunday(year, calendar: calendar), calendar: calendar)
        case .once(let start, let end):
            return start.year == year ? (start, end) : nil
        }
    }

    static func fourthThursdayOfNovember(_ year: Int, calendar: Calendar) -> DateComponents? {
        guard let first = calendar.date(from: DateComponents(year: year, month: 11, day: 1)) else { return nil }
        // Weekdays: Sunday is 1, Thursday is 5.
        let weekday = calendar.component(.weekday, from: first)
        let firstThursday = 1 + (5 - weekday + 7) % 7
        return DateComponents(year: year, month: 11, day: firstThursday + 21)
    }

    /// Western Easter Sunday — the anonymous Gregorian algorithm.
    static func easterSunday(_ year: Int) -> DateComponents {
        let a = year % 19, b = year / 100, c = year % 100
        let d = b / 4, e = b % 4, f = (b + 8) / 25, g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = (h + l - 7 * m + 114) % 31 + 1
        return DateComponents(year: year, month: month, day: day)
    }

    /// Good Friday and Easter Monday around a Sunday.
    private static func easterWeekend(_ sunday: DateComponents,
                                      calendar: Calendar) -> (DateComponents, DateComponents) {
        (shift(sunday, by: -2, calendar: calendar), shift(sunday, by: 1, calendar: calendar))
    }

    /// Orthodox Easter Sunday as a Gregorian date — Meeus' Julian algorithm
    /// plus the 13 days between the calendars (right for 1900–2099).
    static func orthodoxEasterSunday(_ year: Int, calendar: Calendar) -> DateComponents {
        let a = year % 4, b = year % 7, c = year % 19
        let d = (19 * c + 15) % 30
        let e = (2 * a + 4 * b - d + 34) % 7
        let month = (d + e + 114) / 31
        let day = (d + e + 114) % 31 + 1
        return shift(DateComponents(year: year, month: month, day: day), by: 13, calendar: calendar)
    }

    private static func shift(_ day: DateComponents, by days: Int, calendar: Calendar) -> DateComponents {
        guard let date = calendar.date(from: day),
              let moved = calendar.date(byAdding: .day, value: days, to: date) else { return day }
        return calendar.dateComponents([.year, .month, .day], from: moved)
    }
}

/// A sale on points: when, which packs are cheaper, and how it looks. Adding
/// one is a line in `all` plus, if wanted, an emblem `promo_<id>` in the
/// asset catalog — without it the shop draws `symbol` in a brass box, so a
/// promotion never waits for art.
struct PointsPromotion: Identifiable, Sendable {
    let id: String
    /// One or more windows — Christmas is two single days.
    let windows: [PromotionWindow]
    /// Pack → suffix of its sale product. Packs not listed sell at the regular
    /// price during the promotion.
    let sales: [PointsPack: String]
    let title: LocalizedStringResource
    /// Drawn while there is no `promo_<id>` image.
    let symbol: String

    var emblemAsset: String { "promo_" + id }

    /// The two upper packs at the sale price (customer 03.11: 1 000 for 1.99,
    /// 10 000 for 4.99).
    static let upperPacks: [PointsPack: String] = [.medium: "sale", .large: "sale"]

    /// The calendar (03.11). Short windows on purpose: a sale that runs half
    /// the year becomes the price. About 24 days a year in all.
    static let all: [PointsPromotion] = [
        PointsPromotion(id: "blackfriday", windows: [.blackFriday], sales: upperPacks,
                        title: "Black Friday", symbol: "tag"),
        // Both Christmases, one day each (customer 04.11). Listed before New
        // Year, so 7 January shows Christmas, not New Year.
        PointsPromotion(id: "christmas", windows: [.yearly(start: (12, 25), end: (12, 25)),
                                                   .yearly(start: (1, 7), end: (1, 7))],
                        sales: upperPacks, title: "Christmas", symbol: "gift"),
        // The Russian New Year holidays, up to Orthodox Christmas.
        PointsPromotion(id: "newyear", windows: [.yearly(start: (12, 31), end: (1, 6))],
                        sales: upperPacks, title: "New Year", symbol: "sparkles"),
        // Both Easters; in a year they coincide the windows are the same days.
        PointsPromotion(id: "easter", windows: [.westernEaster, .orthodoxEaster], sales: upperPacks,
                        title: "Easter", symbol: "hare"),
        // With the Halloween shelf in the wardrobe (15.10 – 5.11).
        PointsPromotion(id: "halloween", windows: [.yearly(start: (10, 29), end: (11, 1))],
                        sales: upperPacks, title: "Halloween", symbol: "moon.stars"),
    ]

    /// The promotion running on `date` with its window; the first in `all`
    /// wins if two overlap.
    /// Gregorian whatever the device uses (a Buddhist calendar would put
    /// November in another year), in the device's time zone.
    static func active(on date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> ActivePromotion? {
        for promotion in all {
            for window in promotion.windows {
                if let interval = window.interval(containing: date, calendar: calendar) {
                    return ActivePromotion(promotion: promotion, interval: interval)
                }
            }
        }
        return nil
    }
}

struct ActivePromotion: Sendable {
    let promotion: PointsPromotion
    let interval: DateInterval

    /// The last day of the sale, for «until 30 November».
    func lastDay(calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.start
    }
}

// MARK: - What the sheet shows

/// One pack with its price as the store formatted it.
struct PointsOffer: Identifiable, Equatable, Sendable {
    let pack: PointsPack
    /// The product a purchase is made with — the sale one during a promotion.
    let productID: String
    let price: String
    /// The regular price, struck through — only while the pack is on sale.
    var regularPrice: String?
    /// «−33%»: a whole number, rounded.
    var discountPercent: Int?

    var id: PointsPack { pack }
    var isOnSale: Bool { regularPrice != nil }

    static func discount(price: Decimal, regular: Decimal) -> Int? {
        guard regular > 0, price < regular else { return nil }
        let share = NSDecimalNumber(decimal: (regular - price) / regular * 100).doubleValue
        return Int(share.rounded())
    }

    /// The offers from loaded prices: `prices` by product id. A sale product
    /// the store did not return (not set up yet) falls back to the regular
    /// price — the sheet then simply shows no sale on that pack.
    static func offers(prices: [String: (display: String, value: Decimal)],
                       promotion: PointsPromotion?) -> [PointsOffer] {
        PointsPack.allCases.compactMap { pack in
            let regular = prices[pack.productID]
            if let suffix = promotion?.sales[pack],
               let sale = prices[pack.productID(sale: suffix)] {
                var offer = PointsOffer(pack: pack, productID: pack.productID(sale: suffix),
                                        price: sale.display)
                if let regular, let percent = discount(price: sale.value, regular: regular.value) {
                    offer.regularPrice = regular.display
                    offer.discountPercent = percent
                }
                return offer
            }
            guard let regular else { return nil }
            return PointsOffer(pack: pack, productID: pack.productID, price: regular.display)
        }
    }
}

// MARK: - The shop

@MainActor
@Observable
final class PointsShop {

    /// Loaded products by id, regular and sale ones.
    private(set) var products: [String: Product] = [:]
    /// The store has answered at least once.
    private(set) var hasLoadedProducts = false

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    /// Listens for purchases that arrive later (Ask to Buy), finishes the ones
    /// a crash interrupted, loads the prices. Call from the app's root `.task`.
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task {
            for await result in Transaction.unfinished {
                await handle(result)
            }
            await loadProducts()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        let loaded = (try? await Product.products(for: PointsPack.allProductIDs)) ?? []
        products = Dictionary(loaded.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        hasLoadedProducts = true
    }

    /// What the sheet sells on `date`.
    func offers(on date: Date = .now) -> [PointsOffer] {
        PointsOffer.offers(prices: products.mapValues { ($0.displayPrice, $0.price) },
                           promotion: PointsPromotion.active(on: date)?.promotion)
    }

    @discardableResult
    func purchase(_ offer: PointsOffer) async -> PurchaseOutcome {
        guard let product = products[offer.productID] else { return .failed }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified = verification else { return .failed }
                return await handle(verification) ? .purchased : .failed
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

    /// Credits a points transaction once and finishes it. Pro's transactions
    /// are left to `PremiumManager`. A refunded purchase is finished without
    /// points — and points already credited are not taken back: the balance
    /// would go below zero or bought items would have to be taken away.
    /// RETURNS: whether this transaction's points are in the balance.
    @discardableResult
    private func handle(_ result: VerificationResult<Transaction>) async -> Bool {
        guard case .verified(let transaction) = result,
              let pack = PointsPack(productID: transaction.productID) else { return false }
        var credited = false
        if transaction.revocationDate == nil {
            ProgressStore.shared.creditPurchase(transactionID: transaction.id, points: pack.points,
                                                at: transaction.purchaseDate)
            credited = true
        }
        await transaction.finish()
        return credited
    }
}
