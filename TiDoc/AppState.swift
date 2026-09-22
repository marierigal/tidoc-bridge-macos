//
//  AppState.swift
//  TiDoc
//
//  Created by Marie Rigal on 21/09/2026.
//


import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var lastSyncDate: Date?
    @Published var isSyncing = false
    @Published var syncError: String?
    @Published var isConnected = false

    private let vaporServer = VaporServer()
    private let syncManager: CRMSyncManager
    private let importService: ClientImportService
    private var activeLoginWindow: NSWindow?

    init() {
        let exportsFolder = AppState.makeExportsFolder()
        self.syncManager = CRMSyncManager(destinationFolder: exportsFolder)
        self.importService = ClientImportService(
            syncManager: syncManager,
            dbQueue: DatabaseManager.shared
        )

        Task {
            await vaporServer.start()
        }
    }

    private static func makeExportsFolder() -> URL {
        AppPaths.exportsFolder
    }

    func synchronize() async {
        isSyncing = true
        syncError = nil
        defer { isSyncing = false }

        do {
            try await importService.synchronizeAndImport()
            lastSyncDate = Date()
        } catch {
            if case CRMSyncError.sessionExpired = error {
                isConnected = false // reflect reality: session was invalidated server-side
            }
            print("Sync failed: \(error)")
            syncError = "La synchronisation a échoué : \(error.localizedDescription)"
        }
    }

    func openLoginWindow() {
        let window = syncManager.loginWindow()
        activeLoginWindow = window
        window.makeKeyAndOrderFront(nil)

        Task {
            do {
                try await syncManager.waitForLoginThenLoadDashboard()
                isConnected = true
                activeLoginWindow?.close()
                activeLoginWindow = nil
            } catch {
                print("Connection wait failed: \(error)")
            }
        }
    }

    func logOutFromCRM() async {
        await syncManager.logOut()
        isConnected = false
    }

    func stopServer() async {
        await vaporServer.stop()
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }
}
