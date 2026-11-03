//
//  SailorPortrait.swift
//  Sea Battle — моряк: портрет из слоёв, кольцо звания, значок звания
//
//  Слои рисуются один над другим на холсте 1024 × 1024 (`docs/SAILOR_ART.md`).
//  Файла слоя ещё нет в каталоге — вместо него заглушка, нарисованная здесь
//  же в тех же координатах холста: механика витрины видна и проверяется до
//  арта, а пришедший файл просто занимает место заглушки.
//
//  Картинку моряка не зеркалим никогда (на iPad зеркалится раскладка, а не
//  портрет): ордена висят слева на груди моряка у обоих игроков.
//

import SwiftUI
import UIKit

// MARK: - Названия

extension SailorItem {
    var title: LocalizedStringKey {
        switch id {
        case "cap_sailor": "Sailor cap"
        case "shirt_stripes": "Striped vest"
        case "jacket_work": "Work jacket"
        case "coat_peacoat": "Pea coat"
        case "cap_petty": "Soft peaked cap"
        case "shirt_jumper": "Sailor jumper"
        case "jacket_petty": "Uniform jacket"
        case "coat_storm": "Oilskin jacket"
        case "cap_officer": "White peaked cap"
        case "shirt_white": "White shirt and tie"
        case "jacket_officer": "Officer's jacket"
        case "coat_officer": "Greatcoat"
        case "cap_captain": "Captain's cap"
        case "shirt_captain": "Dress shirt"
        case "jacket_captain": "White dress jacket"
        case "coat_captain": "Captain's coat"
        case "cap_admiral": "Admiral's cap"
        case "shirt_admiral": "Admiral's shirt"
        case "jacket_admiral": "Admiral's jacket"
        case "coat_admiral": "Admiral's cloak"
        case "cap_newyear_santa": "Santa hat"
        case "jacket_newyear_santa": "Santa coat"
        case "shirt_newyear_sweater": "Christmas jumper"
        case "coat_newyear_frost": "Blue Father Frost coat"
        case "cap_newyear_deer": "Reindeer antlers"
        case "cap_newyear_elf": "Elf hat"
        case "cap_halloween_pirate": "Pirate hat"
        case "jacket_halloween_pirate": "Pirate coat"
        case "shirt_halloween_skeleton": "Skeleton T-shirt"
        case "coat_halloween_vampire": "Vampire cloak"
        case "cap_halloween_witch": "Witch hat"
        default: "Item"
        }
    }
}

extension SailorSeason {
    static func title(_ id: String) -> LocalizedStringKey {
        switch id {
        case "newyear": "New Year"
        case "halloween": "Halloween"
        default: "Season"
        }
    }
}

extension SailorFigure {
    static func hairTitle(_ hair: String) -> LocalizedStringKey {
        switch hair {
        case "short": "Short"
        case "buzz": "Buzz cut"
        case "curly": "Curls"
        case "curlshort": "Short curls"
        case "slick": "Slicked back"
        case "pixie": "Pixie cut"
        case "bob": "Bob"
        case "bun": "Bun"
        case "ponytail": "Ponytail"
        case "long": "Long hair"
        default: "Hairstyle"
        }
    }
}

/// Цвета кожи и волос. Арт кожи и волос серый (`docs/SAILOR_ART.md`), цвет
/// даёт умножение: почти белое становится этим цветом, тени — темнее его.
/// Светлые волосы песочные, а не жёлтые: серые брови, умноженные на жёлтый,
/// выходят оливковыми (проверено 02.11).
enum SailorPalette {
    static let skins: [Int: Color] = [
        1: Color(hex: 0xF7D9C4), 2: Color(hex: 0xEDC3A2), 3: Color(hex: 0xD9A47C),
        4: Color(hex: 0xB07A55), 5: Color(hex: 0x7E5238), 6: Color(hex: 0x553524),
    ]
    static let hair: [Int: Color] = [
        1: Color(hex: 0x23201F), 2: Color(hex: 0x4A3324), 3: Color(hex: 0x7A5233),
        4: Color(hex: 0xA5532C), 5: Color(hex: 0xC98E5A), 6: Color(hex: 0xD8BC8E),
        7: Color(hex: 0xE9E2D6), 8: Color(hex: 0x9C9C9C),
    ]

