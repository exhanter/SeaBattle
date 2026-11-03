//
//  Sailor.swift
//  SeaBattle
//
//  The player's sailor (customer 30.10): a waist-up portrait put together from
//  layers — figure, shirt, jacket, winter coat, cap —
//  which replaces the showcase of avatar sets. Ranks and clothes are bought for
//  points; ranks one at a time, the next one shown only once the current one is
//  bought, so the ladder can grow forever. The art is the customer's
//  (`docs/SAILOR_ART.md`); until a file is in the asset catalog the portrait
//  draws a placeholder for it (`SailorPortrait`).
//
//  What the player owns and wears lives in `PlayerStats` next to the points it
//  was bought with, so the two travel in one CloudKit record and never
//  disagree.
//

import Foundation

// MARK: - Catalog

/// A clothing slot. The layers are drawn in this order, bottom to top, with
/// the figure below them (`SailorLayer.layers(of:)`). Any item goes with any
/// other — a naval jacket with a Santa hat (customer 31.10).
enum SailorSlot: String, Codable, CaseIterable, Sendable {
    case shirt, jacket, coat, cap
}

enum SailorBody: String, Codable, CaseIterable, Sendable {
    case man = "m", woman = "f"
}

/// The figure under the clothes — all of it free (customer 02.11): man or
/// woman, skin tone, hairstyle and hair colour. The art is drawn once in grey
/// and tinted by the app (`SailorPalette`), so a tone or colour is a number
/// here, not a file.
struct SailorFigure: Codable, Hashable, Sendable {
    static let skinTones = 1...6
    static let hairColors = 1...8
    /// Hairstyles, by the art file `sailor_hair_<id>` — the same for both
    /// figures, whose heads share one outline (design task D6). A hairstyle is
    /// drawn only bareheaded; under a cap only the figure's short hair shows,
    /// plus the strands below the cap for the long styles (`underCapHair`).
    static let hairStyles = ["short", "buzz", "curly", "curlshort", "slick",
                             "pixie", "bob", "bun", "ponytail", "long"]
    /// Long styles whose strands below the ears show under a cap:
    /// `sailor_hair_<id>_under`.
    static let underCapHair: Set<String> = ["bob", "ponytail", "long"]

    var body: SailorBody = .man
    var skinTone: Int = 1
    var hair: String = "short"
    var hairColor: Int = 3

    /// Grey skin, tinted by `skinTone`.
    var skinAsset: String { "sailor_body_\(body.rawValue)" }
    /// Grey short hair and brows that always show, tinted by `hairColor`.
    var hairBaseAsset: String { "sailor_hairbase_\(body.rawValue)" }
    /// Eyes, mouth, blush — not tinted.
    var faceAsset: String { "sailor_face_\(body.rawValue)" }
    var hairAsset: String { "sailor_hair_\(hair)" }
    /// What shows of the hairstyle under a cap; `nil` — nothing but the short
    /// hair of the figure.
    var underCapHairAsset: String? {
        Self.underCapHair.contains(hair) ? "sailor_hair_\(hair)_under" : nil
    }

    init(body: SailorBody = .man, skinTone: Int = 1, hair: String = "short", hairColor: Int = 3) {
        self.body = body
        self.skinTone = Self.skinTones.contains(skinTone) ? skinTone : 1
        self.hair = Self.hairStyles.contains(hair) ? hair : "short"
        self.hairColor = Self.hairColors.contains(hairColor) ? hairColor : 3
    }

    private enum CodingKeys: String, CodingKey { case body, skinTone, hair, hairColor }

    /// Every key optional: hair arrived after the first saves and over the
    /// network from older builds.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(body: (try? c.decodeIfPresent(SailorBody.self, forKey: .body)) ?? .man,
                  skinTone: (try? c.decodeIfPresent(Int.self, forKey: .skinTone)) ?? 1,
                  hair: (try? c.decodeIfPresent(String.self, forKey: .hair)) ?? "short",
                  hairColor: (try? c.decodeIfPresent(Int.self, forKey: .hairColor)) ?? 3)
    }
}

