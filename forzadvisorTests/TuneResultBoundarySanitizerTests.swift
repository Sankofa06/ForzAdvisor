//
//  TuneResultBoundarySanitizerTests.swift
//  forzadvisorTests
//
//  Regression coverage for legacy saved-result presentation and persistence
//  boundaries.
//

import SwiftData
import XCTest
@testable import forzadvisor

@MainActor
final class TuneResultBoundarySanitizerTests: XCTestCase {
    func testLegacyFH5MissingPurposeSanitizesAndPersistsAsPlanOnly() throws {
        let sentinel = "fh5-legacy-sentinel-419.731"
        let rulesetID = "legacy.fh5.numeric"
        let legacy = try decodedLegacyTune(
            fixture(game: .fh5, purpose: .numericTune, sentinel: sentinel, rulesetID: rulesetID),
            removingPurpose: true
        )

        XCTAssertEqual(legacy.purpose, .numericTune)
        XCTAssertNil(legacy.projectionReport)
        XCTAssertTrue(legacy.sections.flatMap(\.lines).contains { $0.value == sentinel })

        let container = try makeContainer()
        let writeContext = ModelContext(container)
        writeContext.insert(try SavedTune(tune: legacy))
        try writeContext.save()

        let reopenContext = ModelContext(container)
        let storedLegacy = try XCTUnwrap(
            reopenContext.fetch(FetchDescriptor<SavedTune>()).first
        )
        let sanitized = TuneResultBoundarySanitizer().sanitize(
            try XCTUnwrap(storedLegacy.tuneResult)
        )

        assertFH5PlanOnly(sanitized, sentinel: sentinel, rulesetID: rulesetID)
        assertCopilotPurpose(.fh5BuildPlan, tune: sanitized)

        try storedLegacy.update(with: sanitized)
        try reopenContext.save()

        let secondReopenContext = ModelContext(container)
        let reopened = try XCTUnwrap(
            secondReopenContext.fetch(FetchDescriptor<SavedTune>()).first?.tuneResult
        )
        assertFH5PlanOnly(reopened, sentinel: sentinel, rulesetID: rulesetID)
        assertCopilotPurpose(.fh5BuildPlan, tune: reopened)
    }

    func testFH6PlanPurposeMismatchSanitizesAndPersistsAsNumericWithoutCandidateData() throws {
        let sentinel = "fh6-mismatch-sentinel-876.543"
        let rulesetID = "legacy.fh6.plan-mismatch"
        let decoded = try decodedLegacyTune(
            fixture(game: .fh6, purpose: .fh5BuildPlan, sentinel: sentinel, rulesetID: rulesetID)
        )
        XCTAssertNil(decoded.projectionReport)

        let storedMismatch = try persistAndReopen(decoded)
        XCTAssertEqual(storedMismatch.purpose, .fh5BuildPlan)
        XCTAssertNil(storedMismatch.projectionReport)
        let sanitized = TuneResultBoundarySanitizer().sanitize(storedMismatch)
        XCTAssertEqual(sanitized.request.car.game, .fh6)
        XCTAssertEqual(sanitized.purpose, .numericTune)
        XCTAssertTrue(sanitized.sections.isEmpty)
        XCTAssertNil(sanitized.providerInfo)
        XCTAssertNil(sanitized.rulesetReference)
        XCTAssertEqual(sanitized.projectionReport?.readyCount, 0)
        XCTAssertFalse(sanitized.projectionReport?.fields.contains { $0.status == .ready } ?? true)
        assertEncoded(sanitized, excludes: [sentinel, rulesetID, "anthropicAPI"])
        assertCopilotPurpose(.numericTune, tune: sanitized)

        let sanitizedReopen = try persistAndReopen(sanitized)
        XCTAssertEqual(sanitizedReopen, sanitized)
        assertCopilotPurpose(.numericTune, tune: sanitizedReopen)
    }

    func testValidLegacyFH6NumericNilReportRemainsStructAndByteEquivalent() throws {
        let sentinel = "fh6-valid-legacy-271.828"
        let rulesetID = "legacy.fh6.numeric"
        let decoded = try decodedLegacyTune(
            fixture(game: .fh6, purpose: .numericTune, sentinel: sentinel, rulesetID: rulesetID),
            removingPurpose: true
        )
        XCTAssertEqual(decoded.purpose, .numericTune)
        XCTAssertNil(decoded.projectionReport)

        let before = try canonicalData(decoded)
        let sanitized = TuneResultBoundarySanitizer().sanitize(decoded)

        XCTAssertEqual(sanitized, decoded)
        XCTAssertEqual(try canonicalData(sanitized), before)
        XCTAssertTrue(sanitized.sections.flatMap(\.lines).contains { $0.value == sentinel })
        XCTAssertEqual(sanitized.providerInfo, .direct(.anthropicAPI))
        XCTAssertEqual(sanitized.rulesetReference?.id, rulesetID)
        XCTAssertNil(sanitized.projectionReport)

        let reopened = try persistAndReopen(decoded)
        let reopenedSanitized = TuneResultBoundarySanitizer().sanitize(reopened)
        XCTAssertEqual(reopenedSanitized, decoded)
        XCTAssertEqual(try canonicalData(reopenedSanitized), before)
    }

