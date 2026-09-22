//
//  VaporServer.swift
//  TiDoc
//
//  Created by Marie Rigal on 21/09/2026.
//


import Vapor

@MainActor
final class VaporServer {
    private var app: Application?

    func start() async {
        guard app == nil else { return } // already running, avoid starting twice

        do {
            try CertificateService.ensureCertificateIsReadyAndTrusted()
        } catch {
            print("Certificate setup failed: \(error)")
            return
        }

        let environment = Environment(name: "development", arguments: ["vapor"])

        do {
            let application = try await Application.make(environment)

            try configure(application)
            self.app = application

            // `execute()` runs until shutdown is triggered — must run on its
            // own detached task, otherwise it would block AppState's init
            Task.detached {
                do {
                    try await application.execute()
                } catch {
                    print("Vapor server stopped with error: \(error)")
                }
            }
        } catch {
            print("Failed to configure Vapor: \(error)")
        }
    }

    func stop() async {
        guard let app else { return }
        try? await app.asyncShutdown()
        self.app = nil
    }
}
