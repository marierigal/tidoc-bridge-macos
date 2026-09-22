//
//  MetadataStore.swift
//  TiDoc
//
//  Created by Marie Rigal on 22/09/2026.
//


import GRDB
import Foundation

enum MetadataStore {
    nonisolated static let lastSyncDateKey = "lastSyncDate"

    static func setLastSyncDate(_ date: Date) async throws {
        try await DatabaseManager.shared.write { db in
            try db.execute(
                sql: "INSERT OR REPLACE INTO app_metadata (key, value) VALUES (?, ?)",
                arguments: [lastSyncDateKey, ISO8601DateFormatter().string(from: date)]
            )
        }
    }

    static func getLastSyncDate() async throws -> Date? {
        try await DatabaseManager.shared.read { db in
            guard let value = try String.fetchOne(
                db, sql: "SELECT value FROM app_metadata WHERE key = ?", arguments: [lastSyncDateKey]
            ) else {
                return nil
            }
            return ISO8601DateFormatter().date(from: value)
        }
    }
}
