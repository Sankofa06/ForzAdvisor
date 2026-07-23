//
//  FH5BuildPlanTests.swift
//  forzadvisorTests
//
//  End-to-end contracts for the bounded FH5 plan-only workflow.
//

import SwiftData
import XCTest
@testable import forzadvisor

final class FH5BuildPlanTests: XCTestCase {
    func testEligibleCatalogRequestRoutesBeforeEveryProviderMode() async throws {
        let request = try catalogRequest()

        for mode in TuneProviderMode.allCases {
            let calls = ProviderCallCounter()
            let provider = CapabilityProjectingTuneProvider(base: CompositeTuneProvider(
                configuration: TuneProviderConfiguration(mode: mode),
                remoteProvider: TuneAPIClient(
                    keychainStore: CountingAPIKeyStore(calls: calls),
                    session: CountingURLSession(calls: calls)
                ),
                onDeviceProvider: CountingOnDeviceProvider(calls: calls),
                localProvider: CountingTuneProvider(calls: calls)
            ))

            let tune = try await provider.generateTune(for: request)

            XCTAssertEqual(tune.purpose, .fh5BuildPlan)
            XCTAssertEqual(tune.request, request)
            XCTAssertTrue(tune.sections.isEmpty)
            XCTAssertNil(tune.rulesetReference)
            XCTAssertNil(tune.providerInfo)
            XCTAssertEqual(tune.projectionReport?.readyCount, 0)
            XCTAssertEqual(calls.localGenerate, 0)
            XCTAssertEqual(calls.onDeviceAvailability, 0)
            XCTAssertEqual(calls.onDeviceGenerate, 0)
            XCTAssertEqual(calls.keyReads, 0)
            XCTAssertEqual(calls.networkRequests, 0)
        }
    }

    func testFH5RouteFailsClosedForEveryUntrustedRequestShape() async throws {
        let valid = try catalogRequest()
        var requests: [TuneRequest] = []

        var missingSnapshot = valid
        missingSnapshot.buildSnapshot = nil
        requests.append(missingSnapshot)

        var manualCar = valid.car
        manualCar.catalogReference = nil
        requests.append(TuneRequest(
            car: manualCar,
            discipline: valid.discipline,
            buildSnapshot: valid.buildSnapshot
        ))

        var edited = valid
        edited.car.weightPounds += 1
        requests.append(edited)

        var mismatched = valid
        mismatched.buildSnapshot?.car.model = "Different model"
        requests.append(mismatched)

        var invalid = valid
        invalid.buildSnapshot?.schemaVersion = VehicleBuildSnapshot.currentSchemaVersion + 1
        requests.append(invalid)

        var exact = valid
        exact.buildSnapshot?.kind = .exactBuildObservation
        requests.append(exact)

        for mode in TuneProviderMode.allCases {
            for request in requests {
                let calls = ProviderCallCounter()
                let provider = CompositeTuneProvider(
                    configuration: TuneProviderConfiguration(mode: mode),
                    remoteProvider: TuneAPIClient(
                        keychainStore: CountingAPIKeyStore(calls: calls),
                        session: CountingURLSession(calls: calls)
                    ),
                    onDeviceProvider: CountingOnDeviceProvider(calls: calls),
                    localProvider: CountingTuneProvider(calls: calls)
                )

                do {
                    _ = try await provider.generateTune(for: request)
                    XCTFail("Expected unsupported FH5 request for \(mode.rawValue).")
                } catch let error as LocalTuneProviderError {
                    XCTAssertEqual(error, .unsupportedRuleset(.fh5))
                }

                XCTAssertEqual(calls.total, 0)
            }
        }
    }

