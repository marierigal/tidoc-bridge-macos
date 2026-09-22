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
    @Published var isAddInInstalled = AddInInstaller.isInstalled
    @Published var addInError: String?

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

        Task {
            await refreshLastSyncDate()
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
            await refreshLastSyncDate()
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

    var hasFullDiskAccess: Bool {
        let testFile = AddInInstaller.wefFolder.appendingPathComponent(".tidoc-access-test")

        do {
            try FileManager.default.createDirectory(at: AddInInstaller.wefFolder, withIntermediateDirectories: true)
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(at: testFile)
            return true
        } catch {
            return false
        }
    }

    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    func installAddIn() {
        guard hasFullDiskAccess else {
            addInError = "TiDoc a besoin de l'accès complet au disque pour installer le complément Word."
            showFullDiskAccessAlert()
            return
        }

        do {
            try AddInInstaller.install()
            isAddInInstalled = true
            addInError = nil
            showRestartWordAlert()
        } catch {
            addInError = "Installation impossible : \(error.localizedDescription)"
        }
    }

    func uninstallAddIn() {
        do {
            try AddInInstaller.uninstall()
            isAddInInstalled = false
            addInError = nil
            showRestartWordAlert()
        } catch {
            addInError = "Désinstallation impossible : \(error.localizedDescription)"
        }
    }

    private func showRestartWordAlert() {
        let alert = NSAlert()
        alert.messageText = "Redémarrage de Word nécessaire"
        alert.informativeText = "Fermez et rouvrez Word pour que le complément apparaisse."
        alert.alertStyle = .informational
        alert.runModal()
    }

    private func showFullDiskAccessAlert() {
        let alert = NSAlert()
        alert.messageText = "Autorisation nécessaire"
        alert.informativeText = "Ouvrez Réglages Système, ajoutez TiDoc à la liste \"Accès complet au disque\", puis réessayez."
        alert.addButton(withTitle: "Ouvrir Réglages Système")
        alert.addButton(withTitle: "Annuler")

        if alert.runModal() == .alertFirstButtonReturn {
            openFullDiskAccessSettings()
        }
    }

    private func refreshLastSyncDate() async {
        do {
            lastSyncDate = try await MetadataStore.getLastSyncDate()
        } catch {
            print("Failed to read last sync date: \(error)")
        }
    }
}
