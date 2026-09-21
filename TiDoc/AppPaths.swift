//
//  AppPaths.swift
//  TiDoc
//
//  Created by Marie Rigal on 21/09/2026.
//

import Foundation

enum AppPaths {
    static let appSupportFolder: URL = {
        let folder = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TiDoc", isDirectory: true)

        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

    static let exportsFolder: URL = {
        let folder = appSupportFolder.appendingPathComponent("exports", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

    static let databaseFile: URL = {
        appSupportFolder.appendingPathComponent("tidoc.sqlite")
    }()

    static let certsFolder: URL = {
        appSupportFolder.appendingPathComponent("certs", isDirectory: true)
    }()
}