    func testVerifiedUpgradeCaptureRebuildsSamePlanWithThreePaths() async throws {
        let initial = try await plan(for: catalogRequest())
        let snapshot = try XCTUnwrap(UpgradePartCaptureEligibility().snapshot(for: initial))
        XCTAssertTrue(TuneControlUpgradePlanner().paths(for: initial).isEmpty)
        XCTAssertNil(TuneClipboardFormatter.verifiedSettingsText(for: initial))

        let capture = UpgradePartCapture(
            gameBuildVersion: "fh5-test-build",
            parts: TunePartID.allCases.map {
                UpgradePartCaptureValue(partID: $0, status: .offered)
            },
            exactStockBuildConfirmed: true,
            localUsePermitted: true
        )
        let verifiedSnapshot = try capture.verifiedSnapshot(upgrading: snapshot)
        let rebuiltRequest = TuneRequest(
            car: initial.request.car,
            discipline: initial.request.discipline,
            buildSnapshot: verifiedSnapshot
        )
        let rebuilt = try await plan(for: rebuiltRequest)
        let paths = TuneControlUpgradePlanner().paths(for: rebuilt)

        XCTAssertEqual(rebuilt.purpose, .fh5BuildPlan)
        XCTAssertEqual(rebuilt.request.car, initial.request.car)
        XCTAssertEqual(rebuilt.request.discipline, initial.request.discipline)
        XCTAssertEqual(rebuilt.projectionReport?.readyCount, 0)
        XCTAssertTrue(rebuilt.sections.isEmpty)
        XCTAssertEqual(paths.count, 3)
        XCTAssertEqual(paths, TuneControlUpgradePlanner().paths(for: rebuilt))
        XCTAssertTrue(paths.allSatisfy { !$0.items.isEmpty })

        let clipboard = try XCTUnwrap(TuneClipboardFormatter.buildPlanText(for: rebuilt))
        XCTAssertTrue(clipboard.contains("FH5 local build plan"))
        XCTAssertTrue(clipboard.contains("plan was rebuilt"))
        XCTAssertTrue(clipboard.contains("Path 1"))
        XCTAssertTrue(clipboard.contains("Path 2"))
        XCTAssertTrue(clipboard.contains("Path 3"))
        XCTAssertFalse(clipboard.localizedCaseInsensitiveContains("regenerate tune"))
        XCTAssertNil(TuneClipboardFormatter.verifiedSettingsText(for: rebuilt))
    }

    func testVerifiedUnavailablePartsRebuildAsPlanWithoutInventingPaths() async throws {
        let initial = try await plan(for: catalogRequest())
        let snapshot = try XCTUnwrap(UpgradePartCaptureEligibility().snapshot(for: initial))
        let capture = UpgradePartCapture(
            gameBuildVersion: "fh5-unavailable-build",
            parts: TunePartID.allCases.map {
                UpgradePartCaptureValue(partID: $0, status: .notOffered)
            },
            exactStockBuildConfirmed: true,
            localUsePermitted: true
        )
        let verified = try capture.verifiedSnapshot(upgrading: snapshot)
        let rebuilt = try await plan(for: TuneRequest(
            car: initial.request.car,
            discipline: initial.request.discipline,
            buildSnapshot: verified
        ))

        XCTAssertEqual(rebuilt.purpose, .fh5BuildPlan)
        XCTAssertEqual(rebuilt.projectionReport?.readyCount, 0)
        XCTAssertTrue(rebuilt.sections.isEmpty)
        XCTAssertTrue(TuneControlUpgradePlanner().paths(for: rebuilt).isEmpty)
        XCTAssertNil(TuneClipboardFormatter.verifiedSettingsText(for: rebuilt))
    }

