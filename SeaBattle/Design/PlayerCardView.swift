//
//  PlayerCardView.swift
//  Sea Battle — «Личное дело»: моряк крупно, звание, счёт, награды (К4)
//
//  Открывается нажатием на моряка — своего в гардеробе и соперника над его
//  полем. Всё, чего нет на самом моряке (заказчик 31.10: ни погон, ни
//  орденов), — здесь: звание крупно, счёт партий и награды за достижения.
//  Окно поверх экрана, как `ModalDialog`, но закрывается и нажатием мимо:
//  это справка, а не вопрос.
//

import SwiftUI

enum PlayerCardMetrics {
    static let portrait: CGFloat = 176
    static let portraitRadius: CGFloat = 22
    static let badge: CGFloat = 40
    static let name: CGFloat = 22
    static let rank: CGFloat = 15
    static let number: CGFloat = 22
    static let caption: CGFloat = 11.5
    static let medal: CGFloat = 64
    static let gap: CGFloat = 14
}

/// Кто в карточке.
struct PlayerCardInfo: Equatable {
    let name: String
    let look: SailorLook
    let dossier: PlayerDossier?
}

struct PlayerCardView: View {
    let info: PlayerCardInfo
    var onClose: () -> Void = {}

    @Environment(\.locale) private var locale

