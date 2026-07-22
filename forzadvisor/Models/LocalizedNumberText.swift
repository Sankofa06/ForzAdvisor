//
//  LocalizedNumberText.swift
//  forzadvisor
//
//  Shared conversion between numeric model values and locale-aware text.
//

import Foundation

enum LocalizedNumberText {
    static func format(
        _ value: Double,
        fractionDigits: Int,
        locale: Locale = .current
    ) -> String {
        let formatter = decimalFormatter(locale: locale)
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func parse(_ text: String, locale: Locale = .current) -> Double? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty, hasValidSignPlacement(trimmedText) else { return nil }
        let parseText = trimmedText.first == "+" ? String(trimmedText.dropFirst()) : trimmedText

        // A single comma followed by a non-grouping-width fraction is an
        // unambiguous decimal comma even when the current locale uses dots.
        let commaParts = parseText.split(separator: ",", omittingEmptySubsequences: false)
        if commaParts.count == 2,
           !parseText.contains("."),
           (1...2).contains(commaParts[1].count),
           hasOnlyDigitsAfterOptionalSign(commaParts[0]),
           commaParts[1].allSatisfy(\.isNumber),
           let commaDecimal = decimalFormatter(locale: invariantLocale)
            .number(from: parseText.replacingOccurrences(of: ",", with: "."))?
            .doubleValue {
            return commaDecimal
        }

        if let localizedValue = decimalFormatter(locale: locale).number(from: parseText)?.doubleValue {
            return localizedValue
        }

        // Tune data and pasted values can still contain invariant decimal dots,
        // even when the device locale uses a different decimal separator.
        guard locale.identifier != invariantLocale.identifier else { return nil }
        return decimalFormatter(locale: invariantLocale).number(from: parseText)?.doubleValue
    }

    private static let invariantLocale = Locale(identifier: "en_US_POSIX")

    private static func hasValidSignPlacement(_ text: String) -> Bool {
        let signs = text.enumerated().filter { $0.element == "+" || $0.element == "-" }
        guard signs.count <= 1 else { return false }
        guard let sign = signs.first else { return true }
        return sign.offset == 0 && text.count > 1
    }

    private static func hasOnlyDigitsAfterOptionalSign(_ text: Substring) -> Bool {
        let digits = if text.first == "+" || text.first == "-" {
            text.dropFirst()
        } else {
            text[...]
        }
        return !digits.isEmpty && digits.allSatisfy(\.isNumber)
    }

    private static func decimalFormatter(locale: Locale) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.isLenient = false
        return formatter
    }
}
