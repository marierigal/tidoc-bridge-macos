//
//  routes.swift
//  TiDocBridge
//
//  Created by Marie Rigal on 21/09/2026.
//


import Vapor

func routes(_ app: Application, repository: ClientRepository) throws {
    app.get("health") { _ in "OK" }

    app.get("clients") { req async throws -> [ClientDTO] in
        try await repository.getAll()
    }

    app.get("clients", "search") { req async throws -> [ClientDTO] in
        guard let query = req.query[String.self, at: "q"], !query.isEmpty else {
            throw Abort(.badRequest, reason: "Missing 'q' query parameter")
        }
        return try await repository.search(query: query)
    }
}