    static func skin(_ tone: Int) -> Color { skins[tone] ?? skins[1]! }
    static func hair(_ color: Int) -> Color { hair[color] ?? hair[3]! }
}

extension SailorRank {
    var title: LocalizedStringKey {
        switch id {
        case "seaman": "Seaman"
        case "seaman_senior": "Able seaman"
        case "petty": "Petty officer"
        case "petty_chief": "Chief petty officer"
        case "warrant": "Warrant officer"
        case "lieutenant": "Lieutenant"
        case "lieutenant_senior": "Senior lieutenant"
        case "commander_lt": "Lieutenant commander"
        case "captain_3": "Commander"
        case "captain_2": "Captain"
        case "captain_1": "Senior captain"
        case "admiral_rear": "Rear admiral"
        case "admiral_vice": "Vice admiral"
        case "admiral": "Admiral"
        case "admiral_fleet": "Admiral of the fleet"
        default: "Rank"
        }
    }
}

extension RankGroup {
    /// Кольцо вокруг портрета и значка: сталь, бронза, серебро, золото.
    var ring: Color {
        switch self {
        case .enlisted: Color(hex: 0x8E9AA6)
        case .warrant: Color(hex: 0xB8793A)
        case .junior: Color(hex: 0xD5DBE1)
        case .senior: Color(hex: 0xE0B04A)
        case .admiral: Color(hex: 0xF4C95C)
        }
    }

    /// Адмиралам — двойное кольцо: видно издалека, что это не капитан.
    var isDoubleRing: Bool { self == .admiral }
}

// MARK: - Портрет