/// A thing to wear. The `id` is frozen — it is stored, synced and sent over
/// the network — and names the art file: `sailor_<id>`.
struct SailorItem: Identifiable, Hashable, Sendable {
    let id: String
    let slot: SailorSlot
    /// Points; 0 — everybody has it from the start.
    let price: Int
    /// The step of its section's ladder, 1…5, styled after a rank (sailor,
    /// petty officer, officer, captain, admiral); 0 — a seasonal item outside
    /// the ladders (customer 02.11).
    let tier: Int
    /// The season a tier-0 item is sold in (`SailorSeason.id`).
    var season: String? = nil

    /// The rank the tier is sold from (customer 02.11); `nil` — sold to all.
    var minRank: String? { SailorCatalog.tierRanks[tier] }

    var assetName: String { "sailor_\(id)" }
    var isFree: Bool { price == 0 }
}

/// Where a rank sits, for the colour of the ring around the portrait.
enum RankGroup: Sendable {
    case enlisted, warrant, junior, senior, admiral
}

struct SailorRank: Identifiable, Hashable, Sendable {
    /// Frozen, like `SailorItem.id`; names the art files.
    let id: String
    /// The price of this step from the rank below; the first rank is free.
    let price: Int
    let group: RankGroup
    /// How many marks the placeholder badge draws — stripes for the enlisted,
    /// stars for the rest. The art replaces it.
    let marks: Int

    var badgeAsset: String { "rank_badge_\(id)" }
}

enum SailorCatalog {
    /// Bought one by one, in this order. New ranks go to the END only: a stored
    /// rank is an id, and the next one is whatever follows it here.
    static let ranks: [SailorRank] = [
        SailorRank(id: "seaman", price: 0, group: .enlisted, marks: 0),
        SailorRank(id: "seaman_senior", price: 100, group: .enlisted, marks: 1),
        SailorRank(id: "petty", price: 200, group: .enlisted, marks: 2),
        SailorRank(id: "petty_chief", price: 300, group: .enlisted, marks: 3),
        SailorRank(id: "warrant", price: 500, group: .warrant, marks: 2),
        SailorRank(id: "lieutenant", price: 750, group: .junior, marks: 2),
        SailorRank(id: "lieutenant_senior", price: 1000, group: .junior, marks: 3),
        SailorRank(id: "commander_lt", price: 1500, group: .junior, marks: 4),
        SailorRank(id: "captain_3", price: 2000, group: .senior, marks: 1),
        SailorRank(id: "captain_2", price: 3000, group: .senior, marks: 2),
        SailorRank(id: "captain_1", price: 4000, group: .senior, marks: 3),
        SailorRank(id: "admiral_rear", price: 6000, group: .admiral, marks: 1),
        SailorRank(id: "admiral_vice", price: 8000, group: .admiral, marks: 2),
        SailorRank(id: "admiral", price: 12000, group: .admiral, marks: 3),
        SailorRank(id: "admiral_fleet", price: 20000, group: .admiral, marks: 4),
    ]

    /// The rank each tier is sold from (customer 02.11).
    static let tierRanks: [Int: String] = [2: "petty", 3: "lieutenant", 4: "captain_3", 5: "admiral_rear"]

