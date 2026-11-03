//
//  PointsShopScreen.swift
//  Sea Battle — покупка баллов за деньги (03.11)
//
//  Лист снизу, как короткий лист Pro (`ProSheetLayer`): шапка, плашка акции,
//  если она идёт, три пакета. Нажатие на пакет сразу покупает — расходуемой
//  покупке нечего выбирать заранее, и кнопка «Купить» под списком была бы
//  лишним шагом.
//
//  Акция не перекраивает лист: одна плашка с эмблемой и сроком сверху, у
//  подешевевших пакетов — старая цена зачёркнутой и метка «−33%». Эмблема —
//  картинка `promo_<id>` из каталога; пока её нет, рисуется значок акции в
//  латунной рамке. Картинки пакетов `points_pack_<число>` — так же.
//
//  Открывается строкой «Купить баллы» в кошельке и скромным «+» у баланса в
//  гардеробе (заказчик 03.11). Посреди партии не продаём.
//

import SwiftUI

enum PointsShopMetrics {
    static let packArt: CGFloat = 44
    static let packRadius: CGFloat = 18
    static let packPaddingV: CGFloat = 11
    static let packTitle: CGFloat = 16
    static let packPrice: CGFloat = 16
    static let oldPrice: CGFloat = 12
    static let emblem: CGFloat = 56
    static let promoTitle: CGFloat = 16
    static let promoText: CGFloat = 12.5
    static let promoRadius: CGFloat = 20
    static let packsGap: CGFloat = 8
    /// «+» у баланса в гардеробе.
    static let plusBox: CGFloat = 22
}

struct PointsShopSheet: View {
    let offers: [PointsOffer]
    var promotion: ActivePromotion?
    var hasLoaded = true
    var onBuy: (PointsOffer) async -> PurchaseOutcome = { _ in .cancelled }

    @State private var working: PointsPack?
    @State private var notice: PointsShopNotice?