/// Моряк целиком, квадратом. Фон не рисует — его даёт место, где портрет стоит.
struct SailorPortrait: View {
    let look: SailorLook

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                ForEach(SailorLayer.layers(of: look), id: \.self) { layer in
                    layer.view(side: side)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Один слой портрета. Порядок — `docs/SAILOR_ART.md`: кожа → волосы «под
/// убор» с бровями → лицо → рубашка → верх → зимнее → причёска (только без
/// убора) или её пряди из-под убора (Д6) → убор.
enum SailorLayer: Hashable {
    case skin(SailorFigure)
    case hairBase(SailorFigure)
    case face(SailorFigure)
    case hair(SailorFigure)
    /// Пряди длинной причёски, видные из-под убора (`underCapHairAsset`).
    case underCapHair(SailorFigure)
    case item(SailorItem)

    static func layers(of look: SailorLook) -> [SailorLayer] {
        let figure = look.figure
        var layers: [SailorLayer] = [.skin(figure), .hairBase(figure), .face(figure)]
        for id in [look.shirt, look.jacket, look.coat] {
            if let item = SailorCatalog.item(id) { layers.append(.item(item)) }
        }
        if let cap = SailorCatalog.item(look.cap) {
            if figure.underCapHairAsset != nil { layers.append(.underCapHair(figure)) }
            layers.append(.item(cap))
        } else {
            layers.append(.hair(figure))
        }
        return layers
    }

    var assetName: String {
        switch self {
        case .skin(let figure): figure.skinAsset
        case .hairBase(let figure): figure.hairBaseAsset
        case .face(let figure): figure.faceAsset
        case .hair(let figure): figure.hairAsset
        case .underCapHair(let figure): figure.underCapHairAsset ?? figure.hairAsset
        case .item(let item): item.assetName
        }
    }

    /// Цвет, на который умножается серый арт; `nil` — слой как есть.
    var tint: Color? {
        switch self {
        case .skin(let figure): SailorPalette.skin(figure.skinTone)
        case .hairBase(let figure), .hair(let figure), .underCapHair(let figure):
            SailorPalette.hair(figure.hairColor)
        case .face, .item: nil
        }
    }

    @ViewBuilder
    func view(side: CGFloat) -> some View {
        if UIImage(named: assetName) != nil {
            Image(assetName)
                .resizable()
                .interpolation(.high)
                .colorMultiply(tint ?? .white)
                .frame(width: side, height: side)
        } else {
            Canvas { context, size in
                context.scaleBy(x: size.width / SailorCanvas.size, y: size.height / SailorCanvas.size)
                SailorCanvas.draw(self, in: &context)
            }
            .frame(width: side, height: side)
        }
    }
}

// MARK: - Кольцо и значок

/// Моряк в круге с кольцом звания — аватар игрока в списках, в бою и у
/// соперника по сети.
struct SailorAvatar: View {
    let look: SailorLook
    var size: CGFloat = 44

    var body: some View {
        let group = look.rankInfo.group
        let ring = max(1.5, size * 0.05)
        ZStack {
            Circle().fill(SailorCanvas.backdrop)
            SailorPortrait(look: look)
                // Голова крупнее: по пояс в маленьком круге — это
                // точка вместо лица.
                .scaleEffect(1.35, anchor: UnitPoint(x: 0.5, y: 0.38))
                .clipShape(Circle())
            Circle().strokeBorder(group.ring, lineWidth: ring)
            if group.isDoubleRing {
                Circle().strokeBorder(group.ring.opacity(0.7), lineWidth: ring * 0.5)
                    .padding(ring * 1.6)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(Text(look.rankInfo.title))
    }
}

/// Значок звания (`rank_badge_<звание>`) — рядом с моряком: на самом моряке
/// звания нет (заказчик 31.10). Без файла — кольцо группы и полоски или звёзды.
struct RankBadge: View {
    let rank: SailorRank
    var size: CGFloat = 22

    var body: some View {
        Group {
            if UIImage(named: rank.badgeAsset) != nil {
                Image(rank.badgeAsset).resizable().interpolation(.high)
            } else {
                ZStack {
                    Circle().fill(Color(hex: 0x1E2E52))
                    Circle().strokeBorder(rank.group.ring, lineWidth: max(1, size * 0.08))
                    marks
                        .foregroundStyle(rank.group == .enlisted ? Color(hex: 0xE8C34A) : rank.group.ring)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(Text(rank.title))
    }

    @ViewBuilder
    private var marks: some View {
        let count = max(rank.marks, 0)
        if count == 0 {
            // Матрос: знаков нет, только кружок — значок не пустой.
            Circle().frame(width: size * 0.22, height: size * 0.22)
        } else if rank.group == .enlisted {
            VStack(spacing: size * 0.06) {
                ForEach(0..<count, id: \.self) { _ in
                    Capsule().frame(width: size * 0.46, height: size * 0.09)
                }
            }
        } else {
            let star = size * (count > 2 ? 0.2 : 0.28)
            HStack(spacing: size * 0.02) {
                ForEach(0..<count, id: \.self) { _ in
                    Image(systemName: "star.fill").font(.system(size: star, weight: .bold))
                }
            }
        }
    }
}

/// Имя соперника по сети с его моряком и значком звания — над его полем.
/// Без моряка (старая версия у соперника) — просто имя.
struct SailorNameTag: View {
    let name: String
    let sailor: SailorLook?
    /// Высота строки: под неё подгоняются аватар и значок.
    var size: CGFloat = 22

    var body: some View {
        HStack(spacing: 6) {
            if let sailor { SailorAvatar(look: sailor, size: size) }
            Text(verbatim: name)
            if let sailor { RankBadge(rank: sailor.rankInfo, size: size * 0.8) }
        }
    }
}

// MARK: - Заглушки

/// Заглушки на холсте 1024 — для того, чего ещё нет в арте (женская фигура,
/// вещь, ждущая картинки). Не арт — схема: где голова, где одежда, чтобы
/// примерка работала до прихода файла.
enum SailorCanvas {
    static let size: CGFloat = 1024

    /// Фон портрета — светлый, как в эскизах: тёмная одежда и обводка на
    /// тёмно-синем терялись (оценка эскиза 02.11).
    static let backdrop = LinearGradient(colors: [Color(hex: 0xBCCFDD), Color(hex: 0xA6BCCE)],
                                         startPoint: .top, endPoint: .bottom)

    static func draw(_ layer: SailorLayer, in context: inout GraphicsContext) {
        switch layer {
        case .skin(let figure): drawFigure(figure, in: &context)
        case .item(let item): drawItem(item, in: &context)
        // У заглушки фигуры волосы и лицо уже нарисованы.
        case .hairBase, .face, .hair, .underCapHair: break
        }
    }

    /// Плечи и грудь до низа холста; `grow` — на сколько вещь шире тела.
    static func torso(_ grow: CGFloat = 0) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 179 - grow, y: 1024))
        p.addLine(to: CGPoint(x: 190 - grow, y: 840))
        p.addQuadCurve(to: CGPoint(x: 440, y: 690 - grow),
                       control: CGPoint(x: 210 - grow, y: 720 - grow))
        p.addLine(to: CGPoint(x: 584, y: 690 - grow))
        p.addQuadCurve(to: CGPoint(x: 834 + grow, y: 840),
                       control: CGPoint(x: 814 + grow, y: 720 - grow))
        p.addLine(to: CGPoint(x: 845 + grow, y: 1024))
        p.closeSubpath()
        return p
    }

    private static func drawFigure(_ figure: SailorFigure, in context: inout GraphicsContext) {
        let skin = SailorPalette.skin(figure.skinTone)
        let hair = SailorPalette.hair(figure.hairColor)
        context.fill(torso(), with: .color(skin))
        context.fill(Path(CGRect(x: 462, y: 560, width: 100, height: 160)), with: .color(skin))
        context.fill(Path(ellipseIn: CGRect(x: 330, y: 400, width: 50, height: 84)), with: .color(skin))
        context.fill(Path(ellipseIn: CGRect(x: 644, y: 400, width: 50, height: 84)), with: .color(skin))
        let head = CGRect(x: 350, y: 240, width: 324, height: 370)
        context.fill(Path(ellipseIn: head), with: .color(skin))
        var top = Path()
        top.move(to: CGPoint(x: head.minX + 4, y: 420))
        top.addCurve(to: CGPoint(x: head.maxX - 4, y: 420),
                     control1: CGPoint(x: head.minX - 10, y: 200),
                     control2: CGPoint(x: head.maxX + 10, y: 200))
        top.addQuadCurve(to: CGPoint(x: head.minX + 4, y: 420), control: CGPoint(x: 512, y: 330))
        context.fill(top, with: .color(hair))
        for x in [462.0, 562.0] {
            context.fill(Path(ellipseIn: CGRect(x: x - 15, y: 440, width: 30, height: 34)),
                         with: .color(Color(hex: 0x2A1E16)))
        }
        context.stroke(Path { p in
            p.move(to: CGPoint(x: 470, y: 530))
            p.addQuadCurve(to: CGPoint(x: 554, y: 530), control: CGPoint(x: 512, y: 566))
        }, with: .color(Color(hex: 0x9A2A22)), style: StrokeStyle(lineWidth: 9, lineCap: .round))
    }

    /// Вещь без картинки — серый силуэт своего слоя.
    private static func drawItem(_ item: SailorItem, in context: inout GraphicsContext) {
        let fill = Color(white: 0.55)
        switch item.slot {
        case .shirt: context.fill(torso(), with: .color(fill))
        case .jacket: context.fill(torso(10), with: .color(fill.opacity(0.9)))
        case .coat: context.fill(torso(22), with: .color(fill.opacity(0.85)))
        case .cap:
            context.fill(Path(ellipseIn: CGRect(x: 330, y: 190, width: 364, height: 130)), with: .color(fill))
        }
    }
}

// MARK: - Превью

#Preview("Моряк · слои") {
    let looks: [SailorLook] = [
        SailorLook(),
        SailorLook(figure: SailorFigure(skinTone: 5, hair: "curly", hairColor: 1), rank: "lieutenant",
                   shirt: "shirt_white", jacket: "jacket_officer", cap: nil),
        SailorLook(figure: SailorFigure(skinTone: 2, hair: "slick", hairColor: 6), rank: "captain_2",
                   shirt: "shirt_jumper", jacket: "jacket_petty", cap: "cap_petty"),
        SailorLook(figure: SailorFigure(body: .woman, skinTone: 3), rank: "admiral",
                   shirt: "shirt_stripes", coat: "coat_officer", cap: "cap_newyear_santa"),
    ]
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            ForEach(looks, id: \.self) { look in
                SailorPortrait(look: look)
                    .background(SailorCanvas.backdrop)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        HStack(spacing: 12) {
            ForEach(looks, id: \.self) { look in
                SailorAvatar(look: look, size: 56)
            }
        }
        HStack(spacing: 4) {
            ForEach(SailorCatalog.ranks) { RankBadge(rank: $0, size: 20) }
        }
        SailorNameTag(name: "Борис", sailor: looks[2], size: 22)
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.inkPrimary)
    }
    .padding()
    .background(SeaBackground())
}
