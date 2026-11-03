//
//  SailorTests.swift
//  SeaBattleTests
//
//  The sailor (30.10): buying ranks and clothes for points, what is worn in
//  winter, and that the wardrobe survives saving and old saves.
//

import Foundation
import Testing
@testable import SeaBattle

struct SailorTests {

    private let morning = Date(timeIntervalSince1970: 1_800_000_000)

    private func item(_ id: String) -> SailorItem {
        SailorCatalog.item(id)!
    }

    // MARK: Buying

    @Test("An item costs its price, goes on and leaves a line in the history")
    func buyingAnItem() {
        let jacket = item("jacket_work")
        var stats = PlayerStats(points: 1000)
        let bought1 = stats.buy(jacket, at: morning)
        #expect(bought1)
        #expect(stats.points == 1000 - jacket.price)
        #expect(stats.sailor.owns(jacket))
        #expect(stats.sailor.jacket == "jacket_work")
        #expect(stats.ledger.entries.first?.amount == -jacket.price)
        #expect(stats.ledger.entries.first?.purchasedItem == "jacket_work")

        // Twice is not a second purchase.
        let bought2 = stats.buy(jacket, at: morning)
        #expect(!bought2)
        #expect(stats.points == 1000 - jacket.price)
    }

    @Test("Short of points or of rank — nothing is bought")
    func blockedPurchases() {
        let coat = item("coat_peacoat")
        var poor = PlayerStats(points: coat.price - 1)
        let bought3 = poor.buy(coat)
        #expect(!bought3)
        #expect(poor.points == coat.price - 1 && poor.ledger.entries.isEmpty)

        // Tier 3 — the officer's jacket — is sold from lieutenant up, and only
        // after tiers 1 and 2 of the same section.
        var rich = PlayerStats(points: 100_000)
        rich.sailor.owned = ["jacket_work", "jacket_petty"]
        #expect(!rich.sailor.allows(item("jacket_officer")))
        let bought4 = rich.buy(item("jacket_officer"))
        #expect(!bought4)
        rich.sailor.rank = "lieutenant"
        let bought5 = rich.buy(item("jacket_officer"))
        #expect(bought5)
    }

    @Test("Each tier is sold from its rank; seasonal items to everybody")
    func tiersFollowRanks() {
        let wardrobe = SailorWardrobe()
        #expect(SailorCatalog.items.filter { $0.tier == 1 }.allSatisfy(wardrobe.allows))
        #expect(SailorCatalog.items.filter { $0.tier == 0 }.allSatisfy(wardrobe.allows))
        #expect(item("cap_petty").minRank == "petty")
        #expect(item("cap_officer").minRank == "lieutenant")
        #expect(!wardrobe.allows(item("cap_petty")))
    }

    @Test("A section's ladder opens one tier at a time")
    func ladderOpensStepByStep() {
        var stats = PlayerStats(points: 100_000)
        stats.sailor.rank = "admiral_fleet"
        // The free tier-1 cap is owned, so tier 2 shows; tier 3 does not yet.
        #expect(stats.sailor.reveals(item("cap_petty")))
        #expect(!stats.sailor.reveals(item("cap_officer")))
        let skipped = stats.buy(item("cap_officer"))
        #expect(!skipped, "a hidden tier cannot be bought")
        // Jackets start with nothing owned: only the work jacket shows.
        #expect(stats.sailor.reveals(item("jacket_work")))
        #expect(!stats.sailor.reveals(item("jacket_petty")))
        let first = stats.buy(item("jacket_work"))
        #expect(first)
        #expect(stats.sailor.reveals(item("jacket_petty")))
        #expect(stats.sailor.topTier(.jacket) == 1)
    }

    @Test("A seasonal item is sold only in its season and kept after it")
    func seasonalSets() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let december = try #require(calendar.date(from: DateComponents(year: 2026, month: 12, day: 20)))
        let january = try #require(calendar.date(from: DateComponents(year: 2027, month: 1, day: 5)))
        let march = try #require(calendar.date(from: DateComponents(year: 2027, month: 3, day: 1)))
        let newYear = try #require(SailorSeason.season("newyear"))
        #expect(newYear.isActive(on: december, calendar: calendar))
        #expect(newYear.isActive(on: january, calendar: calendar), "the window runs over New Year")
        #expect(!newYear.isActive(on: march, calendar: calendar))