    var body: some View {
        VStack(spacing: ProMetrics.sheetGap) {
            Capsule()
                .fill(Color.inkTertiary)
                .frame(width: ProMetrics.grabberWidth, height: ProMetrics.grabberHeight)
                .accessibilityHidden(true)

            HStack(spacing: 11) {
                BrassIconBox(icon: PointsSymbol.name, box: ProMetrics.sheetIconBox,
                             radius: ProMetrics.sheetIconRadius, symbol: ProMetrics.featureIcon,
                             fill: 0.22)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Buy points")
                        .font(.scalable(size: ProMetrics.sheetTitle, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.inkPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("Points are spent on hints and on your sailor's ranks and uniform.")
                        .font(.scalable(size: ProMetrics.sheetText))
                        .lineSpacing(ProMetrics.sheetText * 0.4)
                        .foregroundStyle(Color.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let promotion, offers.contains(where: \.isOnSale) {
                PromotionBanner(active: promotion)
            }

            VStack(spacing: PointsShopMetrics.packsGap) {
                if offers.isEmpty {
                    if hasLoaded {
                        Text("The App Store cannot be reached right now. Please try again later.")
                            .font(.scalable(size: ProMetrics.sheetText))
                            .foregroundStyle(Color.inkSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 12)
                    } else {
                        ProgressView()
                            .padding(.vertical, 24)
                    }
                }
                ForEach(offers) { offer in
                    PointsPackRow(offer: offer, isWorking: working == offer.pack) {
                        guard working == nil else { return }
                        Task {
                            working = offer.pack
                            notice = PointsShopNotice(await onBuy(offer))
                            working = nil
                        }
                    }
                    .disabled(working != nil && working != offer.pack)
                }
            }

            if let notice {
                Text(notice.text)
                    .font(.scalable(size: ProMetrics.sheetText))
                    .foregroundStyle(Color.inkPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
    }
}

/// Что сказать после покупки: успех виден по балансу, отмена молчит.
enum PointsShopNotice: Equatable {
    case pending, failed

    var text: LocalizedStringKey {
        switch self {
        case .pending: "Waiting for approval. The points arrive as soon as the purchase goes through."
        case .failed: "The purchase did not go through. Please try again."
        }
    }

    init?(_ outcome: PurchaseOutcome) {
        switch outcome {
        case .pending: self = .pending
        case .failed: self = .failed
        case .purchased, .cancelled: return nil
        }
    }
}

// MARK: - Акция

/// Плашка над пакетами: эмблема праздника, его имя, до какого числа.
struct PromotionBanner: View {
    let active: ActivePromotion

    var body: some View {
        HStack(spacing: 12) {
            PromotionEmblem(promotion: active.promotion, size: PointsShopMetrics.emblem)
            VStack(alignment: .leading, spacing: 3) {
                Text(active.promotion.title)
                    .font(.scalable(size: PointsShopMetrics.promoTitle, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.inkPrimary)
                Text("Points are cheaper until \(Text(active.lastDay(), format: .dateTime.day().month(.wide)))")
                    .font(.scalable(size: PointsShopMetrics.promoText))
                    .foregroundStyle(Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, ListMetrics.rowPaddingH)
        .glassPanel(.g2, radius: PointsShopMetrics.promoRadius, highlight: .selected)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("pointsPromotion-\(active.promotion.id)")
    }
}

/// Эмблема акции: картинка `promo_<id>`, без неё — значок в латунной рамке.
struct PromotionEmblem: View {
    let promotion: PointsPromotion
    let size: CGFloat

    var body: some View {
        if UIImage(named: promotion.emblemAsset) != nil {
            Image(promotion.emblemAsset)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            BrassIconBox(icon: promotion.symbol, box: size, radius: size * 0.32,
                         symbol: size * 0.5, fill: 0.22)
        }
    }
}

// MARK: - Пакет

struct PointsPackRow: View {
    let offer: PointsOffer
    var isWorking = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                PointsPackArt(pack: offer.pack, size: PointsShopMetrics.packArt)
                HStack(spacing: 8) {
                    Text("\(offer.pack.points) points")
                        .font(.scalable(size: PointsShopMetrics.packTitle, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.inkPrimary)
                    if let percent = offer.discountPercent {
                        PackBadge(text: Text(verbatim: "\u{2212}\(percent)%"))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isWorking {
                    ProgressView()
                } else {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(verbatim: offer.price)
                            .font(.scalable(size: PointsShopMetrics.packPrice, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(offer.isOnSale ? Color.roleYou : Color.inkPrimary)
                        if let regular = offer.regularPrice {
                            Text(verbatim: regular)
                                .font(.scalable(size: PointsShopMetrics.oldPrice))
                                .monospacedDigit()
                                .strikethrough()
                                .foregroundStyle(Color.inkSecondary)
                                .accessibilityLabel(Text("instead of \(regular)"))
                        }
                    }
                }
            }
            .padding(.vertical, PointsShopMetrics.packPaddingV)
            .padding(.horizontal, ListMetrics.rowPaddingH)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassPanel(.g2, radius: PointsShopMetrics.packRadius,
                    highlight: offer.isOnSale ? .selected : .none)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("pointsPack-\(offer.pack.points)")
    }
}

private struct PackBadge: View {
    let text: Text

    var body: some View {
        text
            .font(.scalable(size: ProMetrics.badgeText, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(Color.inkPrimary)
            .padding(.vertical, 2)
            .padding(.horizontal, 8)
            .background(Color.roleYou.opacity(0.24), in: Capsule())
            .overlay { Capsule().strokeBorder(Color.roleYou, lineWidth: 1) }
    }
}

/// Картинка пакета `points_pack_<число>`; без неё — знак баллов, у пакета
/// побольше — крупнее, чтобы три строки не были одинаковыми.
struct PointsPackArt: View {
    let pack: PointsPack
    let size: CGFloat

    private var asset: String { "points_pack_\(pack.points)" }

    var body: some View {
        Group {
            if UIImage(named: asset) != nil {
                Image(asset)
                    .resizable()
                    .scaledToFit()
            } else {
                let glyph: CGFloat = switch pack {
                case .small: 0.5
                case .medium: 0.62
                case .large: 0.74
                }
                Image(systemName: PointsSymbol.name)
                    .font(.system(size: symbolFontSize(inBox: size * glyph)))
                    .foregroundStyle(Color.roleYou)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - «+» у баланса

/// Скромная кнопка «купить баллы» рядом с числом баллов (гардероб).
struct BuyPointsPlus: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: PointsShopMetrics.plusBox * 0.5, weight: .bold))
                .foregroundStyle(Color.inkPrimary)
                .frame(width: PointsShopMetrics.plusBox, height: PointsShopMetrics.plusBox)
                .background(Color.roleYou.opacity(0.16), in: Circle())
                .overlay { Circle().strokeBorder(Color.roleYou.opacity(0.7), lineWidth: 1) }
                // Палец не попадёт в 22 pt — область нажатия больше значка.
                .padding(8)
                .contentShape(Rectangle())
                .padding(-8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Buy points"))
        .accessibilityIdentifier("buyPointsPlus")
    }
}

extension View {
    /// Лист покупки баллов поверх экрана.
    func pointsShopSheet(isPresented: Bool, onDismiss: @escaping () -> Void,
                         @ViewBuilder sheet: () -> some View) -> some View {
        overlay {
            ProSheetLayer(isPresented: isPresented, onDismiss: onDismiss,
                          sheet: isPresented ? sheet() : nil)
        }
    }
}

// MARK: - Превью

private extension Array where Element == PointsOffer {
    static let regular: [PointsOffer] = [
        PointsOffer(pack: .small, productID: PointsPack.small.productID, price: "€0,99"),
        PointsOffer(pack: .medium, productID: PointsPack.medium.productID, price: "€2,99"),
        PointsOffer(pack: .large, productID: PointsPack.large.productID, price: "€9,99"),
    ]

    static let sale: [PointsOffer] = [
        PointsOffer(pack: .small, productID: PointsPack.small.productID, price: "€0,99"),
        PointsOffer(pack: .medium, productID: PointsPack.medium.productID(sale: "sale"),
                    price: "€1,99", regularPrice: "€2,99", discountPercent: 33),
        PointsOffer(pack: .large, productID: PointsPack.large.productID(sale: "sale"),
                    price: "€4,99", regularPrice: "€9,99", discountPercent: 50),
    ]
}

private struct ShopPreview: View {
    var offers: [PointsOffer]
    var on: DateComponents?

    var body: some View {
        let promotion = on.flatMap { Calendar(identifier: .gregorian).date(from: $0) }
            .flatMap { PointsPromotion.active(on: $0) }
        ZStack {
            SeaBackground()
                .ignoresSafeArea()
        }
        .pointsShopSheet(isPresented: true, onDismiss: {}) {
            PointsShopSheet(offers: offers, promotion: promotion)
        }
    }
}

#Preview("Баллы · лист") {
    ShopPreview(offers: .regular)
        .preferredColorScheme(.dark)
}

#Preview("Баллы · чёрная пятница") {
    ShopPreview(offers: .sale, on: DateComponents(year: 2026, month: 11, day: 28))
        .preferredColorScheme(.dark)
}

#Preview("Баллы · Новый год, светлая") {
    ShopPreview(offers: .sale, on: DateComponents(year: 2027, month: 1, day: 2))
        .preferredColorScheme(.light)
}

#Preview("Баллы · магазин молчит") {
    ShopPreview(offers: [])
        .preferredColorScheme(.dark)
}
