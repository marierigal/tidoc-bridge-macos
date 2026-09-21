//
//  configure.swift
//  TiDocBridge
//
//  Created by Marie Rigal on 21/09/2026.
//


import Vapor
import NIOSSL

func configure(_ app: Application) throws {
    // TLS via mkcert-generated files (dev only — see note above about
    // distribution needing a different, automated cert flow)
    let certPath = "/Users/\(NSUserName())/Library/Application Support/TiDoc Bridge/certs/localhost.pem"
    let keyPath = "/Users/\(NSUserName())/Library/Application Support/TiDoc Bridge/certs/localhost-key.pem"

    app.http.server.configuration.tlsConfiguration = .makeServerConfiguration(
        certificateChain: try NIOSSLCertificate.fromPEMFile(certPath).map { .certificate($0) },
        privateKey: .privateKey(try NIOSSLPrivateKey(file: keyPath, format: .pem))
    )
    app.http.server.configuration.hostname = "127.0.0.1"
    app.http.server.configuration.port = 4321

    // CORS: allow the add-in's Vercel origin specifically (not "*",
    // since the browser blocks wildcard origin when combined with
    // certain request headers, and it's better practice anyway)
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .custom("https://ton-projet.vercel.app"),
        allowedMethods: [.GET, .OPTIONS],
        allowedHeaders: [.accept, .contentType]
    )
    app.middleware.use(CORSMiddleware(configuration: corsConfiguration), at: .beginning)

    let repository = InMemoryClientRepository()
    try routes(app, repository: repository)
}
