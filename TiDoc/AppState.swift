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

    private let vaporServer = VaporServer()
    private let syncManager: CRMSyncManager
    private let importService: ClientImportService
    private var connexionWindow: NSWindow?

    init() {
        let exportsFolder = AppPaths.exportsFolder
        self.syncManager = CRMSyncManager(dossierDestination: exportsFolder)
        self.importService = ClientImportService(
            syncManager: syncManager,
            dbQueue: DatabaseManager.shared
        )

        Task {
            await vaporServer.start()
        }
    }

    func synchroniser() async {
        isSyncing = true
        syncError = nil
        defer { isSyncing = false }

        do {
            try await importService.synchroniserEtImporter()
            lastSyncDate = Date()
        } catch {
            print("Sync failed: \(error)")
            syncError = "La synchronisation a échoué : \(error.localizedDescription)"
        }
    }

    func ouvrirFenetreDeConnexion() {
        let window = syncManager.fenetreDeConnexion()
        connexionWindow = window
        window.makeKeyAndOrderFront(nil)

        Task {
            do {
                try await syncManager.attendreConnexionPuisChargerDashboard()
                connexionWindow?.close()
                connexionWindow = nil
            } catch {
                print("Connection wait failed: \(error)")
            }
        }
    }

    func quitter() async {
        await vaporServer.stop()
        NSApplication.shared.terminate(nil)
    }
}