    @MainActor
    func testSaveAndReopenPreservesPlanEvidencePathsAndClipboard() async throws {
        let initial = try await plan(for: catalogRequest())
        let snapshot = try XCTUnwrap(UpgradePartCaptureEligibility().snapshot(for: initial))
        let capture = UpgradePartCapture(
            gameBuildVersion: "fh5-persistence-build",
            parts: TunePartID.allCases.map {
                UpgradePartCaptureValue(partID: $0, status: .offered)
            },
            exactStockBuildConfirmed: true,
            localUsePermitted: true
        )
        let verified = try capture.verifiedSnapshot(upgrading: snapshot)
        let rebuilt = try await plan(for: TuneRequest(
            car: initial.request.car,
            discipline: initial.request.discipline,
            buildSnapshot: verified
        ))
        let expectedPaths = TuneControlUpgradePlanner().paths(for: rebuilt)
        let expectedClipboard = try XCTUnwrap(TuneClipboardFormatter.buildPlanText(for: rebuilt))
        let container = try ModelContainer(
            for: SavedTune.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        context.insert(try SavedTune(tune: rebuilt))
        try context.save()

        let reopened = try XCTUnwrap(
            context.fetch(FetchDescriptor<SavedTune>()).first?.tuneResult
        )

        XCTAssertEqual(reopened.request.car.game, .fh5)
        XCTAssertEqual(reopened.purpose, .fh5BuildPlan)
        XCTAssertEqual(reopened.request.buildSnapshot?.id, verified.id)
        XCTAssertEqual(reopened.request.buildSnapshot?.kind, verified.kind)
        XCTAssertEqual(reopened.request.buildSnapshot?.gameBuild.version, verified.gameBuild.version)
        XCTAssertEqual(reopened.request.buildSnapshot?.car, verified.car)
        XCTAssertEqual(reopened.request.buildSnapshot?.capabilityProfile, verified.capabilityProfile)
        XCTAssertEqual(reopened.request.buildSnapshot?.constraints, verified.constraints)
        XCTAssertEqual(reopened.request.buildSnapshot?.evidenceSources, verified.evidenceSources)
        XCTAssertEqual(reopened.projectionReport, rebuilt.projectionReport)
        XCTAssertEqual(TuneControlUpgradePlanner().paths(for: reopened), expectedPaths)
        XCTAssertEqual(TuneClipboardFormatter.buildPlanText(for: reopened), expectedClipboard)
    }

    func testPurposeIsExplicitlyCodableAndLegacyTuneDefaultsToNumeric() throws {
        let plan = TuneResult(
            request: try catalogRequest(),
            sections: [],
            notes: emptyNotes,
            purpose: .fh5BuildPlan
        )
        let planData = try JSONEncoder().encode(plan)
        XCTAssertEqual(
            try JSONDecoder().decode(TuneResult.self, from: planData).purpose,
            .fh5BuildPlan
        )

        let numeric = TuneResult(
            request: TuneRequest(car: SampleTuningData.starterCar, discipline: .road),
            sections: [],
            notes: emptyNotes
        )
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(numeric)) as? [String: Any]
        )
        object.removeValue(forKey: "purpose")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        XCTAssertEqual(
            try JSONDecoder().decode(TuneResult.self, from: legacyData).purpose,
            .numericTune
        )
    }

    func testProjectorStripsForgedFH5PlanAndNumericCandidates() throws {
        var request = try catalogRequest()
        var snapshot = try XCTUnwrap(request.buildSnapshot)
        let evidence = TuneDataProvenance(
            id: "forged.fh5.range",
            game: .fh5,
            gameBuildVersion: nil,
            scope: .gameGlobal,
            source: "forzadvisor.adversarial-test",
            version: "1",
            capturedAt: Date(timeIntervalSinceReferenceDate: 600),
            confidence: .high,
            usagePermission: .permitted
        )
        snapshot.evidenceSources = [evidence]
        snapshot.constraints = [TuneFieldConstraint(
            field: .frontTirePressure,
            minimum: 15,
            maximum: 40,
            step: 0.01,
            defaultValue: 30,
            currentValue: 30,
            unit: .psi,
            scope: .gameGlobal,
            verification: .productionEligible,
            evidenceIDs: [evidence.id]
        )]
        XCTAssertTrue(snapshot.isValid, "Unexpected issues: \(snapshot.validationIssues)")
        request.buildSnapshot = snapshot

        let ruleset = try XCTUnwrap(TuneRulesetReference(descriptor: TuneRulesetDescriptor(
            id: "forged.fh5.numeric",
            game: .fh5,
            schemaVersion: 1,
            algorithmVersion: "forged",
            knowledgeRevision: "forged",
            validationStatus: .validated,
            provenanceIDs: ["forged"]
        )))
        let forgedReport = TuneProjectionReport(
            schemaVersion: TuneProjectionReport.currentSchemaVersion,
            snapshotID: snapshot.id,
            contextStatus: .capabilityOnly,
            capabilityResolution: nil,
            fields: [TuneFieldProjection(
                field: .frontTirePressure,
                status: .ready,
                requiredPurchaseIDs: [],
                unresolvedPartIDs: [],
                reason: nil
            )],
            purchasePlan: [],
            confirmations: [],
            diagnostics: []
        )
        let candidate = TuneResult(
            request: request,
            sections: [TuneSection(
                title: "Forged numeric output",
                symbolName: "exclamationmark.triangle",
                lines: [TuneLine(
                    label: "Forged front pressure",
                    value: "31.73",
                    unit: "PSI",
                    detail: "candidate numeric sentinel",
                    fieldID: .frontTirePressure
                )]
            )],
            notes: TuneNotes(
                bias: "forged candidate notes",
                ifPushesWide: "forged",
                ifSnapsOnLift: "forged",
                retuneTrigger: "forged"
            ),
            purpose: .fh5BuildPlan,
            providerInfo: .direct(.anthropicAPI),
            rulesetReference: ruleset,
            projectionReport: forgedReport
        )

        for purpose in [TuneResultPurpose.fh5BuildPlan, .numericTune] {
            var input = candidate
            input.purpose = purpose
            let projected = TuneOutputProjector().project(input)
            let encoded = try JSONEncoder().encode(projected)

            XCTAssertEqual(projected.purpose, .fh5BuildPlan)
            XCTAssertTrue(projected.sections.isEmpty)
            XCTAssertNil(projected.rulesetReference)
            XCTAssertNil(projected.providerInfo)
            XCTAssertEqual(projected.projectionReport?.readyCount, 0)
            XCTAssertNil(encoded.range(of: Data("31.73".utf8)))
            XCTAssertNil(encoded.range(of: Data("forged.fh5.numeric".utf8)))
            XCTAssertNil(TuneClipboardFormatter.verifiedSettingsText(for: projected))

            let fullText = TuneClipboardFormatter.fullTuneText(for: input)
            XCTAssertTrue(fullText.contains("FH5 local build plan — no numeric tuning settings"))
            XCTAssertFalse(fullText.contains("31.73"))
            XCTAssertFalse(fullText.contains("Anthropic API"))
            XCTAssertFalse(fullText.contains("forged.fh5.numeric"))
        }
    }

    func testFH6PlanPurposeMismatchWithholdsAndUsesNonFH5Semantics() throws {
        let ruleset = try XCTUnwrap(TuneRulesetReference(descriptor: TuneRulesetDescriptor(
            id: "forged.fh6.mismatch",
            game: .fh6,
            schemaVersion: 1,
            algorithmVersion: "forged",
            knowledgeRevision: "forged",
            validationStatus: .validated,
            provenanceIDs: ["forged"]
        )))
        let candidate = TuneResult(
            request: TuneRequest(car: SampleTuningData.starterCar, discipline: .road),
            sections: [TuneSection(
                title: "Forged mismatch",
                symbolName: "exclamationmark.triangle",
                lines: [TuneLine(
                    label: "Forged value",
                    value: "876.543",
                    unit: "",
                    fieldID: .frontARB
                )]
            )],
            notes: TuneNotes(
                bias: "forged",
                ifPushesWide: "forged",
                ifSnapsOnLift: "forged",
                retuneTrigger: "forged"
            ),
            purpose: .fh5BuildPlan,
            providerInfo: .direct(.anthropicAPI),
            rulesetReference: ruleset
        )

        let projected = TuneOutputProjector().project(candidate)
        XCTAssertEqual(projected.request.car.game, .fh6)
        XCTAssertEqual(projected.purpose, .numericTune)
        XCTAssertTrue(projected.sections.isEmpty)
        XCTAssertNil(projected.providerInfo)
        XCTAssertNil(projected.rulesetReference)
        XCTAssertEqual(projected.projectionReport?.readyCount, 0)

        let fullText = TuneClipboardFormatter.fullTuneText(for: candidate)
        XCTAssertFalse(fullText.contains("876.543"))
        XCTAssertFalse(fullText.contains("Anthropic API"))
        XCTAssertFalse(fullText.contains("forged.fh6.mismatch"))
        XCTAssertFalse(fullText.contains("FH5"))
        XCTAssertFalse(fullText.localizedCaseInsensitiveContains("build plan"))
        XCTAssertTrue(fullText.contains("Provider: Provider not recorded"))

        let context = CopilotContextFactory().make(
            step: .result(
                projected,
                savedTuneID: nil,
                adjustmentChanges: [],
                thumbnailData: nil,
                playerNotes: ""
            ),
            savedTuneCount: 0,
            catalogCarCount: 0
        )
        XCTAssertEqual(context.projection?.resultPurpose, .numericTune)
        XCTAssertEqual(context.facts.first { $0.label == "Result type" }?.value, "Numeric tune")
        for intent in CopilotIntent.allCases {
            let message = CopilotEngine().response(to: intent, in: context).message
            XCTAssertFalse(message.contains("FH5"))
            XCTAssertFalse(message.localizedCaseInsensitiveContains("build plan"))
        }
    }

    func testPlanAdjustmentRemainsUnsupported() async throws {
        let result = try await plan(for: catalogRequest())
        let provider = CompositeTuneProvider(configuration: .offlineDefault)

        do {
            _ = try await provider.adjustTune(previous: result, adjustment: .moreRotation)
            XCTFail("Expected FH5 adjustment to remain unsupported.")
        } catch let error as LocalTuneProviderError {
            XCTAssertEqual(error, .unsupportedRuleset(.fh5))
        }
    }

    func testCopilotGuidanceIsPlanAwareBeforeAndAfterUpgradeVerification() async throws {
        let initial = try await plan(for: catalogRequest())
        let initialContext = CopilotContextFactory().make(
            step: .result(
                initial,
                savedTuneID: nil,
                adjustmentChanges: [],
                thumbnailData: nil,
                playerNotes: ""
            ),
            savedTuneCount: 0,
            catalogCarCount: 1
        )
        let engine = CopilotEngine()

        XCTAssertEqual(initialContext.projection?.resultPurpose, .fh5BuildPlan)
        XCTAssertTrue(
            engine.response(to: .nextStep, in: initialContext).message
                .contains("Open Upgrade Lab")
        )
        XCTAssertTrue(
            engine.response(to: .trust, in: initialContext).message
                .contains("not a verified numeric tune")
        )

        let snapshot = try XCTUnwrap(initial.request.buildSnapshot)
        let verified = try UpgradePartCapture(
            gameBuildVersion: "fh5-copilot-build",
            parts: TunePartID.allCases.map {
                UpgradePartCaptureValue(partID: $0, status: .offered)
            },
            exactStockBuildConfirmed: true,
            localUsePermitted: true
        ).verifiedSnapshot(upgrading: snapshot)
        let rebuilt = try await plan(for: TuneRequest(
            car: initial.request.car,
            discipline: initial.request.discipline,
            buildSnapshot: verified
        ))
        let rebuiltContext = CopilotContextFactory().make(
            step: .result(
                rebuilt,
                savedTuneID: nil,
                adjustmentChanges: [],
                thumbnailData: nil,
                playerNotes: ""
            ),
            savedTuneCount: 0,
            catalogCarCount: 1
        )

        XCTAssertEqual(rebuiltContext.projection?.exactUpgradePathCount, 3)
        XCTAssertTrue(
            engine.response(to: .nextStep, in: rebuiltContext).message
                .contains("Copy the FH5 build plan and save it")
        )
        XCTAssertTrue(
            engine.response(to: .missing, in: rebuiltContext).message
                .contains("No numeric FH5 settings are included")
        )
        XCTAssertFalse(
            engine.response(to: .trust, in: rebuiltContext).message
                .contains("verified tune")
        )
    }

    private func catalogRequest() throws -> TuneRequest {
        let catalog = try BundledCarCatalog.load().get()
        let entry = try XCTUnwrap(catalog.entries.first { $0.game == .fh5 })
        let selection = catalog.selection(for: entry)
        return TuneRequest(
            car: selection.carInput,
            discipline: .road,
            buildSnapshot: selection.capabilityOnlyBuildSnapshot(
                capturedAt: Date(timeIntervalSinceReferenceDate: 500)
            )
        )
    }

    private func plan(for request: TuneRequest) async throws -> TuneResult {
        try await CapabilityProjectingTuneProvider(base: CompositeTuneProvider())
            .generateTune(for: request)
    }

    private var emptyNotes: TuneNotes {
        TuneNotes(bias: "", ifPushesWide: "", ifSnapsOnLift: "", retuneTrigger: "")
    }
}