    /// Prices are preliminary (task K6 checks them against what a match pays).
    static let items: [SailorItem] = [
        // Tier 1 — sailor.
        SailorItem(id: "cap_sailor", slot: .cap, price: 0, tier: 1),
        SailorItem(id: "shirt_stripes", slot: .shirt, price: 0, tier: 1),
        SailorItem(id: "jacket_work", slot: .jacket, price: 50, tier: 1),
        SailorItem(id: "coat_peacoat", slot: .coat, price: 100, tier: 1),
        // Tier 2 — petty officer.
        SailorItem(id: "cap_petty", slot: .cap, price: 150, tier: 2),
        SailorItem(id: "shirt_jumper", slot: .shirt, price: 150, tier: 2),
        SailorItem(id: "jacket_petty", slot: .jacket, price: 200, tier: 2),
        SailorItem(id: "coat_storm", slot: .coat, price: 200, tier: 2),
        // Tier 3 — officer.
        SailorItem(id: "cap_officer", slot: .cap, price: 400, tier: 3),
        SailorItem(id: "shirt_white", slot: .shirt, price: 400, tier: 3),
        SailorItem(id: "jacket_officer", slot: .jacket, price: 500, tier: 3),
        SailorItem(id: "coat_officer", slot: .coat, price: 500, tier: 3),
        // Tier 4 — captain.
        SailorItem(id: "cap_captain", slot: .cap, price: 1000, tier: 4),
        SailorItem(id: "shirt_captain", slot: .shirt, price: 1000, tier: 4),
        SailorItem(id: "jacket_captain", slot: .jacket, price: 1500, tier: 4),
        SailorItem(id: "coat_captain", slot: .coat, price: 1500, tier: 4),
        // Tier 5 — admiral.
        SailorItem(id: "cap_admiral", slot: .cap, price: 3000, tier: 5),
        SailorItem(id: "shirt_admiral", slot: .shirt, price: 3000, tier: 5),
        SailorItem(id: "jacket_admiral", slot: .jacket, price: 5000, tier: 5),
        SailorItem(id: "coat_admiral", slot: .coat, price: 5000, tier: 5),
        // Seasonal — sold only in their season, kept for good once bought.
        SailorItem(id: "cap_newyear_santa", slot: .cap, price: 200, tier: 0, season: "newyear"),
        SailorItem(id: "jacket_newyear_santa", slot: .jacket, price: 300, tier: 0, season: "newyear"),
        SailorItem(id: "shirt_newyear_sweater", slot: .shirt, price: 200, tier: 0, season: "newyear"),
        SailorItem(id: "coat_newyear_frost", slot: .coat, price: 400, tier: 0, season: "newyear"),
        SailorItem(id: "cap_newyear_deer", slot: .cap, price: 150, tier: 0, season: "newyear"),
        SailorItem(id: "cap_newyear_elf", slot: .cap, price: 150, tier: 0, season: "newyear"),
        SailorItem(id: "cap_halloween_pirate", slot: .cap, price: 200, tier: 0, season: "halloween"),
        SailorItem(id: "jacket_halloween_pirate", slot: .jacket, price: 300, tier: 0, season: "halloween"),
        SailorItem(id: "shirt_halloween_skeleton", slot: .shirt, price: 150, tier: 0, season: "halloween"),
        SailorItem(id: "coat_halloween_vampire", slot: .coat, price: 400, tier: 0, season: "halloween"),
        SailorItem(id: "cap_halloween_witch", slot: .cap, price: 200, tier: 0, season: "halloween"),
    ]

    /// A section's ladder, tier 1 first.
    static func ladder(_ slot: SailorSlot) -> [SailorItem] {
        items.filter { $0.slot == slot && $0.tier > 0 }.sorted { $0.tier < $1.tier }
    }

    static func seasonal(_ season: SailorSeason) -> [SailorItem] {
        items.filter { $0.season == season.id }
    }

    /// The shirt everybody starts in.
    static let stripedShirt = "shirt_stripes"

    static func item(_ id: String?) -> SailorItem? {
        guard let id else { return nil }
        return items.first { $0.id == id }
    }

    static func items(in slot: SailorSlot) -> [SailorItem] {
        items.filter { $0.slot == slot }
    }

    static func rankIndex(_ id: String) -> Int? {
        ranks.firstIndex { $0.id == id }
    }

    /// A rank this build does not know (sent by a newer one) reads as the
    /// highest it does know rather than as a seaman: it can only be higher.
    static func rank(_ id: String) -> SailorRank {
        rankIndex(id).map { ranks[$0] } ?? ranks[ranks.count - 1]
    }
}

// MARK: - Winter

/// When the winter clothes go on (Settings, customer 30.10).
enum WinterDress: String, Codable, CaseIterable, Sendable {
    case bySeason, always, never
}

/// Is it winter where the player is? The hemisphere comes from the device's
/// region, so no location permission is needed; someone whose region is not
/// where they live picks «always» or «never» in Settings.
enum Season {
    /// Countries whose winter is June to August. Brazil counts: its populated
    /// south has a real winter.
    static let southern: Set<String> = [
        "AR", "AU", "BO", "BR", "BW", "CL", "FK", "LS", "MG", "MU", "MZ", "NA",
        "NZ", "PY", "SZ", "UY", "ZA", "ZW", "RE", "NC",
    ]

