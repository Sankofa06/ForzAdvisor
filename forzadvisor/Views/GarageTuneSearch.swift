import Foundation

enum GarageSortOrder: String, CaseIterable {
    case recent = "Recently updated"
    case carName = "Car name"
}

enum GarageTuneSearch {
    /// Each word may match a different piece of metadata, such as "Mazda drift".
    static func matches(_ query: String, fields: [String]) -> Bool {
        let terms = query.split(whereSeparator: \.isWhitespace)
        let searchableText = fields.joined(separator: " ")
        return terms.allSatisfy { term in
            searchableText.range(
                of: String(term),
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            ) != nil
        }
    }
}
