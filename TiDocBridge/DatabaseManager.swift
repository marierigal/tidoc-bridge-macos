//
//  DatabaseManager.swift
//  TiDocBridge
//
//  Created by Marie Rigal on 21/09/2026.
//


import GRDB
import Foundation

enum DatabaseManager {
    static let shared: DatabaseQueue = {
        let dbPath = AppPaths.databaseFolder.appendingPathComponent("tidoc.sqlite").path

        do {
            let dbQueue = try DatabaseQueue(path: dbPath)
            try migrator.migrate(dbQueue)
            return dbQueue
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
    }()

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("createClients") { db in
            try db.create(table: "clients") { t in
                t.column("reference", .text)
                t.column("category", .text).notNull()
                t.column("type", .text).notNull()
                t.column("company", .text)
                t.column("siret", .text)
                t.column("firstName", .text)
                t.column("lastName", .text)
                t.column("email", .text)
                t.column("phone", .text)
                t.column("address", .text)
                t.column("cp", .text)
                t.column("city", .text)
                t.column("note", .text)
                t.column("accountantId", .text)
                t.column("updatedAt", .datetime).notNull()
                t.primaryKey(["category", "reference"])
            }
        }

        return migrator
    }
}