    /// Near the equator there is no winter to dress for.
    static let tropical: Set<String> = [
        "SG", "MY", "ID", "PH", "TH", "KH", "LA", "VN", "MM", "LK", "MV", "BN", "TL",
        "NG", "GH", "CI", "CM", "KE", "UG", "TZ", "RW", "GA", "CG", "CD", "SN", "LR",
        "SL", "GN", "TG", "BJ", "ET", "SO", "CO", "VE", "EC", "PE", "PA", "CR", "NI",
        "HN", "GT", "SV", "BZ", "CU", "DO", "JM", "HT", "PR", "TT", "BB", "GY", "SR",
        "FJ", "WS", "PG", "SB", "VU",
    ]

    static func isWinter(on date: Date, region: String?, calendar: Calendar = .current) -> Bool {
        let region = region?.uppercased() ?? ""
        if tropical.contains(region) { return false }
        let month = calendar.component(.month, from: date)
        return southern.contains(region) ? (6...8).contains(month) : [12, 1, 2].contains(month)
    }

    /// Right now, on this device.
    static func isWinterHere(on date: Date = .now) -> Bool {
        isWinter(on: date, region: Locale.current.region?.identifier)
    }
}

// MARK: - Seasonal sets

/// A holiday window in which its set is on sale (customer 02.11). The date is
/// the device's; moving the clock cheats it, which for points is acceptable.
struct SailorSeason: Hashable, Sendable {
    let id: String
    /// Month and day, inclusive; a window may run over New Year.
    let start: (month: Int, day: Int)
    let end: (month: Int, day: Int)

    static let all: [SailorSeason] = [
        SailorSeason(id: "halloween", start: (10, 15), end: (11, 5)),
        SailorSeason(id: "newyear", start: (12, 1), end: (1, 10)),
    ]

    static func season(_ id: String?) -> SailorSeason? { all.first { $0.id == id } }

    func isActive(on date: Date, calendar: Calendar = .current) -> Bool {
        let parts = calendar.dateComponents([.month, .day], from: date)
        guard let month = parts.month, let day = parts.day else { return false }
        let today = month * 100 + day
        let from = start.month * 100 + start.day
        let to = end.month * 100 + end.day
        return from <= to ? (from...to).contains(today) : today >= from || today <= to
    }

    /// The seasons on now that have something to sell.
    static func active(on date: Date, calendar: Calendar = .current) -> [SailorSeason] {
        all.filter { $0.isActive(on: date, calendar: calendar) && !SailorCatalog.seasonal($0).isEmpty }
    }

    static func == (a: Self, b: Self) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - What is worn

/// The sailor as drawn: every choice already made, winter included. This is
/// what travels to the network opponent (`NetHello.sailor`) — their app draws
/// it from its own art, so it is a handful of ids, not a picture.
struct SailorLook: Codable, Hashable, Sendable {
    var figure = SailorFigure()
    var rank = SailorCatalog.ranks[0].id
    var shirt = SailorCatalog.stripedShirt
    var jacket: String?
    var coat: String?
    var cap: String?

    // Neither the rank nor achievements are drawn on the sailor (customer
    // 31.10): boards and medals tied the clothes to one cut and were not
    // readable in a small avatar. The rank shows as the ring and the badge
    // beside the portrait; the rest belongs to the player card.

    var rankInfo: SailorRank { SailorCatalog.rank(rank) }
}

/// What the player owns and has chosen to wear (stored in `PlayerStats`).
struct SailorWardrobe: Codable, Hashable, Sendable {
    var figure = SailorFigure()
    /// The highest rank bought — the one worn.
    var rank = SailorCatalog.ranks[0].id
    /// Bought items; free ones are owned without being listed.
    var owned: Set<String> = []
    var shirt = SailorCatalog.stripedShirt
    var jacket: String?
    var cap: String? = "cap_sailor"
    /// Put on over everything in winter; `nil` — no winter clothes.
    var winterCoat: String?
    /// Worn instead of `cap` in winter; `nil` — the summer one stays on.
    var winterCap: String?
    var winter: WinterDress = .bySeason

    init() {}

    // MARK: Reads

    var rankIndex: Int { SailorCatalog.rankIndex(rank) ?? 0 }

    /// The only rank on sale — the next one; `nil` at the top of the ladder.
    var nextRank: SailorRank? {
        let next = rankIndex + 1
        return SailorCatalog.ranks.indices.contains(next) ? SailorCatalog.ranks[next] : nil
    }

