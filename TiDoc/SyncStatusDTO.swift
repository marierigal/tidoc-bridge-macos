//
//  SyncStatusDTO.swift
//  TiDoc
//
//  Created by Marie Rigal on 22/09/2026.
//

import Vapor

struct SyncStatusDTO: Content {
    let lastSyncDate: Date?
}
