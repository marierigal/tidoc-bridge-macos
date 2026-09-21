//
//  CSVParsingError.swift
//  TiDoc
//
//  Created by Marie Rigal on 21/09/2026.
//


import Foundation

enum CSVParsingError: LocalizedError {
    case unexpectedColumnCount(expected: Int, got: Int, line: String)
    case missingReference(line: String)
    case missingType(line: String)

    var errorDescription: String? {
        switch self {
        case .unexpectedColumnCount(let expected, let got, let line):
            return "Nombre de colonnes inattendu (\(got) au lieu de \(expected)) sur la ligne : \(line)"
        case .missingReference(let line):
            return "Référence manquante sur la ligne : \(line)"
        case .missingType(let line):
            return "Type manquant sur la ligne : \(line)"
        }
    }
}

enum CSVClientParser {
    private static let expectedColumnCount = 14

    static func parse(fileURL: URL, category: String) throws -> [ClientRecord] {
        var content = try String(contentsOf: fileURL, encoding: .utf8)

        // Strip UTF-8 BOM if present
        if content.hasPrefix("\u{FEFF}") {
            content.removeFirst()
        }

        let lines = content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard lines.count > 1 else { return [] } // header only, or empty file

        return try lines.dropFirst().map { try parseLine($0, category: category) }
    }

    private static func parseLine(_ line: String, category: String) throws -> ClientRecord {
        let columns = line.components(separatedBy: ";")

        guard columns.count == expectedColumnCount else {
            throw CSVParsingError.unexpectedColumnCount(
                expected: expectedColumnCount, got: columns.count, line: line
            )
        }

        func field(_ index: Int) -> String? {
            let value = columns[index].trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }

        guard let reference = field(0) else {
            throw CSVParsingError.missingReference(line: line)
        }
        guard let type = field(1) else {
            throw CSVParsingError.missingType(line: line)
        }

        return ClientRecord(
            reference: reference,
            category: category,
            type: type,
            company: field(2),
            siret: field(3),
            firstName: field(4),
            lastName: field(5),
            email: field(6),
            phone: field(7),
            phone2: field(8),
            address: field(9),
            cp: field(10),
            city: field(11),
            note: field(12),
            accountantId: field(13),
            updatedAt: Date()
        )
    }
}
