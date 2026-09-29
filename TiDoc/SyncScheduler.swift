//
//  SyncScheduler.swift
//  TiDoc
//
//  Created by Marie Rigal on 29/09/2026.
//


import AppKit

@MainActor
final class SyncScheduler {
    private var timer: Timer?
    private let checkIntervalSeconds: TimeInterval
    private let onFire: () async -> Void

    init(checkIntervalSeconds: TimeInterval = 30 * 60, onFire: @escaping () async -> Void) {
        self.checkIntervalSeconds = checkIntervalSeconds
        self.onFire = onFire

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    deinit {
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    func start() {
        Task { await checkAndSyncIfNeeded() }

        timer = Timer.scheduledTimer(withTimeInterval: checkIntervalSeconds, repeats: true) { [weak self] _ in
            Task { await self?.checkAndSyncIfNeeded() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    @objc private func handleWake() {
        Task { await checkAndSyncIfNeeded() }
    }

    /// Runs a sync only if none has happened yet today. Covers two cases at
    /// once: the first wake of the day (most common case here), and a Mac
    /// that stays awake all day (the periodic timer eventually catches it).
    private func checkAndSyncIfNeeded() async {
        let lastSync = try? await MetadataStore.getLastSyncDate()
        let alreadySyncedToday = lastSync.map { Calendar.current.isDateInToday($0) } ?? false

        guard !alreadySyncedToday else { return }
        await onFire()
    }
}