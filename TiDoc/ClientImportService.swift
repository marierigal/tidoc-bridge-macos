//
//  ClientImportService.swift
//  TiDoc
//
//  Created by Marie Rigal on 21/09/2026.
//


import Foundation
import GRDB

@MainActor
final class ClientImportService {
    private let syncManager: CRMSyncManager
    private let dbQueue: DatabaseQueue

    init(syncManager: CRMSyncManager, dbQueue: DatabaseQueue) {
        self.syncManager = syncManager
        self.dbQueue = dbQueue
    }

    func synchronizeAndImport(categories: [CRMTab] = CRMTab.allCases) async throws {
        let results = try await syncManager.synchronize(categories: categories)

        for result in results {
            let category = result.tab.rawValue

            guard let url = result.url else {
                // No export button was available: the category is empty on
                // the CRM side, clear any previously imported rows for it
                _ = try await dbQueue.write { db in
                    try ClientRecord.filter(Column("category") == category).deleteAll(db)
                }
                continue
            }

            // Parsing happens BEFORE touching the database: if a line is
            // malformed, this throws and the previous data for this category
            // stays untouched
            let records = try CSVClientParser.parse(fileURL: url, category: category)

            try await dbQueue.write { db in
                try ClientRecord.filter(Column("category") == category).deleteAll(db)
                for record in records {
                    try record.insert(db)
                }
            }
        }
    }
}