    func owns(_ item: SailorItem) -> Bool { item.isFree || owned.contains(item.id) }

    /// The highest tier owned in a section; 0 — nothing yet (the free tier-1
    /// shirt and cap count as owned).
    func topTier(_ slot: SailorSlot) -> Int {
        SailorCatalog.ladder(slot).filter(owns).map(\.tier).max() ?? 0
    }

    /// Shown in the wardrobe. A ladder opens one step at a time: the next tier
    /// appears once the one below it is bought (customer 02.11). A seasonal
    /// item shows in its season, and always once owned.
    func reveals(_ item: SailorItem, on date: Date = .now) -> Bool {
        if item.tier > 0 { return item.tier <= topTier(item.slot) + 1 }
        return owns(item) || SailorSeason.season(item.season)?.isActive(on: date) == true
    }

    /// The rank is high enough to buy it.
    func allows(_ item: SailorItem) -> Bool {
        guard let minRank = item.minRank, let needed = SailorCatalog.rankIndex(minRank) else { return true }
        return rankIndex >= needed
    }

    func isWorn(_ item: SailorItem, winter: Bool = false) -> Bool {
        switch item.slot {
        case .shirt: shirt == item.id
        case .jacket: jacket == item.id
        case .coat: winterCoat == item.id
        case .cap: winter ? winterCap == item.id : cap == item.id
        }
    }

    /// The winter clothes are on today.
    func wearsWinter(isWinterHere: Bool) -> Bool {
        switch winter {
        case .always: true
        case .never: false
        case .bySeason: isWinterHere
        }
    }

    func look(winter: Bool) -> SailorLook {
        SailorLook(figure: figure, rank: rank, shirt: shirt, jacket: jacket,
                   coat: winter ? winterCoat : nil,
                   cap: winter ? (winterCap ?? cap) : cap)
    }

    /// The look as it is today, on this device.
    var currentLook: SailorLook {
        look(winter: wearsWinter(isWinterHere: Season.isWinterHere()))
    }

    // MARK: Changes

    /// Puts an owned item on. In the coat slot that is the winter coat; a cap
    /// goes to the summer or the winter head as `winter` says.
    mutating func wear(_ item: SailorItem, winter: Bool = false) {
        guard owns(item) else { return }
        switch item.slot {
        case .shirt: shirt = item.id
        case .jacket: jacket = item.id
        case .coat: winterCoat = item.id
        case .cap:
            if winter { winterCap = item.id } else { cap = item.id }
        }
    }

    /// The wardrobe with `item` — or nothing — in `slot`, owned or not: the
    /// try-on in the wardrobe screen. Nothing in the shirt slot keeps the shirt.
    func trying(_ item: SailorItem?, in slot: SailorSlot, winter: Bool = false) -> SailorWardrobe {
        var copy = self
        switch slot {
        case .shirt: if let item { copy.shirt = item.id }
        case .jacket: copy.jacket = item?.id
        case .coat: copy.winterCoat = item?.id
        case .cap:
            if winter { copy.winterCap = item?.id } else { copy.cap = item?.id }
        }
        return copy
    }

    /// Takes off what is in a slot. A shirt always stays on.
    mutating func takeOff(_ slot: SailorSlot, winter: Bool = false) {
        switch slot {
        case .shirt: break
        case .jacket: jacket = nil
        case .coat: winterCoat = nil
        case .cap:
            if winter { winterCap = nil } else { cap = nil }
        }
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case figure, rank, owned, shirt, jacket, cap, winterCoat, winterCap, winter
    }

