//
//  PhoneFormatter.swift
//  TiDoc
//
//  Created by Marie Rigal on 28/09/2026.
//


import Foundation

enum PhoneFormatter {
    /// Country calling codes with a length different from the common 2-digit
    /// default. Not exhaustive — covers codes most likely to appear for a
    /// French business' contacts. Extend these sets if a client's country
    /// isn't formatted correctly.
    nonisolated private static let oneDigitCodes: Set<String> = ["1", "7"]
    nonisolated private static let threeDigitCodes: Set<String> = [
        "212", "213", "216", "351", "352", "353", "356", "357", "358", "359",
        "370", "371", "372", "373", "374", "375", "376", "377", "378", "380",
        "381", "382", "385", "386", "387", "389", "420", "421", "423",
    ]

    /// Formats an international phone number ("+XX...").
    /// French numbers ("+33...") are converted to the familiar national
    /// format (06 12 34 56 78). Other countries keep their "+XX" prefix,
    /// with the remaining digits grouped for readability.
    /// Returns the original value untouched if it isn't in "+XX..." format,
    /// or if it can't be parsed reliably.
    nonisolated static func format(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return raw }

        let cleaned = raw.replacingOccurrences(of: "(0)", with: "")
        guard cleaned.trimmingCharacters(in: .whitespaces).hasPrefix("+") else {
            return raw
        }

        let digits = cleaned.filter(\.isNumber)
        guard !digits.isEmpty else { return raw }

        let countryCodeLength: Int
        if oneDigitCodes.contains(String(digits.prefix(1))) {
            countryCodeLength = 1
        } else if threeDigitCodes.contains(String(digits.prefix(3))) {
            countryCodeLength = 3
        } else {
            countryCodeLength = 2
        }

        guard digits.count > countryCodeLength else { return raw }

        let countryCode = String(digits.prefix(countryCodeLength))
        let nationalDigits = String(digits.dropFirst(countryCodeLength))

        if countryCode == "33" {
            return formatFrenchNational(nationalDigits, fallback: raw)
        }

        return "+\(countryCode) \(groupGeneric(nationalDigits))"
    }

    nonisolated private static func formatFrenchNational(_ nationalDigits: String, fallback: String) -> String {
        let digits = "0" + nationalDigits
        guard digits.count == 10 else { return fallback }

        return stride(from: 0, to: 10, by: 2)
            .map { index -> String in
                let start = digits.index(digits.startIndex, offsetBy: index)
                let end = digits.index(start, offsetBy: 2)
                return String(digits[start..<end])
            }
            .joined(separator: " ")
    }

    /// Generic grouping heuristic (not a real per-country numbering plan):
    /// pairs of 2 digits, with any odd leftover digit folded into a 3-digit
    /// first group. This happens to match common conventions like Belgian
    /// mobile numbers ("470 12 34 56"), but isn't authoritative for every
    /// country's actual numbering plan.
    nonisolated private static func groupGeneric(_ digits: String) -> String {
        var remaining = Substring(digits)
        var groups: [String] = []

        if digits.count % 2 != 0 {
            groups.append(String(remaining.prefix(3)))
            remaining = remaining.dropFirst(min(3, remaining.count))
        }

        while !remaining.isEmpty {
            let take = min(2, remaining.count)
            groups.append(String(remaining.prefix(take)))
            remaining = remaining.dropFirst(take)
        }

        return groups.joined(separator: " ")
    }
}
