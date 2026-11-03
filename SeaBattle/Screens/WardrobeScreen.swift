//
//  WardrobeScreen.swift
//  Sea Battle — моряк: звание, фигура, одежда (заказчик 30.10)
//
//  Открывается строкой «Моряк» из кошелька — баллы тратятся здесь. Сверху
//  закреплена карточка с моряком: на нём видно и надетое, и примеряемое.
//  Нажатие на свою вещь надевает её сразу; на чужую — примеряет, а купить
//  можно кнопкой под портретом. Покупка тратит баллы безвозвратно, поэтому
//  отдельной кнопкой, а не нажатием на плитку.
//
//  Звания продаются по одному: видно только следующее (заказчик 30.10 —
//  лестница может расти без конца, и игрок не видит, сколько ещё впереди).
//

import SwiftUI

enum WardrobeMetrics {
    static let blockGap: CGFloat = 12
    static let cardPadding: CGFloat = 14
    static let cardRadius: CGFloat = 22
    static let portrait: CGFloat = 128
    static let padPortrait: CGFloat = 168
    static let portraitRadius: CGFloat = 18
    static let rankName: CGFloat = 17
    static let rankBadge: CGFloat = 24
    static let rowBadge: CGFloat = 30
    static let caption: CGFloat = 12.5
    static let tile: CGFloat = 76
    static let tileWidth: CGFloat = 84
    static let tileRadius: CGFloat = 14
    static let tileTitle: CGFloat = 11.5
    static let tileGap: CGFloat = 10
    static let swatch: CGFloat = 34
}

/// Что портрет показывает поверх надетого.
enum WardrobeTryOn: Equatable {
    case item(SailorItem, winter: Bool)
    case rank(SailorRank)
}

/// Плитка выбора: вещь — или «ничего» в этом месте.
struct WardrobeTile: Identifiable, Hashable {
    let slot: SailorSlot
    let item: SailorItem?
    /// Зимний комплект: бушлат и зимний головной убор.
    let winter: Bool

    var id: String { "\(slot.rawValue).\(winter).\(item?.id ?? "none")" }

    /// Лестница раздела, открытая по ступень после купленной (заказчик 02.11),
    /// и купленные сезонные вещи — их носят круглый год.
    static func row(_ slot: SailorSlot, winter: Bool = false, wardrobe: SailorWardrobe,
                    date: Date) -> [WardrobeTile] {
        let ladder = SailorCatalog.ladder(slot).filter { wardrobe.reveals($0, on: date) }
        let seasonal = SailorCatalog.items(in: slot).filter { $0.tier == 0 && wardrobe.owns($0) }
        let items = (ladder + seasonal).map { WardrobeTile(slot: slot, item: $0, winter: winter) }
        // Рубашку не снять — у остальных первая плитка «без».
        return slot == .shirt ? items : [WardrobeTile(slot: slot, item: nil, winter: winter)] + items
    }

    /// Полка сезона: всё из его набора, купленное и нет.
    static func season(_ season: SailorSeason) -> [WardrobeTile] {
        SailorCatalog.seasonal(season).map { WardrobeTile(slot: $0.slot, item: $0, winter: false) }
    }
}

struct WardrobeScreen: View {
    let wardrobe: SailorWardrobe
    let points: Int
    var onBack: () -> Void = {}
    /// Купить вещь и надеть: в зимний комплект или в летний.
    var onBuy: (SailorItem, Bool) -> Void = { _, _ in }
    var onBuyRank: () -> Void = {}
    /// Надеть, снять, сменить фигуру — уже купленное.
    var onChange: (SailorWardrobe) -> Void = { _ in }
    /// Скромный «+» у баланса — купить баллы (заказчик 03.11); `nil` — без него.
    var onBuyPoints: (() -> Void)?

    @State private var showsWinter: Bool
    @State private var tryOn: WardrobeTryOn?
    /// Своё «Личное дело» — нажатием на моряка (К4).
    @State private var showsCard = false
    /// Имя и счёт для «Личного дела».
    var ownerName = ""
    var dossier: PlayerDossier?
    var book: AchievementBook?
    /// Показать «Личное дело» над всем экраном, таб-бар тоже затемнив;
    /// `nil` — показать внутри экрана (превью).
    var onCard: ((PlayerCardInfo) -> Void)?
    /// Сегодня — от него зависят сезонные наборы. Превью и тесты подставляют
    /// свою дату.
    let now: Date

