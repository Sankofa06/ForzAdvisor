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
        guard !trimmedText.isEmpty else { return nil }

        if let localizedValue = decimalFormatter(locale: locale).number(from: trimmedText)?.doubleValue {
            return localizedValue
        }

        // Tune data and pasted values can still contain invariant decimal dots,
        // even when the device locale uses a different decimal separator.
        guard locale.identifier != invariantLocale.identifier else { return nil }
        return decimalFormatter(locale: invariantLocale).number(from: trimmedText)?.doubleValue
    }

    private static let invariantLocale = Locale(identifier: "en_US_POSIX")

    private static func decimalFormatter(locale: Locale) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.isLenient = false
        return formatter
    }
}
