//
//  AddInInstaller.swift
//  TiDoc
//
//  Created by Marie Rigal on 22/09/2026.
//


import Foundation

enum AddInInstallerError: LocalizedError {
    case manifestNotFound
    case wordContainerNotFound

    var errorDescription: String? {
        switch self {
        case .manifestNotFound:
            return "Le fichier manifest.xml n'a pas été trouvé dans l'application."
        case .wordContainerNotFound:
            return "Le dossier de configuration de Word n'a pas pu être créé."
        }
    }
}

enum AddInInstaller {
    private static let manifestFileName = "TiDoc.manifest.xml"

    private static var installedManifestURL: URL {
        wefFolder.appendingPathComponent(manifestFileName)
    }

    static var wefFolder: URL {
        FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Containers/com.microsoft.Word/Data/Documents/wef", isDirectory: true)
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: installedManifestURL.path)
    }

    static func install() throws {
        guard let bundledManifest = Bundle.main.url(forResource: "manifest", withExtension: "xml") else {
            throw AddInInstallerError.manifestNotFound
        }

        do {
            try FileManager.default.createDirectory(at: wefFolder, withIntermediateDirectories: true)
        } catch {
            throw AddInInstallerError.wordContainerNotFound
        }

        // Remove any previous copy first, so re-installing after an update
        // isn't silently skipped just because the destination already exists
        try? FileManager.default.removeItem(at: installedManifestURL)
        try FileManager.default.copyItem(at: bundledManifest, to: installedManifestURL)
    }

    static func uninstall() throws {
        guard isInstalled else { return }
        try FileManager.default.removeItem(at: installedManifestURL)
    }
}
