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

        Button(appState.isSyncing ? "Synchronisation en cours..." : "Synchroniser maintenant") {
            Task {
                await appState.synchronize()
            }
        }
        .disabled(appState.isSyncing)

        if appState.isConnected {
            Button("Se déconnecter du CRM") {
                Task { await appState.logOutFromCRM() }
            }
        } else {
            Button("Se connecter au CRM") {
                appState.openLoginWindow()
            }
        }

        Divider()

        if appState.isAddInInstalled {
            Button("Désinstaller l'add-in Word") {
                appState.uninstallAddIn()
            }
        } else {
            Button("Installer l'add-in Word") {
                appState.installAddIn()
            }
        }

        if let addInError = appState.addInError {
            Text(addInError)
                .foregroundStyle(.red)
        }

        Divider()

        Button("Quitter TiDoc") {
            appState.quit()
        }
    }
}
