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

    // iPad (этап 3, 14.10): сетка экрана уровня.
    static let padMaxWidth: CGFloat = 1000
    static let padColumnGap: CGFloat = 24
    /// Высота панели устройств и пояснения — одна и та же, пока идёт поиск
    /// и когда устройства нашлись: блоки не прыгают (заказчик 14.10). Много
    /// устройств — список прокручивается внутри.
    static let padPanelHeight: CGFloat = 340
    static let padScanIcon: CGFloat = 44
}

struct NearbyScreen: View {
    let transport: MultipeerTransport
    var onBack: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.usesPadLayout) private var usesPadLayout
    @State private var viewportHeight: CGFloat = 0

    var body: some View {
        Group {
            if usesPadLayout {
                padBody
                    // iPad: квадраты по углам, как на уровне и итогах.
                    .environment(\.bottomChrome, .tiles)
            } else {
                phoneBody
            }
        }
        .onAppear { transport.startDiscovery() }
    }

    private var phoneBody: some View {
        VStack(spacing: 0) {
            ScreenTitle(title: "Nearby, no internet", back: "Home", onBack: onBack)
                .padding(.top, NavMetrics.titleTopBelowSafeArea)

            ScrollView {
                VStack(alignment: .leading, spacing: NearbyMetrics.groupGap) {
                    if !transport.peers.isEmpty { devices }
                    scanning
                    note
                }
                .padding(.horizontal, Geometry.Nav.stackInset)
                .padding(.top, Geometry.Nav.titleGap * 2)
                .animation(Motion.quick.reduced(reduceMotion), value: transport.peers)
            }
            .seaScroll()

            BottomStack(onMenu: onBack) {
                EmptyView()
            }
        }
    }

    // MARK: iPad

    /// iPad: две колонки одной высоты по центру экрана, как экран уровня.
    /// Слева панель устройств — пока никого нет, в ней поиск по центру, потом
    /// список и строка «Ищем ещё…» внизу; справа — как это работает.
    private var padBody: some View {
        VStack(spacing: 0) {
            ScreenTitle(title: "Nearby, no internet", back: "Home", onBack: onBack)
                .padding(.top, NavMetrics.titleTopBelowSafeArea)
                .frame(maxWidth: NearbyMetrics.padMaxWidth)
                .padding(.horizontal, Geometry.Inset.padFrame)

            ScrollView {
                HStack(alignment: .top, spacing: NearbyMetrics.padColumnGap) {
                    VStack(alignment: .leading, spacing: 8) {
                        overline("Devices nearby")
                        padDevices
                            .frame(maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    VStack(alignment: .leading, spacing: 8) {
                        // Надзаголовка у пояснения нет — место держится, чтобы
                        // блоки начинались вровень.
                        overline("Devices nearby")
                            .hidden()
                            .accessibilityHidden(true)
                        padNote
                            .frame(maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: NearbyMetrics.padMaxWidth)
                .padding(.horizontal, Geometry.Inset.padFrame + Geometry.Nav.stackInset)
                .padding(.top, Geometry.Nav.titleGap * 2)
                .padding(.bottom, Geometry.Nav.titleGap)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .frame(minHeight: viewportHeight, alignment: .center)
                .animation(Motion.quick.reduced(reduceMotion), value: transport.peers)
            }
            .seaScroll()
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewportHeight = $0 }

            BottomStack(onMenu: onBack) {
                EmptyView()
            }
        }
    }

    private var padDevices: some View {
        VStack(spacing: 0) {
            if transport.peers.isEmpty {
                VStack(spacing: 14) {
                    ScaledSymbol(name: "antenna.radiowaves.left.and.right",
                                 box: NearbyMetrics.padScanIcon)
                        .foregroundStyle(Color.roleYou)
                    Text("Searching for devices…")
                        .font(.scalable(size: 16, weight: .medium))
                        .foregroundStyle(Color.inkPrimary)
                    SearchDots()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
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
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: .infinity, alignment: .top)
                Rectangle()
                    .fill(Color.glassStroke)
                    .frame(height: 1)
                HStack(spacing: 11) {
                    Text("Still searching…")
                        .font(.scalable(size: NearbyMetrics.scanText))
                        .foregroundStyle(Color.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    SearchDots()
                }
                .padding(.vertical, 13)
                .padding(.horizontal, NearbyMetrics.rowPaddingH)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: NearbyMetrics.padPanelHeight)
        .glassPanel(.g2, radius: NearbyMetrics.groupRadius)
    }

    /// Пояснение — на iPad карточкой той же высоты, что панель устройств:
    /// значки Bluetooth и Wi-Fi над текстом.
    private var padNote: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ScaledSymbol(name: "dot.radiowaves.left.and.right", box: 28)
                ScaledSymbol(name: "wifi", box: 28)
            }
            .foregroundStyle(Color.inkSecondary)
            .accessibilityHidden(true)
            Text("Works over Bluetooth and a shared Wi-Fi network, no internet needed. The other player must open the same mode — then the device appears in the list.")
                .font(.scalable(size: 15))
                .lineSpacing(15 * 0.4)
                .foregroundStyle(Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassPanel(.g2, radius: NearbyMetrics.groupRadius)
    }

    private func overline(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.scalable(size: NearbyMetrics.overline, weight: .bold))
            .tracking(NearbyMetrics.overline * 0.09)
            .textCase(.uppercase)
            .foregroundStyle(Color.inkSecondary)
            .padding(.leading, NearbyMetrics.overlineInset)
    }

    // MARK: Устройства

    private var devices: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Devices nearby")
                .font(.scalable(size: NearbyMetrics.overline, weight: .bold))
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
                ScaledSymbol(name: peer.isPad ? "ipad" : "iphone", box: NearbyMetrics.rowIcon)
                    .foregroundStyle(Color.inkPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: peer.name)
                        .font(.scalable(size: NearbyMetrics.rowName, weight: .medium))
                        .foregroundStyle(Color.inkPrimary)
                        .lineLimit(1)
                    Group {
                        if connecting {
                            Text("Connecting…")
                        } else {
                            Text(verbatim: peer.model)
                        }
                    }
                    .font(.scalable(size: NearbyMetrics.rowDetail))
                    .foregroundStyle(Color.inkSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if connecting {
                    ProgressView()
                        .tint(Color.inkPrimary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.scalable(size: 15, weight: .semibold))
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
            ScaledSymbol(name: "antenna.radiowaves.left.and.right", box: NearbyMetrics.scanIcon)
                .foregroundStyle(Color.inkPrimary)
            Text(transport.peers.isEmpty ? "Searching for devices…" : "Still searching…")
                .font(.scalable(size: NearbyMetrics.scanText))
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
            .font(.scalable(size: NearbyMetrics.note))
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

// MARK: - Превью iPad

private struct NearbyPadDemo: View {
    var found: [(name: String, model: String)] = []
    var connecting: Int?
    var mirrored = false
    @State private var transport = MultipeerTransport(displayName: "Превью", model: "iPad")

    var body: some View {
        ZStack {
            SeaBackground()
                .ignoresSafeArea()
            NearbyScreen(transport: transport)
        }
        .environment(\.usesPadLayout, true)
        .environment(\.mirrorsBottomTiles, mirrored)
        .preferredColorScheme(.dark)
        .onAppear { transport.showForPreview(found, connectingTo: connecting) }
    }
}

private let nearbyDemoPeers: [(name: String, model: String)] =
    [("iPhone Бориса", "iPhone"), ("iPad Ксюши", "iPad"), ("Мамин iPhone", "iPhone")]

struct NearbyPadPreview1: PreviewProvider {
    static var previews: some View {
        NearbyPadDemo()
            .padPreview(.portrait, "Рядом · iPad · поиск · вертикально")
    }
}

struct NearbyPadPreview2: PreviewProvider {
    static var previews: some View {
        NearbyPadDemo(found: nearbyDemoPeers)
            .padPreview(.portrait, "Рядом · iPad · нашлись · вертикально")
    }
}

struct NearbyPadPreview3: PreviewProvider {
    static var previews: some View {
        NearbyPadDemo()
            .padPreview(.landscapeLeft, "Рядом · iPad · поиск · горизонтально")
    }
}

struct NearbyPadPreview4: PreviewProvider {
    static var previews: some View {
        NearbyPadDemo(found: nearbyDemoPeers, connecting: 0, mirrored: true)
            .padPreview(.landscapeLeft, "Рядом · iPad · подключение · своё поле справа")
    }
}

struct NearbyPadPreview5: PreviewProvider {
    static var previews: some View {
        NearbyPadDemo(found: nearbyDemoPeers + [("iPad Пети", "iPad"), ("iPhone Гостя", "iPhone"),
                                                ("Папин iPad", "iPad")])
            .padPreview(.landscapeLeft, "Рядом · iPad · много устройств · горизонтально")
    }
}
