//
//  TiDocBridgeApp.swift
//  TiDocBridge
//
//  Created by Marie Rigal on 21/09/2026.
//

import SwiftUI

@main
struct TiDocBridgeApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("TiDoc Bridge", systemImage: "link.circle") {
            MenuBarContentView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.menu)
    }
}
