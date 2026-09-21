//
//  MenuBarContentView.swift
//  TiDoc
//
//  Created by Marie Rigal on 21/09/2026.
//


import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if let lastSync = appState.lastSyncDate {
            Text("Dernière synchro : \(lastSync.formatted(date: .abbreviated, time: .shortened))")
        } else {
            Text("Aucune synchro effectuée")
        }

        if let error = appState.syncError {
            Text(error)
                .foregroundStyle(.red)
        }

        Divider()

        Button("Synchroniser maintenant") {
            Task {
                await appState.synchroniser()
            }
        }
        .disabled(appState.isSyncing)

        Button("Se connecter au CRM") {
            appState.ouvrirFenetreDeConnexion()
        }

        Divider()

        Button("Quitter TiDoc") {
            appState.quitter()
        }
    }
}