private final class ProviderCallCounter: @unchecked Sendable {
    var localGenerate = 0
    var onDeviceAvailability = 0
    var onDeviceGenerate = 0
    var keyReads = 0
    var networkRequests = 0

    var total: Int {
        localGenerate + onDeviceAvailability + onDeviceGenerate + keyReads + networkRequests
    }
}

private struct CountingTuneProvider: TuneProvider {
    let calls: ProviderCallCounter

    func generateTune(for request: TuneRequest) async throws -> TuneResult {
        calls.localGenerate += 1
        throw LocalTuneProviderError.unsupportedRuleset(request.car.game)
    }

    func adjustTune(previous tune: TuneResult, adjustment: TuneAdjustment) async throws -> TuneAdjustmentResult {
        throw LocalTuneProviderError.unsupportedRuleset(tune.request.car.game)
    }
}

private struct CountingOnDeviceProvider: OnDeviceTuneProviding {
    let calls: ProviderCallCounter

    var availability: OnDeviceModelAvailability {
        calls.onDeviceAvailability += 1
        return .available
    }

    func generateTune(for request: TuneRequest) async throws -> TuneResult {
        calls.onDeviceGenerate += 1
        throw CancellationError()
    }

    func adjustTune(previous tune: TuneResult, adjustment: TuneAdjustment) async throws -> TuneAdjustmentResult {
        throw CancellationError()
    }
}

private struct CountingAPIKeyStore: APIKeyStoring {
    let calls: ProviderCallCounter

    func readAPIKey() throws -> String? {
        calls.keyReads += 1
        return "configured-but-unused"
    }

    func saveAPIKey(_ key: String) throws {}
    func deleteAPIKey() throws {}
}

private struct CountingURLSession: URLSessionProtocol {
    let calls: ProviderCallCounter

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        calls.networkRequests += 1
        throw URLError(.cannotConnectToHost)
    }
}
