//
//  CloudSyncManager.swift
//  SeaBattle
//
//  Phase 3: iCloud sync with NO authorization and NO backend. Mirrors the two
//  local stores (ProgressStore = points wallet + wins/losses; ProfileStore =
//  up to 10 players with names + avatars) to the user's CloudKit PRIVATE
//  database, so data follows them across their devices automatically. Premium
//  entitlement already syncs by itself via StoreKit.
//
//  Strategy: each store is one small JSON blob record ("progress" / "profiles")
//  carrying a `modified` timestamp; last-writer-wins. Pull on launch/foreground,
//  debounced push on local change. Degrades to local-only when iCloud is off or
//  the CloudKit capability isn't enabled.
//
//  MANUAL step: enable the iCloud → CloudKit capability (default container) on
//  the app target.
//

import Foundation
import Observation
import CloudKit

@MainActor
@Observable
final class CloudSyncManager {

    static let shared = CloudSyncManager()

    enum Kind: String, CaseIterable { case progress, profiles }

    private let database = CKContainer.default().privateCloudDatabase
    private static let recordType = "SyncBlob"

    private(set) var available = false
    @ObservationIgnored private var pushTasks: [Kind: Task<Void, Never>] = [:]

    /// Installs change hooks and does the first pull. Call once at launch.
    func start() {
        ProgressStore.shared.didChange = { [weak self] in self?.schedulePush(.progress) }
        ProfileStore.shared.didChange = { [weak self] in self?.schedulePush(.profiles) }
        Task { await refresh() }
    }

    /// Pulls both records (call on launch and when returning to the foreground).
    func refresh() async {
        let status = try? await CKContainer.default().accountStatus()
        available = (status == .available)
        guard available else { return }
        for kind in Kind.allCases { await pull(kind) }
    }

    // MARK: - Store bridge

    private func localData(for kind: Kind) -> (data: Data?, modified: Date) {
        switch kind {
        case .progress: return (ProgressStore.shared.exportData(), ProgressStore.shared.lastModified)
        case .profiles: return (ProfileStore.shared.exportData(), ProfileStore.shared.lastModified)
        }
    }

    private func applyRemote(_ kind: Kind, data: Data, modified: Date) {
        switch kind {
        case .progress: ProgressStore.shared.applyRemote(data, modified: modified)
        case .profiles: ProfileStore.shared.applyRemote(data, modified: modified)
        }
    }

    // MARK: - Pull / push (last-writer-wins)

    private func pull(_ kind: Kind) async {
        let recordID = CKRecord.ID(recordName: kind.rawValue)
        do {
            let record = try await database.record(for: recordID)
            let remoteModified = record["modified"] as? Date ?? .distantPast
            let local = localData(for: kind)
            if remoteModified > local.modified, let data = record["data"] as? Data {
                applyRemote(kind, data: data, modified: remoteModified)
            } else if local.modified > remoteModified {
                await push(kind)
            }
        } catch let error as CKError where error.code == .unknownItem {
            await push(kind) // nothing in the cloud yet
        } catch {
            // offline / not available — stay local, retry later
        }
    }

    private func schedulePush(_ kind: Kind) {
        pushTasks[kind]?.cancel()
        pushTasks[kind] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1)) // debounce bursts of changes
            if Task.isCancelled { return }
            await self?.push(kind)
        }
    }

    private func push(_ kind: Kind) async {
        guard available else { return }
        let local = localData(for: kind)
        guard let data = local.data else { return }
        let recordID = CKRecord.ID(recordName: kind.rawValue)
        do {
            let record = (try? await database.record(for: recordID))
                ?? CKRecord(recordType: Self.recordType, recordID: recordID)
            record["data"] = data as any CKRecordValue
            record["modified"] = local.modified as any CKRecordValue
            _ = try await database.save(record)
        } catch {
            // ignore; a later change or refresh will retry
        }
    }
}
