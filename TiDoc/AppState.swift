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

    private var vaporServer = VaporServer()
    private var connexionWindow: NSWindow?

    private let crmSyncManager = CRMSyncManager(dossierDestination: AppPaths.exportsFolder)
    private lazy var importService = ClientImportService(
        syncManager: crmSyncManager,
        dbQueue: DatabaseManager.shared
    )

    init() {
        Task {
            await vaporServer.start()
        }
    }

    func synchroniser() async {
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await importService.synchroniserEtImporter()
            lastSyncDate = Date()
        } catch {
            print("Sync failed: \(error)")
            // TODO: afficher l'erreur à l'utilisateur (cohérent avec la stratégie
            // "erreurs remontées à l'UI" qu'on avait adoptée côté add-in)
        }
    }

    func ouvrirFenetreDeConnexion() {
        // TODO: instancier CRMSyncManager et appeler fenetreDeConnexion()
    }

    func quitter() async {
        await vaporServer.stop()
        NSApplication.shared.terminate(nil)
    }
}
