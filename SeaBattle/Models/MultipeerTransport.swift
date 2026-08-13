//
//  MultipeerTransport.swift
//  SeaBattle
//
//  Phase 5: offline/nearby transport for networked play over MultipeerConnectivity
//  (Wi-Fi / Bluetooth, works in airplane mode). Implements NetworkTransport by
//  JSON-encoding NetworkMessage over an MCSession. Delegate callbacks arrive off
//  the main thread and are hopped to the main actor before touching state.
//  Requires NSLocalNetworkUsageDescription + NSBonjourServices in Info.plist.
//

import Foundation
import Observation
import MultipeerConnectivity

@MainActor
@Observable
final class MultipeerTransport: NSObject, NetworkTransport {

    @ObservationIgnored var onReceive: ((NetworkMessage) -> Void)?
    @ObservationIgnored var onConnectionChange: ((Bool) -> Void)?

    /// Peers a joining player can see and tap to connect to.
    private(set) var discoveredPeers: [MCPeerID] = []
    private(set) var isConnected = false

    private static let serviceType = "seabattle-mp"
    let myPeerID: MCPeerID
    @ObservationIgnored private let session: MCSession
    @ObservationIgnored private var advertiser: MCNearbyServiceAdvertiser?
    @ObservationIgnored private var browser: MCNearbyServiceBrowser?

    init(displayName: String) {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        let name = String((trimmed.isEmpty ? "Player" : trimmed).prefix(60))
        myPeerID = MCPeerID(displayName: name)
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        super.init()
        session.delegate = self
    }

    /// Host: become discoverable.
    func startHosting() {
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: Self.serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    /// Guest: look for hosts.
    func startBrowsing() {
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: Self.serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    func invite(_ peer: MCPeerID) {
        browser?.invitePeer(peer, to: session, withContext: nil, timeout: 20)
    }

    func stopDiscovery() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
    }

    func disconnect() {
        stopDiscovery()
        session.disconnect()
    }

    func send(_ message: NetworkMessage) {
        guard !session.connectedPeers.isEmpty, let data = try? JSONEncoder().encode(message) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }
}

// MARK: - MCSessionDelegate

extension MultipeerTransport: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                self.isConnected = true
                self.stopDiscovery()
                self.onConnectionChange?(true)
            case .notConnected:
                self.isConnected = false
                self.onConnectionChange?(false)
            default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(NetworkMessage.self, from: data) else { return }
        Task { @MainActor in self.onReceive?(message) }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - Advertiser / Browser

extension MultipeerTransport: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                didReceiveInvitationFromPeer peerID: MCPeerID,
                                withContext context: Data?,
                                invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in invitationHandler(true, self.session) } // auto-accept the single opponent
    }
}

extension MultipeerTransport: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            if !self.discoveredPeers.contains(peerID) { self.discoveredPeers.append(peerID) }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in self.discoveredPeers.removeAll { $0 == peerID } }
    }
}
