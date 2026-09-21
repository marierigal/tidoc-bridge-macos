//
//  ClientRepository.swift
//  TiDocBridge
//
//  Created by Marie Rigal on 21/09/2026.
//


import Vapor

protocol ClientRepository: Sendable {
    func getAll() async throws -> [ClientDTO]
    func search(query: String) async throws -> [ClientDTO]
}

/// Temporary in-memory implementation, until GRDB persistence is wired up.
struct InMemoryClientRepository: ClientRepository {
    let clients: [ClientDTO] = [
        ClientDTO(
            reference: "TEST-001",
            type: .professional,
            company: "ACME Corp",
            siret: "123 456 789",
            firstName: nil,
            lastName: nil,
            email: "contact@acme.fr",
            phone: "0102030405",
            address: "12 rue des Lilas",
            cp: "69000",
            city: "Lyon",
            note: nil,
            accountantId: nil
        )
    ]

    func getAll() async throws -> [ClientDTO] {
        clients
    }

    func search(query: String) async throws -> [ClientDTO] {
        let lowered = query.lowercased()
        return clients.filter {
            ($0.company?.lowercased().contains(lowered) ?? false) ||
            ($0.lastName?.lowercased().contains(lowered) ?? false)
        }
    }
}
