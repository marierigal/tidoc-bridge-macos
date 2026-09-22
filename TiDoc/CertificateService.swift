//
//  CertificateService.swift
//  TiDoc
//
//  Created by Marie Rigal on 22/09/2026.
//


import Foundation

enum CertificateServiceError: LocalizedError {
    case opensslFailed(String)
    case trustInstallFailed(String)

    var errorDescription: String? {
        switch self {
        case .opensslFailed(let output):
            return "La génération du certificat a échoué : \(output)"
        case .trustInstallFailed(let output):
            return "L'installation de la confiance du certificat a échoué : \(output)"
        }
    }
}

enum CertificateService {
    static var certificateURL: URL { AppPaths.certsFolder.appendingPathComponent("localhost.pem") }
    static var keyURL: URL { AppPaths.certsFolder.appendingPathComponent("localhost-key.pem") }
    private static var trustFlagURL: URL { AppPaths.certsFolder.appendingPathComponent(".trust-installed") }

    static var certificateFilesExist: Bool {
        FileManager.default.fileExists(atPath: certificateURL.path) &&
        FileManager.default.fileExists(atPath: keyURL.path)
    }

    static var isTrustInstalled: Bool {
        FileManager.default.fileExists(atPath: trustFlagURL.path)
    }

    /// Generates a self-signed certificate for localhost/127.0.0.1 if none
    /// exists yet, then installs it as trusted in the user's login keychain
    /// (one-time confirmation dialog on first run).
    static func ensureCertificateIsReadyAndTrusted() throws {
        if !certificateFilesExist {
            try generateCertificate()
        }
        if !isTrustInstalled {
            try installTrust()
            try Data().write(to: trustFlagURL) // empty marker file is enough
        }
    }

    private static func generateCertificate() throws {
        // Using a config file (rather than -addext) for compatibility: macOS
        // ships an openssl build that doesn't reliably support -addext across
        // versions, but the classic [alt_names] config section always works.
        let configContent = """
        [req]
        distinguished_name = req_distinguished_name
        x509_extensions = v3_req
        prompt = no

        [req_distinguished_name]
        CN = localhost

        [v3_req]
        subjectAltName = @alt_names

        [alt_names]
        DNS.1 = localhost
        IP.1 = 127.0.0.1
        """

        let configURL = AppPaths.certsFolder.appendingPathComponent("openssl.cnf")
        try configContent.write(to: configURL, atomically: true, encoding: .utf8)

        let output = try runProcess(
            "/usr/bin/openssl",
            arguments: [
                "req", "-x509", "-new", "-nodes",
                "-newkey", "rsa:2048",
                "-keyout", keyURL.path,
                "-out", certificateURL.path,
                "-days", "3650",
                "-config", configURL.path,
            ]
        )

        guard certificateFilesExist else {
            throw CertificateServiceError.opensslFailed(output)
        }
    }

    private static func installTrust() throws {
        let loginKeychainPath = FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Keychains/login.keychain-db")
            .path

        // trustRoot is correct here specifically because our certificate is
        // self-signed (it acts as its own root) — this is what tells the
        // system to trust it directly for the SSL policy, without needing a
        // separate CA chain.
        try runProcess(
            "/usr/bin/security",
            arguments: [
                "add-trusted-cert",
                "-p", "ssl",
                "-r", "trustRoot",
                "-k", loginKeychainPath,
                certificateURL.path,
            ]
        )
    }

    @discardableResult
    private static func runProcess(_ launchPath: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw CertificateServiceError.trustInstallFailed(output)
        }

        return output
    }
}