    @Environment(\.locale) private var locale
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(wardrobe: SailorWardrobe, points: Int,
         onBack: @escaping () -> Void = {},
         onBuy: @escaping (SailorItem, Bool) -> Void = { _, _ in },
         onBuyRank: @escaping () -> Void = {},
         onChange: @escaping (SailorWardrobe) -> Void = { _ in },
         ownerName: String = "",
         dossier: PlayerDossier? = nil,
         book: AchievementBook? = nil,
         onCard: ((PlayerCardInfo) -> Void)? = nil,
         onBuyPoints: (() -> Void)? = nil,
         now: Date = .now) {
        self.onCard = onCard
        self.onBuyPoints = onBuyPoints
        self.now = now
        self.ownerName = ownerName
        self.dossier = dossier
        self.book = book
        self.wardrobe = wardrobe
        self.points = points
        self.onBack = onBack
        self.onBuy = onBuy
        self.onBuyRank = onBuyRank
        self.onChange = onChange
        // Сначала — как моряк одет сегодня.
        _showsWinter = State(initialValue: wardrobe.wearsWinter(isWinterHere: Season.isWinterHere()))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenTitle(title: "Sailor", back: "Points", onBack: onBack)
                .padding(.top, NavMetrics.titleTopBelowSafeArea)

            // Моряк закреплён под заголовком: примерку видно из любого места
            // списка. На AX1–AX5 карточка занимала бы весь экран — там она
            // прокручивается вместе со списком.
            if !isLarge {
                card
                    .padding(.horizontal, Geometry.Nav.stackInset)
                    .padding(.top, Geometry.Nav.titleGap * 2)
            }

            ScrollView {
                VStack(spacing: WardrobeMetrics.blockGap) {
                    if isLarge { card }
                    // Сезонный набор — первым под моряком: он ненадолго (заказчик 02.11).
                    ForEach(SailorSeason.active(on: now), id: \.id) { season in
                        tileGroup(SailorSeason.title(season.id), tiles: WardrobeTile.season(season))
                    }
                    rankGroup
                    figureGroup
                    tileGroup("Headwear", tiles: row(.cap))
                    tileGroup("Shirt", tiles: row(.shirt))
                    tileGroup("Jacket", tiles: row(.jacket))
                    tileGroup("Winter clothes", tiles: row(.coat, winter: true))
                    tileGroup("Winter headwear", tiles: row(.cap, winter: true))
                }
                .padding(.horizontal, Geometry.Nav.stackInset)
                .padding(.vertical, WardrobeMetrics.blockGap)
            }
            .seaScroll()
        }
        .animation(Motion.quick, value: tryOn)
        .playerCard(showsCard ? PlayerCardInfo(name: ownerName, look: wardrobe.currentLook,
                                               dossier: dossier, book: book) : nil) {
            showsCard = false
        }
    }

    // MARK: Моряк

    private var shownLook: SailorLook {
        switch tryOn {
        case .item(let item, let winter):
            // Примеряемая зимняя вещь показывается на зимнем моряке.
            return wardrobe.trying(item, in: item.slot, winter: winter).look(winter: showsWinter)
        case .rank(let rank):
            var look = wardrobe.look(winter: showsWinter)
            look.rank = rank.id
            return look
        case nil:
            return wardrobe.look(winter: showsWinter)
        }
    }

    private var portraitSide: CGFloat {
        sizeClass == .regular ? WardrobeMetrics.padPortrait : WardrobeMetrics.portrait
    }

    /// Крупный текст (AX1–AX5): карточка столбцом и не закреплена.
    private var isLarge: Bool { dynamicTypeSize.isAccessibilitySize }

    private var card: some View {
        let look = shownLook
        let shape = RoundedRectangle(cornerRadius: WardrobeMetrics.portraitRadius, style: .continuous)
        let layout = isLarge ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
                             : AnyLayout(HStackLayout(alignment: .top, spacing: 14))
        return VStack(alignment: .leading, spacing: 12) {
            layout {
                Button {
                    let info = PlayerCardInfo(name: ownerName, look: wardrobe.currentLook,
                                              dossier: dossier, book: book)
                    if let onCard { onCard(info) } else { showsCard = true }
                } label: {
                    SailorPortrait(look: look)
                        .frame(width: portraitSide, height: portraitSide)
                        .background(SailorCanvas.backdrop)
                        .clipShape(shape)
                        .overlay(shape.strokeBorder(look.rankInfo.group.ring, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Service record"))
                .accessibilityIdentifier("wardrobeCard")

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        RankBadge(rank: look.rankInfo, size: WardrobeMetrics.rankBadge)
                        Text(look.rankInfo.title)
                            .font(.scalable(size: WardrobeMetrics.rankName, weight: .bold))
                            .foregroundStyle(Color.inkPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    HStack(spacing: 6) {
                        Image(systemName: PointsSymbol.name)
                            .foregroundStyle(Color.roleYou)
                            .accessibilityHidden(true)
                        Text("\(points) points")
                            .monospacedDigit()
                            .foregroundStyle(Color.inkSecondary)
                        if let onBuyPoints {
                            BuyPointsPlus(action: onBuyPoints)
                                .padding(.leading, 2)
                        }
                    }
                    .font(.scalable(size: WardrobeMetrics.caption))
                    .accessibilityElement(children: .contain)
                    Spacer(minLength: 0)
                    SegmentedPick(options: [(false, String(game: "Summer", locale: locale)),
                                            (true, String(game: "Winter", locale: locale))],
                                  selection: $showsWinter)
                        .accessibilityIdentifier("wardrobeSeason")
                }
                .frame(maxWidth: .infinity, minHeight: isLarge ? nil : portraitSide, alignment: .leading)
            }
            // Карточка высотой с портрет, а не со всё свободное место экрана.
            .fixedSize(horizontal: false, vertical: true)
            if let tryOn {
                buyBar(tryOn)
                    .transition(.opacity)
            }
        }
        .padding(WardrobeMetrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(.g2, radius: WardrobeMetrics.cardRadius, highlight: .selected)
    }

    // MARK: Покупка

    @ViewBuilder
    private func buyBar(_ tryOn: WardrobeTryOn) -> some View {
        let (title, price, blocker) = details(of: tryOn)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                title
                    .font(.scalable(size: ListMetrics.rowTitle, weight: .medium))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    self.tryOn = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.scalable(size: 14, weight: .semibold))
                        .foregroundStyle(Color.inkSecondary)
                        .frame(width: Geometry.Hit.minTarget, height: Geometry.Hit.minTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // Крестик в углу строки, а не строка выше на 44 pt.
                .padding(.vertical, -12)
                .accessibilityLabel(Text("Cancel"))
            }
            if let blocker {
                blocker
                    .font(.scalable(size: WardrobeMetrics.caption))
                    .foregroundStyle(Color.inkSecondary)
            }
            Button {
                buy(tryOn)
            } label: {
                HStack(spacing: 6) {
                    Text("Buy")
                    Image(systemName: PointsSymbol.name)
                    Text(verbatim: "\(price)").monospacedDigit()
                }
            }
            .primaryButton(enabled: blocker == nil)
            .accessibilityIdentifier("wardrobeBuy")
        }
    }

    /// Название, цена и почему купить нельзя (`nil` — можно).
    private func details(of tryOn: WardrobeTryOn) -> (Text, Int, Text?) {
        switch tryOn {
        case .item(let item, _):
            let blocker: Text?
            if !wardrobe.allows(item), let rank = item.minRank {
                blocker = Text("Sold from the rank \(Text(SailorCatalog.rank(rank).title))")
            } else if points < item.price {
                blocker = Text("Not enough points")
            } else {
                blocker = nil
            }
            return (Text(item.title), item.price, blocker)
        case .rank(let rank):
            return (Text(rank.title), rank.price, points < rank.price ? Text("Not enough points") : nil)
        }
    }

    private func buy(_ tryOn: WardrobeTryOn) {
        switch tryOn {
        case .item(let item, let winter): onBuy(item, winter)
        case .rank: onBuyRank()
        }
        self.tryOn = nil
    }

    // MARK: Звание

    private var rankGroup: some View {
        let current = SailorCatalog.rank(wardrobe.rank)
        return ListGroup("Rank") {
            rankRow(current, caption: "Your rank", price: nil)
            if let next = wardrobe.nextRank {
                Button {
                    tryOn = .rank(next)
                } label: {
                    rankRow(next, caption: "Next rank", price: next.price)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("wardrobeNextRank")
            } else {
                ListRow(title: "Highest rank", subtitle: "New ranks will come with updates")
            }
        }
    }

    private func rankRow(_ rank: SailorRank, caption: LocalizedStringKey, price: Int?) -> some View {
        HStack(spacing: 12) {
            RankBadge(rank: rank, size: WardrobeMetrics.rowBadge)
            VStack(alignment: .leading, spacing: 2) {
                Text(rank.title)
                    .font(.scalable(size: ListMetrics.rowTitle, weight: .medium))
                    .foregroundStyle(Color.inkPrimary)
                Text(caption)
                    .font(.scalable(size: ListMetrics.rowSubtitle))
                    .foregroundStyle(Color.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let price {
                priceLabel(price)
                Image(systemName: "chevron.right")
                    .font(.scalable(size: symbolFontSize(inBox: ListMetrics.chevron), weight: .semibold))
                    .foregroundStyle(Color.inkTertiary)
            }
        }
        .padding(.vertical, ListMetrics.rowPaddingV)
        .padding(.horizontal, ListMetrics.rowPaddingH)
        .frame(minHeight: Geometry.Hit.minTarget)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func priceLabel(_ price: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: PointsSymbol.name)
                .foregroundStyle(Color.roleYou)
            Text(verbatim: "\(price)")
                .monospacedDigit()
                .foregroundStyle(Color.inkSecondary)
        }
        .font(.scalable(size: ListMetrics.rowValue))
    }

    // MARK: Фигура

    /// Фигура, кожа, причёска и цвет волос — бесплатно (заказчик 02.11).
    private var figureGroup: some View {
        ListGroup("Figure") {
            VStack(alignment: .leading, spacing: ListMetrics.stackGap) {
                SegmentedPick(options: [(SailorBody.man, String(game: "Man", locale: locale)),
                                        (SailorBody.woman, String(game: "Woman", locale: locale))],
                              selection: Binding(get: { wardrobe.figure.body },
                                                 set: { body in change { $0.figure.body = body } }))
                    .accessibilityIdentifier("wardrobeBody")
                swatchRow("Skin tone", values: Array(SailorFigure.skinTones),
                          selected: wardrobe.figure.skinTone, color: SailorPalette.skin) { tone in
                    change { $0.figure.skinTone = tone }
                }
                swatchRow("Hair colour", values: Array(SailorFigure.hairColors),
                          selected: wardrobe.figure.hairColor, color: SailorPalette.hair) { color in
                    change { $0.figure.hairColor = color }
                }
            }
            .padding(.vertical, ListMetrics.rowPaddingV)
            .padding(.horizontal, ListMetrics.rowPaddingH)
            hairRow
        }
    }

    /// Название и кружки цветов под ним — сеткой: восемь цветов волос в одну
    /// строку на iPhone mini не помещаются.
    private func swatchRow(_ title: LocalizedStringKey, values: [Int], selected: Int,
                           color: @escaping (Int) -> Color,
                           onSelect: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.scalable(size: ListMetrics.rowTitle, weight: .medium))
                .foregroundStyle(Color.inkPrimary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: Geometry.Hit.minTarget), spacing: 0)],
                      alignment: .leading, spacing: 0) {
                ForEach(values, id: \.self) { value in
                    swatch(color(value), isSelected: value == selected,
                           label: Text("\(Text(title)) \(value)")) { onSelect(value) }
                }
            }
        }
    }

    private func swatch(_ color: Color, isSelected: Bool, label: Text,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: WardrobeMetrics.swatch, height: WardrobeMetrics.swatch)
                .overlay(Circle().strokeBorder(isSelected ? Color.roleYou : Color.glassStroke,
                                               lineWidth: isSelected ? 3 : 1))
                .frame(minWidth: Geometry.Hit.minTarget, minHeight: Geometry.Hit.minTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Причёски — плитками без убора: под убором причёски не видно.
    private var hairRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: WardrobeMetrics.tileGap) {
                ForEach(SailorFigure.hairStyles, id: \.self) { hair in
                    hairTile(hair)
                }
            }
            .padding(.vertical, ListMetrics.rowPaddingV)
            .padding(.horizontal, ListMetrics.rowPaddingH)
        }
    }

    private func hairTile(_ hair: String) -> some View {
        let isSelected = wardrobe.figure.hair == hair
        var look = wardrobe.look(winter: false)
        look.figure.hair = hair
        look.cap = nil
        let shape = RoundedRectangle(cornerRadius: WardrobeMetrics.tileRadius, style: .continuous)
        return Button {
            change { $0.figure.hair = hair }
        } label: {
            VStack(spacing: 6) {
                SailorPortrait(look: look)
                    .frame(width: WardrobeMetrics.tile, height: WardrobeMetrics.tile)
                    .background(SailorCanvas.backdrop)
                    .clipShape(shape)
                    .overlay(shape.strokeBorder(isSelected ? Color.roleYou : Color.glassStroke,
                                                lineWidth: isSelected ? 2 : 1))
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(Color.inkOnBrass, Color.roleYou)
                                .padding(4)
                        }
                    }
                Text(SailorFigure.hairTitle(hair))
                    .font(.scalable(size: WardrobeMetrics.tileTitle))
                    .foregroundStyle(Color.inkPrimary)
                    .multilineTextAlignment(.center)
                    // Две строки всегда: иначе цены под однострочными
                    // названиями встают выше, чем под двухстрочными.
                    .lineLimit(2, reservesSpace: true)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: WardrobeMetrics.tileWidth)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(SailorFigure.hairTitle(hair)))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("wardrobeHair.\(hair)")
    }

    // MARK: Одежда

    private func tileGroup(_ title: LocalizedStringKey, tiles: [WardrobeTile]) -> some View {
        ListGroup(title) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: WardrobeMetrics.tileGap) {
                    ForEach(tiles) { tileView($0) }
                }
                .padding(.vertical, ListMetrics.rowPaddingV)
                .padding(.horizontal, ListMetrics.rowPaddingH)
            }
        }
    }

    private func row(_ slot: SailorSlot, winter: Bool = false) -> [WardrobeTile] {
        WardrobeTile.row(slot, winter: winter, wardrobe: wardrobe, date: now)
    }

    private func isWorn(_ tile: WardrobeTile) -> Bool {
        if let item = tile.item { return wardrobe.isWorn(item, winter: tile.winter) }
        switch tile.slot {
        case .shirt: return false
        case .jacket: return wardrobe.jacket == nil
        case .coat: return wardrobe.winterCoat == nil
        case .cap: return tile.winter ? wardrobe.winterCap == nil : wardrobe.cap == nil
        }
    }

    private func tileTitle(_ tile: WardrobeTile) -> Text {
        if let item = tile.item { return Text(item.title) }
        // Без зимнего убора на голове остаётся летний.
        return tile.winter && tile.slot == .cap ? Text("As in summer") : Text("None")
    }

    private func tileView(_ tile: WardrobeTile) -> some View {
        let worn = isWorn(tile)
        let owned = tile.item.map(wardrobe.owns) ?? true
        let allowed = tile.item.map(wardrobe.allows) ?? true
        let trying = tile.item.map { tryOn == .item($0, winter: tile.winter) } ?? false
        let shape = RoundedRectangle(cornerRadius: WardrobeMetrics.tileRadius, style: .continuous)
        var look = wardrobe.trying(tile.item, in: tile.slot, winter: tile.winter).look(winter: tile.winter)
        // Рубашку под кителем не разглядеть — на её плитке моряк без кителя.
        if tile.slot == .shirt { look.jacket = nil }
        return Button {
            tap(tile)
        } label: {
            VStack(spacing: 6) {
                SailorPortrait(look: look)
                    .frame(width: WardrobeMetrics.tile, height: WardrobeMetrics.tile)
                    .background(SailorCanvas.backdrop)
                    .clipShape(shape)
                    .overlay(shape.strokeBorder(worn ? Color.roleYou : (trying ? Color.inkPrimary : Color.glassStroke),
                                                lineWidth: worn || trying ? 2 : 1))
                    .overlay(alignment: .topTrailing) {
                        if worn {
                            Image(systemName: "checkmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(Color.inkOnBrass, Color.roleYou)
                                .padding(4)
                        } else if !allowed {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(Color.inkPrimary)
                                .padding(5)
                        }
                    }
                tileTitle(tile)
                    .font(.scalable(size: WardrobeMetrics.tileTitle))
                    .foregroundStyle(Color.inkPrimary)
                    .multilineTextAlignment(.center)
                    // Две строки всегда: иначе цены под однострочными
                    // названиями встают выше, чем под двухстрочными.
                    .lineLimit(2, reservesSpace: true)
                    .fixedSize(horizontal: false, vertical: true)
                if let item = tile.item, !owned {
                    HStack(spacing: 3) {
                        Image(systemName: PointsSymbol.name)
                            .foregroundStyle(Color.roleYou)
                        Text(verbatim: "\(item.price)")
                            .monospacedDigit()
                            .foregroundStyle(Color.inkSecondary)
                    }
                    .font(.scalable(size: WardrobeMetrics.tileTitle))
                }
            }
            .frame(width: WardrobeMetrics.tileWidth)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tileTitle(tile))
        .accessibilityValue(tileValue(tile, worn: worn, owned: owned, allowed: allowed))
        .accessibilityAddTraits(worn ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("wardrobeTile.\(tile.id)")
    }

    private func tileValue(_ tile: WardrobeTile, worn: Bool, owned: Bool, allowed: Bool) -> Text {
        if worn { return Text("Worn") }
        if owned { return Text("Owned") }
        if !allowed { return Text("Locked") }
        return Text("\(tile.item?.price ?? 0) points")
    }

    private func tap(_ tile: WardrobeTile) {
        showsWinter = tile.winter
        if let item = tile.item, !wardrobe.owns(item) {
            tryOn = .item(item, winter: tile.winter)
            return
        }
        tryOn = nil
        change { wardrobe in
            if let item = tile.item {
                wardrobe.wear(item, winter: tile.winter)
            } else {
                wardrobe.takeOff(tile.slot, winter: tile.winter)
            }
        }
    }

    private func change(_ edit: (inout SailorWardrobe) -> Void) {
        var copy = wardrobe
        edit(&copy)
        guard copy != wardrobe else { return }
        onChange(copy)
    }
}

// MARK: - Превью

private struct WardrobeDemo: View {
    @State var wardrobe: SailorWardrobe
    @State var points: Int
    var now: Date = .now

    var body: some View {
        ZStack {
            SeaBackground().ignoresSafeArea()
            WardrobeScreen(wardrobe: wardrobe, points: points,
                           onBuy: { item, winter in
                               var stats = PlayerStats(points: points, sailor: wardrobe)
                               if stats.buy(item, winter: winter, at: now) {
                                   wardrobe = stats.sailor
                                   points = stats.points
                               }
                           },
                           onBuyRank: {
                               var stats = PlayerStats(points: points, sailor: wardrobe)
                               if stats.buyNextRank() {
                                   wardrobe = stats.sailor
                                   points = stats.points
                               }
                           },
                           onChange: { wardrobe = $0 },
                           onBuyPoints: {},
                           now: now)
        }
    }
}

#Preview("Моряк · новичок") {
    WardrobeDemo(wardrobe: SailorWardrobe(), points: 240)
        .preferredColorScheme(.dark)
}

