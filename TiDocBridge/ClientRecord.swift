//
//  ClientRecord.swift
//  TiDocBridge
//
//  Created by Marie Rigal on 21/09/2026.
//


import GRDB
import Foundation

struct ClientRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "clients"

    var reference: String
    var category: String
    var type: String
    var company: String?
    var siret: String?
    var firstName: String?
    var lastName: String?
    var email: String?
    var phone: String?
    var address: String?
    var cp: String?
    var city: String?
    var note: String?
    var accountantId: String?
    var updatedAt: Date

    func toDTO() -> ClientDTO {
        ClientDTO(
            reference: reference,
            type: type == "Professionnel" ? .professional : .individual,
            company: company,
            siret: siret,
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: phone,
            address: address,
            cp: cp,
            city: city,
            note: note,
            accountantId: accountantId
        )
    }
}