        let hat = item("cap_newyear_santa")
        var stats = PlayerStats(points: 1000)
        #expect(!stats.sailor.reveals(hat, on: march))
        let outOfSeason = stats.buy(hat, at: march)
        #expect(!outOfSeason)
        // In season — through the tests' own calendar: `reveals` reads the
        // device calendar, so the date sits well inside the window.
        let inSeason = stats.buy(hat, at: december)
        #expect(inSeason)
        #expect(stats.sailor.reveals(hat, on: march), "owned — shown all year")
    }

    @Test("Long hair shows under a cap; short hair and bare heads need no extra layer")
    func underCapHair() {
        #expect(SailorFigure(hair: "long").underCapHairAsset == "sailor_hair_long_under")
        #expect(SailorFigure(body: .woman, hair: "bob").underCapHairAsset == "sailor_hair_bob_under")
        #expect(SailorFigure(hair: "buzz").underCapHairAsset == nil)
        // Hairstyles are shared by both figures.
        #expect(SailorFigure(body: .man, hair: "ponytail").hair == "ponytail")
        #expect(SailorFigure(body: .woman, hair: "curly").hair == "curly")
    }

    @Test("Ranks are bought one by one, in order")
    func ranksInOrder() {
        var stats = PlayerStats(points: 300)
        #expect(stats.sailor.nextRank?.id == "seaman_senior")
        let bought6 = stats.buyNextRank(at: morning)
        #expect(bought6)
        #expect(stats.sailor.rank == "seaman_senior")
        #expect(stats.points == 200)
        #expect(stats.ledger.entries.first?.purchasedRank == "seaman_senior")
        let bought7 = stats.buyNextRank(at: morning)
        #expect(bought7)
        #expect(stats.sailor.rank == "petty")
        // 300 for the next step, nothing left.
        let bought8 = stats.buyNextRank(at: morning)
        #expect(!bought8)
        #expect(stats.sailor.rank == "petty")
    }

    @Test("At the top of the ladder there is nothing to buy")
    func topRank() {
        var stats = PlayerStats(points: 1_000_000)
        stats.sailor.rank = SailorCatalog.ranks.last!.id
        #expect(stats.sailor.nextRank == nil)
        let bought9 = stats.buyNextRank()
        #expect(!bought9)
    }

    // MARK: Wearing

    @Test("Free items are owned from the start; bought ones only after buying")
    func ownership() {
        let wardrobe = SailorWardrobe()
        #expect(wardrobe.owns(item("shirt_stripes")))
        #expect(wardrobe.owns(item("cap_sailor")))
        #expect(!wardrobe.owns(item("shirt_white")))

        var dressed = wardrobe
        dressed.wear(item("shirt_white"))
        #expect(dressed.shirt == "shirt_stripes", "an item not owned does not go on")
    }

    @Test("Winter puts the coat and the winter cap on; summer takes them off")
    func winterLook() {
        var wardrobe = SailorWardrobe()
        wardrobe.owned = ["coat_peacoat", "cap_newyear_santa"]
        wardrobe.wear(item("coat_peacoat"))
        wardrobe.wear(item("cap_newyear_santa"), winter: true)

        let summer = wardrobe.look(winter: false)
        #expect(summer.coat == nil)
        #expect(summer.cap == "cap_sailor")

        let winter = wardrobe.look(winter: true)
        #expect(winter.coat == "coat_peacoat")
        #expect(winter.cap == "cap_newyear_santa")

        // Without a winter cap the summer one stays on.
        wardrobe.takeOff(.cap, winter: true)
        #expect(wardrobe.look(winter: true).cap == "cap_sailor")
    }

    @Test("The setting decides when the winter clothes are on")
    func winterSetting() {
        var wardrobe = SailorWardrobe()
        #expect(wardrobe.wearsWinter(isWinterHere: true))
        #expect(!wardrobe.wearsWinter(isWinterHere: false))
        wardrobe.winter = .always
        #expect(wardrobe.wearsWinter(isWinterHere: false))
        wardrobe.winter = .never
        #expect(!wardrobe.wearsWinter(isWinterHere: true))
    }

    @Test("A rank this build does not know reads as the highest it knows")
    func unknownRank() {
        #expect(SailorCatalog.rank("grand_admiral_2030").id == SailorCatalog.ranks.last!.id)
    }

    // MARK: Season

    @Test("Winter months depend on the hemisphere, and the tropics have none")
    func seasons() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let january = try #require(calendar.date(from: DateComponents(year: 2027, month: 1, day: 15)))
        let july = try #require(calendar.date(from: DateComponents(year: 2027, month: 7, day: 15)))

        #expect(Season.isWinter(on: january, region: "NL", calendar: calendar))
        #expect(!Season.isWinter(on: july, region: "NL", calendar: calendar))
        #expect(!Season.isWinter(on: january, region: "AU", calendar: calendar))
        #expect(Season.isWinter(on: july, region: "AU", calendar: calendar))
        #expect(!Season.isWinter(on: january, region: "SG", calendar: calendar))
        #expect(!Season.isWinter(on: july, region: "SG", calendar: calendar))
        // No region — the north.
        #expect(Season.isWinter(on: january, region: nil, calendar: calendar))
    }

    // MARK: Saving

    @Test("The wardrobe survives saving, «no cap» included")
    func roundTrip() throws {
        var stats = PlayerStats(points: 5000)
        let bought10 = stats.buy(item("jacket_work"))
        #expect(bought10)
        let bought11 = stats.buyNextRank()
        #expect(bought11)
        stats.sailor.figure = SailorFigure(body: .woman, skinTone: 3, hair: "curly", hairColor: 6)
        stats.sailor.takeOff(.cap)
        stats.sailor.winter = .never

        let data = try JSONEncoder().encode(stats)
        let back = try JSONDecoder().decode(PlayerStats.self, from: data)
        #expect(back.sailor == stats.sailor)
        #expect(back.sailor.cap == nil)
        #expect(back.ledger.entries.count == 2)
    }

    @Test("Statistics saved before the sailor load with a starting sailor")
    func oldSave() throws {
        let json = #"{"records":{},"unattributedLosses":0,"points":42}"#
        let stats = try JSONDecoder().decode(PlayerStats.self, from: Data(json.utf8))
        #expect(stats.points == 42)
        #expect(stats.sailor == SailorWardrobe())
        #expect(stats.sailor.cap == "cap_sailor")
    }

    @Test("A figure saved before hair, and clothes no longer sold, still load")
    func olderWardrobe() throws {
        let json = #"{"figure":{"body":"m","skinTone":2},"rank":"seaman","owned":["jacket_black"],"#
            + #""shirt":"shirt_blue","jacket":"jacket_black","cap":"cap_winter","winter":"bySeason"}"#
        let wardrobe = try JSONDecoder().decode(SailorWardrobe.self, from: Data(json.utf8))
        #expect(wardrobe.figure == SailorFigure(skinTone: 2))
        #expect(wardrobe.figure.hair == "short")
        // Taken off rather than drawn as nothing.
        #expect(wardrobe.shirt == SailorCatalog.stripedShirt)
        #expect(wardrobe.jacket == nil)
        #expect(wardrobe.cap == nil)
    }

    @Test("Resetting statistics keeps the sailor")
    func resetKeepsSailor() {
        var stats = PlayerStats(points: 1000)
        let bought12 = stats.buy(item("coat_peacoat"))
        #expect(bought12)
        let sailor = stats.sailor
        stats.reset(StatsReset(modes: Set(StatsSummary.shownModes)))
        #expect(stats.sailor == sailor)
    }

    // MARK: Network

    @Test("The hello carries the sailor, and an old hello without it still decodes")
    func helloCarriesSailor() throws {
        let look = SailorLook(figure: SailorFigure(skinTone: 4, hair: "slick", hairColor: 2),
                              rank: "captain_1", shirt: "shirt_white", jacket: "jacket_officer")
        let hello = NetHello(name: "Аня", glyph: "helm", colorIndex: 1, accountID: "a",
                             nonce: 7, version: 2, sailor: look)
        let back = try JSONDecoder().decode(NetHello.self, from: JSONEncoder().encode(hello))
        #expect(back.sailor == look)

        let old = #"{"name":"Б","glyph":"helm","colorIndex":0,"accountID":"b","nonce":1,"version":2}"#
        #expect(try JSONDecoder().decode(NetHello.self, from: Data(old.utf8)).sailor == nil)
    }

    // MARK: Player card

    @Test("The dossier counts all games and the games against people apart")
    func dossierFromStats() throws {
        var stats = PlayerStats()
        stats.recordWin(.computer(.hard))
        stats.addLoss(.computer(.easy))
        stats.recordWin(.online)
        stats.addLoss(.nearby)
        let dossier = PlayerDossier(stats)
        #expect(dossier.games == 4)
        #expect(dossier.wins == 2)
        #expect(dossier.networkGames == 2)
        #expect(dossier.networkWins == 1)
        #expect(dossier.winShare == 0.5)
        #expect(PlayerDossier().winShare == nil)

        let hello = NetHello(name: "Аня", glyph: "helm", colorIndex: 1, accountID: "a",
                             nonce: 7, version: 2, sailor: SailorLook(), dossier: dossier)
        let back = try JSONDecoder().decode(NetHello.self, from: JSONEncoder().encode(hello))
        #expect(back.dossier == dossier)
    }
}
