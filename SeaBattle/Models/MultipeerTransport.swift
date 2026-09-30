//
//  MultipeerTransport.swift
//  SeaBattle
//
//  Nearby transport for networked play over MultipeerConnectivity (Wi-Fi /
//  Bluetooth, works without internet). Implements NetworkTransport by
//  JSON-encoding NetworkMessage over an MCSession. Delegate callbacks arrive
//  off the main thread and are hopped to the main actor before touching state.
//  Requires NSLocalNetworkUsageDescription + NSBonjourServices in Info.plist.
//
//  R3.3: discovery is symmetric — every device on the "Nearby" screen both
//  advertises and browses, so the list shows everyone who opened the mode and
//  either side can tap the other (spec 4.8, frame `screen5NetNearby`). There
//  is no host / join choice any more; who shoots first is decided by the
//  match itself (`NetGame.iShootFirst`).
//
//  Multipeer reports neither signal strength nor distance, so the list shows
//  the player's name and the kind of device only.
//

import Foundation
import Observation
import MultipeerConnectivity

/// A device found nearby.
struct NearbyPeer: Identifiable, Equatable {
    let peerID: MCPeerID
    /// "iPhone" / "iPad" — sent in the discovery info.
    let model: String

    var id: MCPeerID { peerID }
    var name: String { peerID.displayName }
    var isPad: Bool { model == "iPad" }
}

@MainActor
@Observable
final class MultipeerTransport: NSObject, NetworkTransport {

    @ObservationIgnored var onReceive: ((NetworkMessage) -> Void)?
    @ObservationIgnored var onConnectionChange: ((Bool) -> Void)?

    /// Devices with the "Nearby" screen open, in the order they were found.
    private(set) var peers: [NearbyPeer] = []
    /// The device this one is connecting to or connected with.
    private(set) var partner: MCPeerID?
    private(set) var isConnected = false

    private static let serviceType = "seabattle-mp"
    let myPeerID: MCPeerID
    private let model: String
    /// MCSession is created once and is safe to use from the Multipeer delegate
    /// queue; the invitation handler must be answered there, so the session
    /// cannot live behind the main actor.
    @ObservationIgnored nonisolated(unsafe) private let session: MCSession
    @ObservationIgnored private var advertiser: MCNearbyServiceAdvertiser?
    @ObservationIgnored private var browser: MCNearbyServiceBrowser?
    /// This side sent the invitation — after a drop it is the one to invite
    /// again, so the two devices do not invite each other at once.
    @ObservationIgnored private var invitedPartner = false

    init(displayName: String, model: String) {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        let name = String((trimmed.isEmpty ? "Player" : trimmed).prefix(60))
        myPeerID = MCPeerID(displayName: name)
        self.model = model
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        super.init()
        session.delegate = self
    }

    /// Opened the "Nearby" screen: become visible and look for others.
    func startDiscovery() {
        if advertiser == nil {
            advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: ["model": model],
                                                   serviceType: Self.serviceType)
            advertiser?.delegate = self
        }
        if browser == nil {
            browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: Self.serviceType)
            browser?.delegate = self
        }
        advertiser?.startAdvertisingPeer()
        browser?.startBrowsingForPeers()
    }

    func stopDiscovery() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
    }

    /// Tapped a device in the list.
    func invite(_ peer: NearbyPeer) {
        guard partner == nil else { return }
        partner = peer.peerID
        invitedPartner = true
        browser?.invitePeer(peer.peerID, to: session, withContext: nil, timeout: 20)
    }

    // MARK: NetworkTransport

    func send(_ message: NetworkMessage) {
        guard !session.connectedPeers.isEmpty, let data = try? JSONEncoder().encode(message) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    /// After a drop: look for the same device again. The side that invited
    /// the first time invites again once it reappears (`foundPeer`).
    func reconnect() {
        guard !isConnected else { return }
        startDiscovery()
        if invitedPartner, let partner, peers.contains(where: { $0.peerID == partner }) {
            browser?.invitePeer(partner, to: session, withContext: nil, timeout: 20)
        }
    }

    func disconnect() {
        stopDiscovery()
        session.disconnect()
        partner = nil
        isConnected = false
    }

    // MARK: Delegate events on the main actor

    fileprivate func stateChanged(_ peer: MCPeerID, _ state: MCSessionState) {
        switch state {
        case .connected:
            partner = peer
            isConnected = true
            stopDiscovery()
            onConnectionChange?(true)
        case .notConnected:
            guard peer == partner else { return }
            if isConnected {
                isConnected = false
                onConnectionChange?(false)
            } else if invitedPartner && onReceive == nil {
                // An invitation that did not go through, still in the lobby:
                // the device can be tapped again.
                partner = nil
                invitedPartner = false
            }
        default:
            break
        }
    }

    fileprivate func found(_ peer: MCPeerID, model: String) {
        if !peers.contains(where: { $0.peerID == peer }) {
            peers.append(NearbyPeer(peerID: peer, model: model))
        }
        // The partner came back after a drop — invite it again.
        if peer == partner, !isConnected, invitedPartner {
            browser?.invitePeer(peer, to: session, withContext: nil, timeout: 20)
        }
    }

    fileprivate func lost(_ peer: MCPeerID) {
        peers.removeAll { $0.peerID == peer }
    }
}

// MARK: - MCSessionDelegate

extension MultipeerTransport: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        // MCPeerID is immutable but not marked Sendable, so hand it over explicitly.
        nonisolated(unsafe) let peer = peerID
        Task { @MainActor in self.stateChanged(peer, state) }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(NetworkMessage.self, from: data) else { return }
        Task { @MainActor in self.onReceive?(message) }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: (any Error)?) {}
}

// MARK: - Advertiser / Browser

extension MultipeerTransport: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                didReceiveInvitationFromPeer peerID: MCPeerID,
                                withContext context: Data?,
                                invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // One opponent at a time: accept only while nobody is connected.
        // Answered inline: the handler is not Sendable and Multipeer expects
        // a prompt reply on this queue.
        invitationHandler(session.connectedPeers.isEmpty, session)
    }
}

extension MultipeerTransport: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        nonisolated(unsafe) let peer = peerID
        let model = info?["model"] ?? "iPhone"
        Task { @MainActor in self.found(peer, model: model) }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        nonisolated(unsafe) let peer = peerID
        Task { @MainActor in self.lost(peer) }
    }
}
