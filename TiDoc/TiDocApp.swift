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
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        MenuBarExtra("TiDoc", systemImage: "person.crop.circle.fill.badge.plus") {
            MenuBarContentView()
                .environmentObject(appState)
                .task {
                    appDelegate.appState = appState
                }
        }
        .menuBarExtraStyle(.menu)
    }
}
