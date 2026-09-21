//
//  AppState.swift
//  TiDocBridge
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

    init() {
        Task {
            await vaporServer.start()
        }
    }

    func synchroniser() async {
        isSyncing = true
        defer { isSyncing = false }
        // TODO: brancher CRMSyncManager ici
        lastSyncDate = Date()
    }

    func ouvrirFenetreDeConnexion() {
        // TODO: instancier CRMSyncManager et appeler fenetreDeConnexion()
    }

    func quitter() async {
        await vaporServer.stop()
        NSApplication.shared.terminate(nil)
    }
}