    var body: some View {
        let rank = info.look.rankInfo
        let shape = RoundedRectangle(cornerRadius: PlayerCardMetrics.portraitRadius, style: .continuous)
        VStack(spacing: PlayerCardMetrics.gap) {
            HStack {
                Text("Service record")
                    .font(.scalable(size: ListMetrics.overline, weight: .bold))
                    .tracking(ListMetrics.overlineTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.inkSecondary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.scalable(size: 14, weight: .semibold))
                        .foregroundStyle(Color.inkSecondary)
                        .frame(width: Geometry.Hit.minTarget, height: Geometry.Hit.minTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, -12)
                .accessibilityLabel(Text("Close"))
                .accessibilityIdentifier("playerCardClose")
            }

            SailorPortrait(look: info.look)
                .frame(width: PlayerCardMetrics.portrait, height: PlayerCardMetrics.portrait)
                .background(SailorCanvas.backdrop)
                .clipShape(shape)
                .overlay(shape.strokeBorder(rank.group.ring, lineWidth: 3))

            VStack(spacing: 6) {
                if !info.name.isEmpty {
                    Text(verbatim: info.name)
                        .font(.scalable(size: PlayerCardMetrics.name, weight: .bold))
                        .foregroundStyle(Color.inkPrimary)
                        .multilineTextAlignment(.center)
                }
                HStack(spacing: 8) {
                    RankBadge(rank: rank, size: PlayerCardMetrics.badge)
                    Text(rank.title)
                        .font(.scalable(size: PlayerCardMetrics.rank, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                }
                .accessibilityElement(children: .combine)
            }

            if let dossier = info.dossier {
                record(dossier)
                awards(dossier.medals)
            }
        }
        .padding(ModalMetrics.padding)
        .frame(maxWidth: .infinity)
        .glassPanel(.g3, radius: ModalMetrics.radius)
        // Под стеклом — море, а не экран: сквозь окно проступали кнопки
        // гардероба цветными пятнами.
        .background(SeaBackground().clipShape(RoundedRectangle(cornerRadius: ModalMetrics.radius,
                                                                style: .continuous)))
        // Касание по окну его не закрывает — закрывает только мимо.
        .contentShape(Rectangle())
        .onTapGesture {}
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onClose)
    }

    // MARK: Счёт

    private func record(_ dossier: PlayerDossier) -> some View {
        HStack(spacing: 0) {
            number(Text(verbatim: "\(dossier.games)"), caption: "games")
            divider
            number(Text(verbatim: "\(dossier.wins)"), caption: "wins")
            divider
            number(dossier.winShare.map { Text($0, format: .percent.precision(.fractionLength(0)).locale(locale)) }
                       ?? Text(verbatim: "—"),
                   caption: "win rate")
            divider
            number(Text(verbatim: "\(dossier.networkWins)"), caption: "wins over people")
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .glassPanel(.g2, radius: ListMetrics.groupRadius)
    }

    private func number(_ value: Text, caption: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            value
                .font(.scalable(size: PlayerCardMetrics.number, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.inkPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(caption)
                .font(.scalable(size: PlayerCardMetrics.caption))
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                // Две строки у всех подписей: иначе числа над длинной
                // подписью встают выше соседних.
                .lineLimit(2, reservesSpace: true)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var divider: some View {
        Rectangle().fill(Color.glassStroke).frame(width: 1, height: 34)
    }

    // MARK: Награды

    @ViewBuilder
    private func awards(_ medals: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Awards")
                .font(.scalable(size: ListMetrics.overline, weight: .bold))
                .tracking(ListMetrics.overlineTracking)
                .textCase(.uppercase)
                .foregroundStyle(Color.inkSecondary)
                .accessibilityAddTraits(.isHeader)
            if medals.isEmpty {
                Text("No awards yet")
                    .font(.scalable(size: ListMetrics.rowSubtitle))
                    .foregroundStyle(Color.inkSecondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: PlayerCardMetrics.medal), spacing: 8)],
                          spacing: 8) {
                    ForEach(medals, id: \.self) { medal in
                        Image("medal_\(medal)")
                            .resizable()
                            .scaledToFit()
                            .frame(width: PlayerCardMetrics.medal, height: PlayerCardMetrics.medal)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Показ поверх экрана

extension View {
    /// «Личное дело» поверх всего экрана. В отличие от `modalDialog`,
    /// нажатие мимо окна закрывает его: это справка, ничего не теряется.
    func playerCard(_ info: PlayerCardInfo?, onClose: @escaping () -> Void) -> some View {
        overlay { PlayerCardLayer(info: info, onClose: onClose) }
    }
}

private struct PlayerCardLayer: View {
    let info: PlayerCardInfo?
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if info != nil {
                Color.overlayScrim
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onClose)
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }
            if let info {
                GeometryReader { proxy in
                    ScrollView {
                        PlayerCardView(info: info, onClose: onClose)
                            .frame(maxWidth: Geometry.Nav.padDialog)
                            .padding(.horizontal, ModalMetrics.screenInset)
                            .padding(.vertical, ModalMetrics.screenInset)
                            .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                            // Прокрутка лежит над затемнением и забирает
                            // касания — поэтому «мимо окна» ловит её фон.
                            .background {
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture(perform: onClose)
                            }
                    }
                }
                // Крупный текст не помещается в экран — тогда окно
                // прокручивается; обычно оно в середине и не двигается.
                .scrollBounceBehavior(.basedOnSize)
                .transition(reduceMotion ? .opacity
                                         : .opacity.combined(with: .scale(scale: ModalMetrics.windowStartScale)))
            }
        }
        .animation(.easeOut(duration: Motion.scaled(ModalMetrics.windowAppear, reduceMotion: reduceMotion)),
                   value: info)
    }
}

// MARK: - Превью

#Preview("Личное дело") {
    ZStack {
        SeaBackground().ignoresSafeArea()
        Color.clear
    }
    .playerCard(PlayerCardInfo(
        name: "Борис",
        look: SailorLook(figure: SailorFigure(skinTone: 3, hair: "slick", hairColor: 2), rank: "captain_2",
                         shirt: "shirt_white", jacket: "jacket_officer", cap: "cap_officer"),
        dossier: PlayerDossier(games: 148, wins: 91, networkGames: 30, networkWins: 17,
                               medals: ["sample_gold", "sample_silver", "sample_bronze"])),
                onClose: {})
    .preferredColorScheme(.dark)
}
