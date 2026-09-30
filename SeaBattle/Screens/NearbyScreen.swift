//
//  NearbyScreen.swift
//  Sea Battle — «Рядом, без сети»: поиск устройств (R3.3)
//
//  Спека 4.8, кадр `screen5NetNearby`. Список устройств, у которых открыт тот
//  же экран, поиск — строкой под списком, а не поверх него, и пояснение, как
//  это работает. Касание устройства — приглашение; второе устройство его
//  принимает само, и обе стороны уходят на расстановку.
//
//  Отступления от кадра — решения R3.3: Multipeer не сообщает ни силу
//  сигнала, ни расстояние, поэтому в строке имя и вид устройства, а справа
//  шеврон; «Ввести код вручную» не нужен — устройства рядом находят друг
//  друга без кода, поэтому внизу только «Меню».
//

import SwiftUI

enum NearbyMetrics {
    static let groupGap: CGFloat = 16
    static let overline: CGFloat = 11
    static let overlineInset: CGFloat = 6
    static let rowIcon: CGFloat = 28
    static let rowName: CGFloat = 15
    static let rowDetail: CGFloat = 11.5
    static let rowPaddingV: CGFloat = 13
    static let rowPaddingH: CGFloat = 14
    static let groupRadius: CGFloat = 20
    static let cardRadius: CGFloat = 18
    static let scanIcon: CGFloat = 24
    static let scanText: CGFloat = 13.5
    static let note: CGFloat = 12.5
    static let dot: CGFloat = 6
}

struct NearbyScreen: View {
    let transport: MultipeerTransport
    var onBack: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            ScreenTitle(title: "Nearby, no internet", back: "Play", onBack: onBack)
                .padding(.top, NavMetrics.titleTopBelowSafeArea)

            ScrollView {
                VStack(alignment: .leading, spacing: NearbyMetrics.groupGap) {
                    if !transport.peers.isEmpty { devices }
                    scanning
                    note
                }
                .padding(.horizontal, Geometry.Nav.stackInset)
                .padding(.top, Geometry.Nav.titleGap * 2)
                .animation(Motion.quick, value: transport.peers)
            }
            .scrollBounceBehavior(.basedOnSize)

            BottomStack(onMenu: onBack) {
                EmptyView()
            }
        }
        .onAppear { transport.startDiscovery() }
    }

    // MARK: Устройства

    private var devices: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Devices nearby")
                .font(.system(size: NearbyMetrics.overline, weight: .bold))
                .tracking(NearbyMetrics.overline * 0.09)
                .textCase(.uppercase)
                .foregroundStyle(Color.inkSecondary)
                .padding(.leading, NearbyMetrics.overlineInset)
            VStack(spacing: 0) {
                ForEach(transport.peers) { peer in
                    if peer.id != transport.peers.first?.id {
                        Rectangle()
                            .fill(Color.glassStroke)
                            .frame(height: 1)
                            .padding(.horizontal, NearbyMetrics.rowPaddingH)
                    }
                    row(peer)
                }
            }
            .glassPanel(.g2, radius: NearbyMetrics.groupRadius)
        }
    }

    private func row(_ peer: NearbyPeer) -> some View {
        let connecting = transport.partner == peer.peerID
        return Button { transport.invite(peer) } label: {
            HStack(spacing: 12) {
                Image(systemName: peer.isPad ? "ipad" : "iphone")
                    .font(.system(size: symbolFontSize(inBox: NearbyMetrics.rowIcon)))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(width: NearbyMetrics.rowIcon, height: NearbyMetrics.rowIcon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: peer.name)
                        .font(.system(size: NearbyMetrics.rowName, weight: .medium))
                        .foregroundStyle(Color.inkPrimary)
                        .lineLimit(1)
                    Group {
                        if connecting {
                            Text("Connecting…")
                        } else {
                            Text(verbatim: peer.model)
                        }
                    }
                    .font(.system(size: NearbyMetrics.rowDetail))
                    .foregroundStyle(Color.inkSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if connecting {
                    ProgressView()
                        .tint(Color.inkPrimary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.inkTertiary)
                }
            }
            .padding(.vertical, NearbyMetrics.rowPaddingV)
            .padding(.horizontal, NearbyMetrics.rowPaddingH)
            .frame(minHeight: Geometry.Hit.minTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Пока идёт одно приглашение, второе не отправить.
        .disabled(transport.partner != nil && !connecting)
        .accessibilityIdentifier("nearbyPeer_\(peer.name)")
    }

    // MARK: Поиск и пояснение

    private var scanning: some View {
        HStack(spacing: 11) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: symbolFontSize(inBox: NearbyMetrics.scanIcon)))
                .foregroundStyle(Color.inkPrimary)
                .frame(width: NearbyMetrics.scanIcon, height: NearbyMetrics.scanIcon)
            Text(transport.peers.isEmpty ? "Searching for devices…" : "Still searching…")
                .font(.system(size: NearbyMetrics.scanText))
                .foregroundStyle(Color.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            SearchDots()
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 15)
        .glassPanel(.g2, radius: NearbyMetrics.cardRadius)
    }

    private var note: some View {
        Text("Works over Bluetooth and a shared Wi-Fi network, no internet needed. The other player must open the same mode — then the device appears in the list.")
            .font(.system(size: NearbyMetrics.note))
            .lineSpacing(NearbyMetrics.note * 0.5)
            .foregroundStyle(Color.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 13)
            .padding(.horizontal, 15)
            .glassPanel(.g2, radius: NearbyMetrics.cardRadius)
    }
}

/// Три латунные точки поиска: яркость бежит по ним по кругу. При Reduce
/// Motion — стоят как в кадре (1 · 0,7 · 0,4).
struct SearchDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.4)) { context in
            let step = reduceMotion ? 0 : Int(context.date.timeIntervalSinceReferenceDate / 0.4) % 3
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.roleYou)
                        .frame(width: NearbyMetrics.dot, height: NearbyMetrics.dot)
                        .opacity(1 - Double((index - step + 3) % 3) * 0.3)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: step)
        }
        .accessibilityHidden(true)
    }
}

#Preview("Рядом · поиск") {
    ZStack {
        SeaBackground()
            .ignoresSafeArea()
        NearbyScreen(transport: MultipeerTransport(displayName: "Превью", model: "iPhone"))
    }
    .preferredColorScheme(.dark)
}
