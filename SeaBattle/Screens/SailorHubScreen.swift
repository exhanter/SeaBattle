//
//  SailorHubScreen.swift
//  Sea Battle — таб «Моряк» (заказчик 04.11)
//
//  Моряк, гардероб и баллы не находились: путь к ним был «Статистика → Баллы →
//  Моряк». Теперь «Моряк» — таб на месте «Статистики» (аватар в таб-баре и в
//  квадрате iPad), а корень таба — «Личное дело»: большой портрет, звание,
//  баланс с «+», ордена. Под ним разделы: гардероб, ордена и следующие
//  награды, баллы, статистика.
//
//  Из двух вариантов (компактная карточка со списком / личное дело на весь
//  верх) заказчик выбрал второй.
//

import SwiftUI

enum SailorHubMetrics {
    static let cardRadius: CGFloat = 22
    static let cardPadding: CGFloat = 14
    static let portrait: CGFloat = 150
    static let padPortrait: CGFloat = 180
    static let name: CGFloat = 20
    static let rank: CGFloat = 15
    static let balance: CGFloat = 15
    static let coin: CGFloat = 18
    static let medal: CGFloat = 40
    static let rowIcon: CGFloat = 26
    static let blockGap: CGFloat = 12
}

struct SailorHubScreen: View {
    let name: String
    let wardrobe: SailorWardrobe
    let points: Int
    var dossier = PlayerDossier()
    var onWardrobe: () -> Void = {}
    var onWallet: () -> Void = {}
    var onBuyPoints: () -> Void = {}
    var onCard: () -> Void = {}
    var onStatistics: () -> Void = {}

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var look: SailorLook { wardrobe.currentLook }

    var body: some View {
        VStack(spacing: 0) {
            ScreenTitle(title: "Sailor")
                .padding(.top, NavMetrics.titleTopBelowSafeArea)

            ScrollView {
                VStack(spacing: SailorHubMetrics.blockGap) {
                    dossierCard
                    sections
                }
                .padding(.horizontal, Geometry.Nav.stackInset)
                .padding(.top, Geometry.Nav.titleGap * 2)
                .padding(.bottom, SailorHubMetrics.blockGap)
            }
            .seaScroll()
        }
    }

    // MARK: Личное дело

    private var dossierCard: some View {
        let side = sizeClass == .regular ? SailorHubMetrics.padPortrait : SailorHubMetrics.portrait
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return VStack(spacing: 10) {
            Button(action: onWardrobe) {
                SailorPortrait(look: look)
                    .frame(width: side, height: side)
                    .background(SailorCanvas.backdrop)
                    .clipShape(shape)
                    .overlay(shape.strokeBorder(look.rankInfo.group.ring, lineWidth: 3))
            }
            .buttonStyle(.plain)
            if !name.isEmpty {
                Text(verbatim: name)
                    .font(.scalable(size: SailorHubMetrics.name, weight: .bold))
                    .foregroundStyle(Color.inkPrimary)
            }
            rankLine
            balanceLine
            if !dossier.medals.isEmpty {
                HStack(spacing: 6) {
                    ForEach(dossier.medals.prefix(6), id: \.self) { medal in
                        MedalImage(medal: medal, size: SailorHubMetrics.medal)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(SailorHubMetrics.cardPadding)
        .frame(maxWidth: .infinity)
        .glassPanel(.g2, radius: SailorHubMetrics.cardRadius, highlight: .selected)
    }

    // MARK: Общее

    private var rankLine: some View {
        HStack(spacing: 8) {
            RankBadge(rank: look.rankInfo, size: 22)
            Text(look.rankInfo.title)
                .font(.scalable(size: SailorHubMetrics.rank, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)
        }
        .accessibilityElement(children: .combine)
    }

    private var balanceLine: some View {
        HStack(spacing: 6) {
            PointsCoin(size: SailorHubMetrics.coin)
            Text("\(points) points")
                .font(.scalable(size: SailorHubMetrics.balance, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.inkSecondary)
            BuyPointsPlus(action: onBuyPoints)
                .padding(.leading, 2)
        }
    }

    private var sections: some View {
        ListGroup {
            row(icon: "tshirt", title: "Wardrobe", subtitle: "Ranks, uniform and seasonal sets",
                action: onWardrobe)
            row(icon: "medal", title: "Service record", subtitle: "Medals and next awards",
                action: onCard)
            row(icon: "clock.arrow.circlepath", title: "Points", subtitle: "Balance and history",
                action: onWallet)
            row(icon: "chart.bar", title: "Statistics", subtitle: "Wins and losses by mode",
                action: onStatistics)
        }
    }

    private func row(icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ScaledSymbol(name: icon, box: SailorHubMetrics.rowIcon)
                    .foregroundStyle(Color.inkPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.scalable(size: ListMetrics.rowTitle, weight: .medium))
                        .foregroundStyle(Color.inkPrimary)
                    Text(subtitle)
                        .font(.scalable(size: ListMetrics.rowSubtitle))
                        .foregroundStyle(Color.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.scalable(size: symbolFontSize(inBox: ListMetrics.chevron), weight: .semibold))
                    .foregroundStyle(Color.inkTertiary)
            }
            .padding(.vertical, ListMetrics.rowPaddingV)
            .padding(.horizontal, ListMetrics.rowPaddingH)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Превью

private enum HubDemo {
    static var wardrobe: SailorWardrobe {
        var wardrobe = SailorWardrobe()
        wardrobe.rank = SailorCatalog.ranks[4].id
        return wardrobe
    }
    static let dossier = PlayerDossier(games: 48, wins: 29, networkGames: 6, networkWins: 4,
                                       medals: ["sharpshooter_gold", "streak_silver", "seaWolf_bronze"])
}

private struct HubPreview: View {
    @State private var tab: ShellTab = .sailor

    var body: some View {
        ZStack {
            SeaBackground()
                .ignoresSafeArea()
            VStack(spacing: 0) {
                SailorHubScreen(name: "Аня", wardrobe: HubDemo.wardrobe,
                                points: 1_250, dossier: HubDemo.dossier)
                SeaTabBar(selection: $tab, sailor: HubDemo.wardrobe.currentLook)
            }
        }
    }
}

#Preview("Моряк") {
    HubPreview()
        .preferredColorScheme(.dark)
}

#Preview("Моряк · светлая") {
    HubPreview()
        .preferredColorScheme(.light)
}

#Preview("Моряк · 375 × 667", traits: .fixedLayout(width: 375, height: 667)) {
    HubPreview()
        .preferredColorScheme(.dark)
}

/// Таб-бар без подписей: три состояния выбора.
#Preview("Таб-бар") {
    @Previewable @State var home: ShellTab = .play
    @Previewable @State var sailor: ShellTab = .sailor
    @Previewable @State var settings: ShellTab = .settings
    ZStack {
        SeaBackground()
            .ignoresSafeArea()
        VStack(spacing: 24) {
            SeaTabBar(selection: $home, sailor: HubDemo.wardrobe.currentLook)
            SeaTabBar(selection: $sailor, sailor: HubDemo.wardrobe.currentLook)
            SeaTabBar(selection: $settings, sailor: HubDemo.wardrobe.currentLook)
        }
    }
    .preferredColorScheme(.dark)
}
