//
//  TiDocApp.swift
//  TiDoc
//
//  Created by Marie Rigal on 21/09/2026.
//

import SwiftUI

@main
struct TiDocApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("TiDoc", systemImage: "link.circle") {
            MenuBarContentView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.menu)
    }
}
