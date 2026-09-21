//
//  AppPaths.swift
//  TiDoc
//
//  Created by Marie Rigal on 21/09/2026.
//

import Foundation

enum AppPaths {
    static let applicationSupportFolder: URL = {
        let folder = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TiDoc", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

    static let exportsFolder: URL = {
        let folder = applicationSupportFolder.appendingPathComponent("exports", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

    static let databaseFolder: URL = {
        let folder = applicationSupportFolder.appendingPathComponent("database", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()
}