    /// Every key is optional: a field added later must not cost a player
    /// what they bought.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        figure = (try? c.decodeIfPresent(SailorFigure.self, forKey: .figure)) ?? SailorFigure()
        rank = try c.decodeIfPresent(String.self, forKey: .rank) ?? SailorCatalog.ranks[0].id
        owned = try c.decodeIfPresent(Set<String>.self, forKey: .owned) ?? []
        // Something no longer in the catalog (the first, pre-art catalog of
        // 30.10) is taken off rather than drawn as nothing.
        let known = { (id: String?) in SailorCatalog.item(id)?.id }
        shirt = known(try c.decodeIfPresent(String.self, forKey: .shirt)) ?? SailorCatalog.stripedShirt
        jacket = known(try c.decodeIfPresent(String.self, forKey: .jacket))
        // «No cap» is written as null, so a missing key means an older save.
        cap = c.contains(.cap) ? known(try c.decodeIfPresent(String.self, forKey: .cap)) : "cap_sailor"
        winterCoat = known(try c.decodeIfPresent(String.self, forKey: .winterCoat))
        winterCap = known(try c.decodeIfPresent(String.self, forKey: .winterCap))
        winter = (try? c.decodeIfPresent(WinterDress.self, forKey: .winter)) ?? .bySeason
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(figure, forKey: .figure)
        try c.encode(rank, forKey: .rank)
        try c.encode(owned.sorted(), forKey: .owned)
        try c.encode(shirt, forKey: .shirt)
        try c.encodeIfPresent(jacket, forKey: .jacket)
        try c.encode(cap, forKey: .cap)
        try c.encodeIfPresent(winterCoat, forKey: .winterCoat)
        try c.encodeIfPresent(winterCap, forKey: .winterCap)
        try c.encode(winter, forKey: .winter)
    }
}

// MARK: - Buying

extension PlayerStats {
    /// Buys an item and puts it on. RETURNS: whether it was bought — not when it
    /// is owned already, the rank is too low or the points are short.
    mutating func buy(_ item: SailorItem, winter: Bool = false, at date: Date = .now) -> Bool {
        guard !sailor.owns(item), sailor.reveals(item, on: date), sailor.allows(item),
              points >= item.price else { return false }
        points -= item.price
        sailor.owned.insert(item.id)
        sailor.wear(item, winter: winter)
        ledger.addPurchase(item.id, cost: item.price, at: date)
        return true
    }

    /// Buys the next rank. RETURNS: whether it was bought.
    mutating func buyNextRank(at date: Date = .now) -> Bool {
        guard let next = sailor.nextRank, points >= next.price else { return false }
        points -= next.price
        sailor.rank = next.id
        ledger.addPurchase(PointsEntry.rankPurchase(next.id), cost: next.price, at: date)
        return true
    }
}

// MARK: - Player card

/// What the player card («Личное дело») shows besides the sailor: the record
/// and the awards (customer 31.10 — merit lives in the card, not on the
/// sailor). Travels to the network opponent in `NetHello.dossier`, so it is
/// numbers and ids only. The opponent's numbers are taken on trust.
struct PlayerDossier: Codable, Hashable, Sendable {
    var games = 0
    var wins = 0
    /// Nearby and online together — the games against people.
    var networkGames = 0
    var networkWins = 0
    /// Achievement medals, most valuable first, as `medal_<id>_<grade>`
    /// asset suffixes. Achievements are not designed yet (task K5).
    var medals: [String] = []

    init(games: Int = 0, wins: Int = 0, networkGames: Int = 0, networkWins: Int = 0,
         medals: [String] = []) {
        self.games = games
        self.wins = wins
        self.networkGames = networkGames
        self.networkWins = networkWins
        self.medals = medals
    }

    init(_ stats: PlayerStats) {
        let network = [GameMode.nearby, .online].map(stats.record(for:))
        self.init(games: stats.totalGames, wins: stats.totalWins,
                  networkGames: network.reduce(0) { $0 + $1.played },
                  networkWins: network.reduce(0) { $0 + $1.wins })
    }

    /// Share of games won, 0…1; `nil` before the first game.
    var winShare: Double? { games > 0 ? Double(wins) / Double(games) : nil }

    private enum CodingKeys: String, CodingKey { case games, wins, networkGames, networkWins, medals }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(games: (try? c.decodeIfPresent(Int.self, forKey: .games)) ?? 0,
                  wins: (try? c.decodeIfPresent(Int.self, forKey: .wins)) ?? 0,
                  networkGames: (try? c.decodeIfPresent(Int.self, forKey: .networkGames)) ?? 0,
                  networkWins: (try? c.decodeIfPresent(Int.self, forKey: .networkWins)) ?? 0,
                  medals: (try? c.decodeIfPresent([String].self, forKey: .medals)) ?? [])
    }
}
