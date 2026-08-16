import Foundation

struct LegacyValidationBlobCompatibility {
    private let factory = FirstPartyValidationRecordFactory()

    func encodeReusableRecords(
        _ records: [FirstPartyValidationRecord]
    ) throws -> Data? {
        guard records.allSatisfy({
            $0.deidentifiedReusePermitted && factory.isValid($0)
        }) else {
            throw FirstPartyValidationError.invalidStoredRecord
        }
        guard !records.isEmpty else { return nil }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(records)
    }

    func decodeAsOlderBinary(_ data: Data?)
        -> [FirstPartyValidationRecord]? {
        guard let data else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let records = try? decoder.decode(
            [FirstPartyValidationRecord].self,
            from: data
        ), records.allSatisfy({
            $0.deidentifiedReusePermitted && factory.isValid($0)
        }) else { return nil }
        return records
    }
}