    private func fixture(
        game: ForzaGame,
        purpose: TuneResultPurpose,
        sentinel: String,
        rulesetID: String
    ) throws -> TuneResult {
        var car = SampleTuningData.starterCar
        car.game = game
        if game == .fh5 {
            car.performanceIndex = 850
        }
        let ruleset = try XCTUnwrap(TuneRulesetReference(descriptor: TuneRulesetDescriptor(
            id: rulesetID,
            game: game,
            schemaVersion: 1,
            algorithmVersion: "legacy",
            knowledgeRevision: "legacy",
            validationStatus: .validated,
            provenanceIDs: ["legacy-test"]
        )))
        return TuneResult(
            request: TuneRequest(car: car, discipline: .road),
            sections: [TuneSection(
                title: "Legacy candidate",
                symbolName: "exclamationmark.triangle",
                lines: [TuneLine(
                    label: "Legacy value",
                    value: sentinel,
                    unit: "",
                    detail: "must not cross a mismatched boundary",
                    fieldID: .frontARB
                )]
            )],
            notes: TuneNotes(
                bias: "Legacy bias",
                ifPushesWide: "Legacy understeer note",
                ifSnapsOnLift: "Legacy oversteer note",
                retuneTrigger: "Legacy retune note"
            ),
            generatedAt: Date(timeIntervalSince1970: 1_750_000_000),
            purpose: purpose,
            providerInfo: .direct(.anthropicAPI),
            rulesetReference: ruleset,
            projectionReport: nil
        )
    }

    private func decodedLegacyTune(
        _ tune: TuneResult,
        removingPurpose: Bool = false
    ) throws -> TuneResult {
        let encoded = try JSONEncoder().encode(tune)
        guard removingPurpose else {
            return try JSONDecoder().decode(TuneResult.self, from: encoded)
        }
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "purpose")
        return try JSONDecoder().decode(
            TuneResult.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
    }

    private func assertFH5PlanOnly(
        _ tune: TuneResult,
        sentinel: String,
        rulesetID: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(tune.request.car.game, .fh5, file: file, line: line)
        XCTAssertEqual(tune.purpose, .fh5BuildPlan, file: file, line: line)
        XCTAssertTrue(tune.sections.isEmpty, file: file, line: line)
        XCTAssertNil(tune.providerInfo, file: file, line: line)
        XCTAssertNil(tune.rulesetReference, file: file, line: line)
        XCTAssertEqual(tune.projectionReport?.readyCount, 0, file: file, line: line)
        XCTAssertFalse(
            tune.projectionReport?.fields.contains { $0.status == .ready } ?? true,
            file: file,
            line: line
        )
        assertEncoded(tune, excludes: [sentinel, rulesetID, "anthropicAPI"], file: file, line: line)
    }

    private func assertCopilotPurpose(
        _ purpose: TuneResultPurpose,
        tune: TuneResult,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let context = CopilotContextFactory().make(
            step: .result(
                tune,
                savedTuneID: tune.id,
                adjustmentChanges: [],
                thumbnailData: nil,
                playerNotes: ""
            ),
            savedTuneCount: 1,
            catalogCarCount: 0
        )
        XCTAssertEqual(context.projection?.resultPurpose, purpose, file: file, line: line)
        XCTAssertEqual(
            context.facts.first { $0.label == "Result type" }?.value,
            purpose == .fh5BuildPlan ? "FH5 build plan" : "Numeric tune",
            file: file,
            line: line
        )
    }

    private func assertEncoded(
        _ tune: TuneResult,
        excludes values: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            let encoded = try JSONEncoder().encode(tune)
            for value in values {
                XCTAssertNil(
                    encoded.range(of: Data(value.utf8)),
                    "Encoded tune leaked \(value).",
                    file: file,
                    line: line
                )
            }
        } catch {
            XCTFail("Could not encode sanitized tune: \(error)", file: file, line: line)
        }
    }

    private func persistAndReopen(_ tune: TuneResult) throws -> TuneResult {
        let container = try makeContainer()
        let writeContext = ModelContext(container)
        writeContext.insert(try SavedTune(tune: tune))
        try writeContext.save()

        let reopenContext = ModelContext(container)
        return try XCTUnwrap(
            reopenContext.fetch(FetchDescriptor<SavedTune>()).first?.tuneResult
        )
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: SavedTune.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func canonicalData(_ tune: TuneResult) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(tune)
    }
}