#Preview("Моряк · Новый год") {
    var wardrobe = SailorWardrobe()
    wardrobe.rank = "petty"
    wardrobe.owned = ["jacket_work", "cap_petty"]
    wardrobe.jacket = "jacket_work"
    wardrobe.cap = "cap_petty"
    let december = Calendar.current.date(from: DateComponents(year: 2026, month: 12, day: 15)) ?? .now
    return WardrobeDemo(wardrobe: wardrobe, points: 900, now: december)
        .preferredColorScheme(.dark)
}

#Preview("Моряк · лейтенант") {
    var wardrobe = SailorWardrobe()
    wardrobe.rank = "lieutenant"
    wardrobe.figure = SailorFigure(skinTone: 4, hair: "curly", hairColor: 1)
    wardrobe.owned = ["shirt_white", "jacket_officer", "cap_officer", "coat_peacoat"]
    wardrobe.shirt = "shirt_white"
    wardrobe.jacket = "jacket_officer"
    wardrobe.cap = "cap_officer"
    wardrobe.winterCoat = "coat_peacoat"
    return WardrobeDemo(wardrobe: wardrobe, points: 3200)
        .preferredColorScheme(.dark)
}

#Preview("Моряк · 375 × 667, женщина, Хэллоуин", traits: .fixedLayout(width: 375, height: 667)) {
    var wardrobe = SailorWardrobe()
    wardrobe.figure = SailorFigure(body: .woman, skinTone: 3, hair: "long", hairColor: 2)
    wardrobe.rank = "lieutenant"
    wardrobe.owned = ["jacket_work", "jacket_petty", "cap_petty", "cap_halloween_witch"]
    wardrobe.jacket = "jacket_petty"
    wardrobe.cap = "cap_halloween_witch"
    let october = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 25)) ?? .now
    return WardrobeDemo(wardrobe: wardrobe, points: 2400, now: october)
        .preferredColorScheme(.dark)
}
