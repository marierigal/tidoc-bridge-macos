//
//  AppDelegate.swift
//  TiDoc
//
//  Created by Marie Rigal on 21/09/2026.
//


import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let appState else { return .terminateNow }

        Task {
            await appState.arreterServeur()
            NSApp.reply(toApplicationShouldTerminate: true)
        }

        return .terminateLater
    }
}