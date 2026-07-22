//
//  CommunityTuneBenchmarkTests.swift
//  forzadvisorTests
//

import XCTest
@testable import forzadvisor

final class CommunityTuneBenchmarkTests: XCTestCase {
    func testBundledMetadataDocumentContainsNoNumericTuneValues() throws {
        let document = try CommunityTuneBenchmark.decode(bundledFixtureData())

        XCTAssertEqual(document.schemaVersion, 1)
        XCTAssertEqual(Set(document.fixtures.map(\.source.game)), [.fh5, .fh6])
        XCTAssertTrue(document.fixtures.allSatisfy { $0.source.usagePermission == .metadataOnly })
        XCTAssertTrue(document.fixtures.allSatisfy { $0.source.coverage == .opaque })
        XCTAssertTrue(document.fixtures.allSatisfy { $0.context == nil })
        XCTAssertTrue(document.fixtures.allSatisfy(\.fields.isEmpty))
        XCTAssertTrue(document.fixtures.allSatisfy { !$0.unknowns.isEmpty })
        XCTAssertTrue(document.validationIssues(mode: .bundledFixture).isEmpty)
    }

    func testSyntheticSchemaRoundTripsStableFieldsAndIndexedGears() throws {
        var fixture = makeFixture()
        fixture.fields = [
            observation(.frontTirePressure, value: 27),
            observation(.gearRatio(6), value: 0.82)
        ]
        let document = CommunityTuneBenchmarkDocument(schemaVersion: 1, fixtures: [fixture])

        let encoded = try CommunityTuneBenchmark.encoder().encode(document)
        let decoded = try CommunityTuneBenchmark.decode(encoded)

        XCTAssertEqual(decoded, document)
        XCTAssertEqual(decoded.fixtures[0].fields.map(\.id), [.frontTirePressure, .gearRatio(6)])
        XCTAssertEqual(decoded.fixtures[0].fields.map(\.id.benchmarkStableID), ["frontTirePressure", "gearRatio.6"])
    }

    func testDocumentValidationRejectsSchemaAndDuplicateFixtureAndSourceIDs() {
        let fixture = makeFixture()
        let document = CommunityTuneBenchmarkDocument(schemaVersion: 99, fixtures: [fixture, fixture])
        let codes = document.validationIssues(mode: .localResearch).map(\.code)

        XCTAssertTrue(codes.contains(.unsupportedSchema))
        XCTAssertTrue(codes.contains(.duplicateFixtureID))
        XCTAssertTrue(codes.contains(.duplicateSourceID))
    }

    func testSourceValidationRejectsBlankIdentityHTTPAndInvalidDualReview() {
        var fixture = makeFixture()
        fixture.id = " "
        fixture.source.id = ""
        fixture.source.publisher = " "
        fixture.source.url = "http://example.com/tune"
        fixture.source.contentFingerprint = ""
        fixture.source.extractionMethod = .manualDualReview
        fixture.source.reviewerIDs = ["same", "same"]
        let codes = CommunityTuneBenchmarkDocument(schemaVersion: 1, fixtures: [fixture])
            .validationIssues(mode: .localResearch)
            .map(\.code)

        XCTAssertTrue(codes.contains(.blankIdentifier))
        XCTAssertTrue(codes.contains(.invalidURL))
        XCTAssertTrue(codes.contains(.invalidSource))
    }

    func testPermissionValidationFailsClosedAndPublicAvailabilityNeverCommitsNumbers() {
        var fixture = makeFixture()

        fixture.source.usagePermission = .unknown
        var issues = CommunityTuneBenchmarkDocument(schemaVersion: 1, fixtures: [fixture])
            .validationIssues(mode: .localResearch)
        XCTAssertTrue(issues.contains { $0.code == .invalidPermission })
        XCTAssertTrue(issues.contains { $0.code == .numericValuesForbidden })

        fixture.source.usagePermission = .prohibited
        issues = CommunityTuneBenchmarkDocument(schemaVersion: 1, fixtures: [fixture])
            .validationIssues(mode: .localResearch)
        XCTAssertTrue(issues.contains { $0.code == .invalidPermission })

        fixture.source.usagePermission = .committedNumericBenchmark
        fixture.source.permissionBasis = .publicAvailability
        fixture.source.permissionEvidenceID = "web-link"
        issues = CommunityTuneBenchmarkDocument(schemaVersion: 1, fixtures: [fixture])
            .validationIssues(mode: .localResearch)
        XCTAssertTrue(issues.contains { $0.code == .invalidPermission })

        fixture.source.usagePermission = .metadataOnly
        fixture.source.permissionBasis = .unspecified
        issues = CommunityTuneBenchmarkDocument(schemaVersion: 1, fixtures: [fixture])
            .validationIssues(mode: .localResearch)
        XCTAssertTrue(issues.contains { $0.code == .numericValuesForbidden })
    }

    func testLocalResearchAndSyntheticPermissionsStayOutOfBundledFixtures() {
        var fixture = makeFixture()
        fixture.source.usagePermission = .localResearchOnly
        fixture.source.permissionBasis = .publicAvailability
        fixture.source.permissionEvidenceID = nil
        var document = CommunityTuneBenchmarkDocument(schemaVersion: 1, fixtures: [fixture])

        XCTAssertTrue(document.validationIssues(mode: .localResearch).isEmpty)
        XCTAssertTrue(document.validationIssues(mode: .bundledFixture).contains { $0.code == .invalidPermission })

        fixture.source.usagePermission = .committedNumericBenchmark
        fixture.source.permissionBasis = .syntheticTest
        fixture.source.permissionEvidenceID = "test-source"
        document.fixtures = [fixture]
        XCTAssertTrue(document.validationIssues(mode: .localResearch).isEmpty)
        XCTAssertTrue(document.validationIssues(mode: .bundledFixture).contains { $0.code == .invalidPermission })
    }

    func testCompatibleLicenseRequiresNamedHTTPSEvidence() {
        var fixture = makeFixture()
        fixture.source.permissionBasis = .compatibleLicense
        fixture.source.license = BenchmarkLicense(name: "", url: "http://example.com/license")
        var issues = CommunityTuneBenchmarkDocument(schemaVersion: 1, fixtures: [fixture])
            .validationIssues(mode: .localResearch)
        XCTAssertTrue(issues.contains { $0.code == .invalidPermission })

        fixture.source.license = BenchmarkLicense(name: "CC BY 4.0", url: "https://creativecommons.org/licenses/by/4.0/")
        issues = CommunityTuneBenchmarkDocument(schemaVersion: 1, fixtures: [fixture])
            .validationIssues(mode: .localResearch)
        XCTAssertFalse(issues.contains { $0.code == .invalidPermission })
    }

    func testFieldValidationRejectsDuplicatesUnitMismatchNonfiniteAndIllegalStates() {
        var fixture = makeFixture()
        fixture.fields = [
            observation(.frontTirePressure, value: .infinity),
            BenchmarkFieldObservation(
                id: .frontTirePressure,
                unit: .degrees,
                status: .notShown,
                value: 0,
                observedStep: -1,
                reason: nil,
                note: nil
            ),
            BenchmarkFieldObservation(
                id: .frontAero,
                unit: .pounds,
                status: .notApplicable,
                value: nil,
                observedStep: nil,
                reason: " ",
                note: nil
            ),
            BenchmarkFieldObservation(
                id: .rearToe,
                unit: .degrees,
                status: .ambiguous,
                value: nil,
                observedStep: nil,
                reason: nil,
                note: nil
            )
        ]
        let codes = CommunityTuneBenchmarkDocument(schemaVersion: 1, fixtures: [fixture])
            .validationIssues(mode: .localResearch)
            .map(\.code)

        XCTAssertTrue(codes.contains(.duplicateFieldID))
        XCTAssertTrue(codes.contains(.unitMismatch))
        XCTAssertTrue(codes.contains(.nonFiniteValue))
        XCTAssertTrue(codes.contains(.illegalFieldState))
        XCTAssertTrue(codes.contains(.missingReason))
    }

    func testContextValidationRejectsIdentityClassBuildPartsAndUnknownErrors() {
        var fixture = makeFixture()
        fixture.context?.car.catalogID = ""
        fixture.context?.performanceClass = .r
        fixture.context?.performanceIndex = 800
        fixture.context?.build.weightPounds = 100
        fixture.context?.build.gearCount = 11
        let duplicatedPart = fixture.context!.build.parts[0]
        fixture.context?.build.parts.append(duplicatedPart)
        fixture.context?.build.partsFingerprint = "stale"
        fixture.unknowns = [.init(path: "", reason: "", note: nil)]
        let codes = CommunityTuneBenchmarkDocument(schemaVersion: 1, fixtures: [fixture])
            .validationIssues(mode: .localResearch)
            .map(\.code)

        XCTAssertTrue(codes.contains(.invalidCarIdentity))
        XCTAssertTrue(codes.contains(.invalidClassPI))
        XCTAssertTrue(codes.contains(.invalidBuild))
        XCTAssertTrue(codes.contains(.invalidParts))
        XCTAssertTrue(codes.contains(.invalidUnknown))
    }

    func testNumericFixtureRequiresContextAndSourceGameMustMatch() {
        var fixture = makeFixture()
        fixture.context = nil
        var issues = CommunityTuneBenchmarkDocument(schemaVersion: 1, fixtures: [fixture])
            .validationIssues(mode: .localResearch)
        XCTAssertTrue(issues.contains { $0.code == .missingContext })

        fixture = makeFixture()
        fixture.source.game = .fh5
        issues = CommunityTuneBenchmarkDocument(schemaVersion: 1, fixtures: [fixture])
            .validationIssues(mode: .localResearch)
        XCTAssertTrue(issues.contains { $0.code == .invalidSource })
    }

    func testExactCohortRequiresEveryBuildFingerprintInput() {
        var fixture = makeFixture()
        XCTAssertEqual(fixture.cohortIdentity.classification, .exact)

        fixture.source.gameVersion = nil
        XCTAssertEqual(fixture.cohortIdentity.classification, .exploratory)

        fixture = makeFixture()
        fixture.context?.build.partsCoverage = .partial
        XCTAssertEqual(fixture.cohortIdentity.classification, .exploratory)

        fixture = makeFixture()
        fixture.unknowns = [.init(path: "context.build.parts", reason: "Not shown", note: nil)]
        XCTAssertEqual(fixture.cohortIdentity.classification, .exploratory)

        fixture = makeFixture()
        fixture.context?.build.peakHorsepower = nil
        XCTAssertEqual(fixture.cohortIdentity.classification, .exploratory)
    }

    func testCompletePartsCoverageRequiresNonemptyInventoryAndFingerprint() {
        var fixture = makeFixture()
        fixture.context?.build.parts = []
        fixture.context?.build.partsFingerprint = ""

        let issues = CommunityTuneBenchmarkDocument(schemaVersion: 1, fixtures: [fixture])
            .validationIssues(mode: .localResearch)

        XCTAssertTrue(issues.contains { $0.code == .invalidParts && $0.path.hasSuffix(".build.parts") })
        XCTAssertEqual(fixture.cohortIdentity.classification, .exploratory)
    }

    func testExactCohortRejectsBlankPartKeysAndSourceLabels() {
        var blankKey = makeFixture()
        var blankKeyBuild = blankKey.context!.build
        blankKeyBuild.parts[0].normalizedKey = " "
        blankKeyBuild.partsFingerprint = blankKeyBuild.canonicalPartsFingerprint
        blankKey.context?.build = blankKeyBuild

        var blankLabel = makeFixture()
        blankLabel.context?.build.parts[0].sourceLabel = " "

        for fixture in [blankKey, blankLabel] {
            let issues = CommunityTuneBenchmarkDocument(schemaVersion: 1, fixtures: [fixture])
                .validationIssues(mode: .localResearch)

            XCTAssertTrue(issues.contains { $0.code == .invalidParts })
            XCTAssertEqual(fixture.cohortIdentity.classification, .exploratory)
        }
    }

    func testExactCohortRejectsDuplicatePartKeysWithMatchingFingerprint() {
        var fixture = makeFixture()
        var build = fixture.context!.build
        build.parts.append(build.parts[0])
        build.partsFingerprint = build.canonicalPartsFingerprint
        fixture.context?.build = build

        let issues = CommunityTuneBenchmarkDocument(schemaVersion: 1, fixtures: [fixture])
            .validationIssues(mode: .localResearch)

        XCTAssertTrue(issues.contains { $0.code == .invalidParts })
        XCTAssertEqual(fixture.cohortIdentity.classification, .exploratory)
    }

    func testConsensusRequiresIndependentNonderivativePublishers() {
        let first = makeFixture(id: "one", sourceID: "source.one", publisher: "One")
        let second = makeFixture(id: "two", sourceID: "source.two", publisher: "Two")
        var third = makeFixture(id: "three", sourceID: "source.three", publisher: "Three")

        var report = CommunityTuneBenchmark.cohortReports(for: [first, second])
        XCTAssertEqual(report.count, 1)
        XCTAssertEqual(report[0].independentSourceCount, 2)
        XCTAssertEqual(report[0].consensusLabel, .pairwiseAgreement)

        report = CommunityTuneBenchmark.cohortReports(for: [third, second, first])
        XCTAssertEqual(report[0].independentSourceCount, 3)
        XCTAssertEqual(report[0].consensusLabel, .communityCenter)
        XCTAssertEqual(report[0].fixtureIDs, ["one", "three", "two"])

        third.source.derivativeOfSourceID = first.source.id
        report = CommunityTuneBenchmark.cohortReports(for: [first, second, third])
        XCTAssertEqual(report[0].independentSourceCount, 2)
        XCTAssertEqual(report[0].consensusLabel, .pairwiseAgreement)
    }

    func testCohortStatisticsUseOneDeterministicIndependentRepresentativeSet() throws {
        var first = makeFixture(id: "01-first", sourceID: "source.01", publisher: "One")
        first.fields = [observation(.frontTirePressure, value: 10)]
        var second = makeFixture(id: "02-second", sourceID: "source.02", publisher: "Two")
        second.fields = [observation(.frontTirePressure, value: 20)]
        var third = makeFixture(id: "03-third", sourceID: "source.03", publisher: "Three")
        third.fields = [observation(.frontTirePressure, value: 30)]

        var derivative = makeFixture(id: "04-derivative", sourceID: "source.04", publisher: "Four")
        derivative.source.derivativeOfSourceID = first.source.id
        derivative.fields = [observation(.frontTirePressure, value: 10_000)]

        var duplicatePublisher = makeFixture(id: "05-duplicate-publisher", sourceID: "source.05", publisher: " ONE ")
        duplicatePublisher.fields = [observation(.frontTirePressure, value: -10_000)]

        var duplicateContent = makeFixture(id: "06-duplicate-content", sourceID: "source.06", publisher: "Six")
        duplicateContent.source.contentFingerprint = second.source.contentFingerprint
        duplicateContent.fields = [observation(.frontTirePressure, value: 20_000)]

        var noObservations = makeFixture(id: "07-no-observations", sourceID: "source.07", publisher: "Seven")
        noObservations.fields = []

        let fixtures = [
            first,
            second,
            third,
            derivative,
            duplicatePublisher,
            duplicateContent,
            noObservations
        ]
        let forward = CommunityTuneBenchmark.cohortReports(for: fixtures)
        let reverse = CommunityTuneBenchmark.cohortReports(for: Array(fixtures.reversed()))
        let report = try XCTUnwrap(forward.first)
        let distribution = try XCTUnwrap(report.distributions.first { $0.field == .frontTirePressure })

        XCTAssertEqual(forward, reverse)
        XCTAssertEqual(report.independentSourceCount, 3)
        XCTAssertEqual(report.consensusLabel, .communityCenter)
        XCTAssertEqual(distribution.sampleCount, 3)
        XCTAssertEqual(distribution.median, 20)
        XCTAssertEqual(distribution.minimum, 10)
        XCTAssertEqual(distribution.maximum, 30)

        let pairwiseFixtures = fixtures.filter { $0.id != third.id }
        let pairwiseReport = try XCTUnwrap(CommunityTuneBenchmark.cohortReports(for: pairwiseFixtures).first)
        let pairwiseDistribution = try XCTUnwrap(
            pairwiseReport.distributions.first { $0.field == .frontTirePressure }
        )
        XCTAssertEqual(pairwiseReport.independentSourceCount, 2)
        XCTAssertEqual(pairwiseReport.consensusLabel, .pairwiseAgreement)
        XCTAssertEqual(pairwiseDistribution.sampleCount, 2)
        XCTAssertEqual(pairwiseDistribution.median, 15)
        XCTAssertEqual(pairwiseDistribution.minimum, 10)
        XCTAssertEqual(pairwiseDistribution.maximum, 20)
    }

    func testComparisonUsesObservedStepAndTreatsOutsideBandAsData() throws {
        var fixture = makeFixture()
        fixture.fields = [
            observation(.frontTirePressure, value: 25, step: 0.5),
            observation(.frontSpringRate, value: 500)
        ]
        let candidate = BenchmarkCandidate(
            status: .supported,
            values: [
                .init(field: .frontTirePressure, value: 26),
                .init(field: .frontSpringRate, value: 530)
            ],
            diagnostics: []
        )

        let comparisons = CommunityTuneBenchmark.compare(candidate: candidate, fixture: fixture)
        let tire = try XCTUnwrap(comparisons.first { $0.field == .frontTirePressure })
        XCTAssertEqual(tire.status, .outsideBand)
        XCTAssertEqual(tire.signedDelta, 1)
        XCTAssertEqual(tire.absoluteDelta, 1)
        XCTAssertEqual(tire.tolerance, 0.5)
        XCTAssertEqual(tire.bandDistance, 2)
        XCTAssertEqual(tire.stepDistance, 2)
        XCTAssertEqual(tire.relativePercentDelta, 4)

        let spring = try XCTUnwrap(comparisons.first { $0.field == .frontSpringRate })
        XCTAssertEqual(spring.tolerance, 25)
        XCTAssertEqual(spring.status, .outsideBand)
    }

    func testUnknownNotApplicableAndMissingCandidateAreNeverImputed() throws {
        var fixture = makeFixture()
        fixture.fields = [
            BenchmarkFieldObservation(id: .frontToe, unit: .degrees, status: .notShown, value: nil, observedStep: nil, reason: nil, note: nil),
            BenchmarkFieldObservation(id: .rearToe, unit: .degrees, status: .ambiguous, value: nil, observedStep: nil, reason: nil, note: "Two screens disagree."),
            BenchmarkFieldObservation(id: .frontAero, unit: .pounds, status: .notApplicable, value: nil, observedStep: nil, reason: "No adjustable aero.", note: nil),
            observation(.rearAero, value: 120)
        ]
        let comparisons = CommunityTuneBenchmark.compare(
            candidate: .init(status: .supported, values: [], diagnostics: []),
            fixture: fixture
        )

        XCTAssertEqual(comparisons.first { $0.field == .frontToe }?.status, .referenceUnknown)
        XCTAssertEqual(comparisons.first { $0.field == .rearToe }?.status, .referenceUnknown)
        XCTAssertEqual(comparisons.first { $0.field == .frontAero }?.status, .notApplicable)
        let missing = try XCTUnwrap(comparisons.first { $0.field == .rearAero })
        XCTAssertEqual(missing.status, .candidateMissing)
        XCTAssertNil(missing.candidate)
        XCTAssertEqual(missing.reference, 120)
    }

    func testGroupedMetricsCoverBalanceFamiliesAndUndefinedDenominators() throws {
        var fixture = makeFixture()
        let values: [(TuneFieldID, Double)] = [
            (.frontTirePressure, 30), (.rearTirePressure, 20),
            (.frontARB, 40), (.rearARB, 60),
            (.frontSpringRate, 600), (.rearSpringRate, 400),
            (.frontRebound, 10), (.rearRebound, 8),
            (.frontBump, 4), (.rearBump, 2),
            (.frontRideHeight, 4.5), (.rearRideHeight, 5),
            (.frontCamber, -2), (.rearCamber, -1),
            (.frontToe, 0.1), (.rearToe, 0),
            (.frontAero, 0), (.rearAero, 0),
            (.differentialAcceleration, 60), (.differentialDeceleration, 20),
            (.frontDifferentialAcceleration, 20), (.frontDifferentialDeceleration, 10),
            (.rearDifferentialAcceleration, 60), (.rearDifferentialDeceleration, 20),
            (.differentialCenterBalance, 70),
            (.gearRatio(1), 3), (.gearRatio(2), 2), (.gearRatio(3), 1)
        ]
        fixture.fields = values.map { observation($0.0, value: $0.1) }
        let candidate = BenchmarkCandidate(
            status: .supported,
            values: values.map { .init(field: $0.0, value: $0.1) },
            diagnostics: []
        )
        let metrics = CommunityTuneBenchmark.groupedMetrics(candidate: candidate, fixture: fixture)

        XCTAssertEqual(metric("tires.frontMinusRear", in: metrics)?.candidate, 10)
        XCTAssertEqual(metric("tires.frontShare", in: metrics)?.candidate ?? 0, 0.6, accuracy: 0.0001)
        XCTAssertEqual(metric("antirollBars.frontShare", in: metrics)?.candidate ?? 0, 0.4, accuracy: 0.0001)
        XCTAssertEqual(metric("springs.frontWeightResidual", in: metrics)?.candidate ?? 0, 0.07, accuracy: 0.0001)
        XCTAssertEqual(metric("damping.frontBumpReboundRatio", in: metrics)?.candidate ?? 0, 0.4, accuracy: 0.0001)
        XCTAssertEqual(metric("rideHeight.rearMinusFront", in: metrics)?.candidate, 0.5)
        XCTAssertEqual(metric("alignment.camberFrontMinusRear", in: metrics)?.candidate, -1)
        XCTAssertEqual(metric("differential.singleAxleSpread", in: metrics)?.candidate, 40)
        XCTAssertEqual(metric("differential.accelerationFrontShare", in: metrics)?.candidate ?? 0, 0.25, accuracy: 0.0001)
        XCTAssertEqual(metric("differential.centerRear", in: metrics)?.candidate, 70)
        XCTAssertEqual(metric("gearing.spacing.1-2", in: metrics)?.candidate ?? 0, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(metric("gearing.spacing.3-4", in: metrics)?.status, .unavailable)
        XCTAssertEqual(metric("aero.frontShare", in: metrics)?.status, .unavailable)
    }

    func testFH5CandidateReturnsUnsupportedWithoutValues() async {
        let fixture = makeFixture(game: .fh5)
        let candidate = await RawLocalBenchmarkCandidateAdapter.candidate(for: fixture)

        XCTAssertEqual(candidate.status, .unsupportedRuleset)
        XCTAssertTrue(candidate.values.isEmpty)
        XCTAssertEqual(candidate.diagnostics.count, 1)
    }

    func testFH5FullRunReturnsUnsupportedWithoutComparisonsOrGroupedMetrics() async throws {
        let fixture = makeFixture(game: .fh5)
        let document = CommunityTuneBenchmarkDocument(schemaVersion: 1, fixtures: [fixture])

        let report = try await CommunityTuneBenchmark.run(document: document, mode: .localResearch)
        let fixtureReport = try XCTUnwrap(report.fixtures.first)

        XCTAssertEqual(fixtureReport.candidate.status, .unsupportedRuleset)
        XCTAssertTrue(fixtureReport.candidate.values.isEmpty)
        XCTAssertTrue(fixtureReport.fieldComparisons.isEmpty)
        XCTAssertTrue(fixtureReport.groupedMetrics.isEmpty)
    }

    func testUnsupportedAndInvalidCandidatesNeverProduceComparisonMetrics() {
        let fixture = makeFixture()
        for status in [
            BenchmarkCandidateStatus.unsupportedRuleset,
            .notEvaluatedMetadataOnly,
            .invalidCandidate
        ] {
            let candidate = BenchmarkCandidate(
                status: status,
                values: [.init(field: .frontTirePressure, value: 27)],
                diagnostics: ["test"]
            )

            XCTAssertTrue(CommunityTuneBenchmark.compare(candidate: candidate, fixture: fixture).isEmpty)
            XCTAssertTrue(CommunityTuneBenchmark.groupedMetrics(candidate: candidate, fixture: fixture).isEmpty)
        }
    }

    func testFH6CandidateUsesUnprojectedLocalProviderValues() async throws {
        let fixture = makeFixture()
        let candidate = await RawLocalBenchmarkCandidateAdapter.candidate(for: fixture)

        XCTAssertEqual(candidate.status, .supported)
        XCTAssertEqual(candidate.values.count, 24)
        XCTAssertTrue(candidate.diagnostics.isEmpty)
        XCTAssertNotNil(candidate.valuesByField[.frontTirePressure])
        XCTAssertNotNil(candidate.valuesByField[.frontAero])
        XCTAssertNotNil(candidate.valuesByField[.differentialAcceleration])
    }

    func testLocalResearchHelperRunsWithoutAppChanges() async throws {
        var fixture = makeFixture()
        fixture.source.usagePermission = .localResearchOnly
        fixture.source.permissionBasis = .publicAvailability
        fixture.source.permissionEvidenceID = nil
        let document = CommunityTuneBenchmarkDocument(schemaVersion: 1, fixtures: [fixture])
        let data = try CommunityTuneBenchmark.encoder().encode(document)

        let report = try await CommunityTuneBenchmark.run(documentData: data, mode: .localResearch)

        XCTAssertEqual(report.fixtures.count, 1)
        XCTAssertEqual(report.fixtures[0].candidate.status, .supported)
    }

    func testReportOrderingAndJSONAreDeterministic() async throws {
        let first = metadataFixture(id: "z-last", sourceID: "source.z", game: .fh6)
        let second = metadataFixture(id: "a-first", sourceID: "source.a", game: .fh5)
        let forward = CommunityTuneBenchmarkDocument(schemaVersion: 1, fixtures: [first, second])
        let reverse = CommunityTuneBenchmarkDocument(schemaVersion: 1, fixtures: [second, first])

        let firstReport = try await CommunityTuneBenchmark.run(document: forward, mode: .localResearch)
        let secondReport = try await CommunityTuneBenchmark.run(document: reverse, mode: .localResearch)
        let firstJSON = try CommunityTuneBenchmark.encodedReport(firstReport)
        let secondJSON = try CommunityTuneBenchmark.encodedReport(secondReport)

        XCTAssertEqual(firstReport.fixtures.map(\.fixtureID), ["a-first", "z-last"])
        XCTAssertEqual(firstReport, secondReport)
        XCTAssertEqual(firstJSON, secondJSON)
        XCTAssertFalse(String(decoding: firstJSON, as: UTF8.self).lowercased().contains("accuracyscore"))
    }

    func testHarnessSourceHasNoProductionProjectionSnapshotOrPersistenceDependency() throws {
        let implementationURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("CommunityTuneBenchmark.swift")
        let source = try String(contentsOf: implementationURL, encoding: .utf8)
        let forbidden = [
            ["Tune", "Output", "Projector"].joined(),
            ["Capability", "Projecting", "Tune", "Provider"].joined(),
            ["Vehicle", "Build", "Snapshot"].joined(),
            ["Saved", "Tune"].joined(),
            ["Swift", "Data"].joined()
        ]

        for symbol in forbidden {
            XCTAssertFalse(source.contains(symbol), "Test harness must not depend on \(symbol)")
        }
    }

    private func bundledFixtureData() throws -> Data {
        let bundle = Bundle(for: Self.self)
        let url = bundle.url(forResource: "CommunityTuneBenchmarks.v1", withExtension: "json")
            ?? bundle.url(forResource: "CommunityTuneBenchmarks.v1", withExtension: "json", subdirectory: "Fixtures")
        return try Data(contentsOf: XCTUnwrap(url))
    }

    private func makeFixture(
        id: String = "fixture.fh6.supra",
        sourceID: String = "source.synthetic.supra",
        publisher: String = "Synthetic Source",
        game: ForzaGame = .fh6
    ) -> CommunityTuneFixture {
        let performanceClass: PerformanceClass = game == .fh5 ? .a : .s1
        let performanceIndex = 750
        let part = BenchmarkBuildPart(
            normalizedKey: "raceTransmission",
            canonicalTunePartID: .raceTransmission,
            sourceLabel: "Race Transmission",
            state: .installed
        )
        return CommunityTuneFixture(
            id: id,
            source: BenchmarkSource(
                id: sourceID,
                kind: .syntheticTest,
                game: game,
                url: "https://example.com/\(sourceID)",
                publisher: publisher,
                publishedAt: Date(timeIntervalSince1970: 100),
                retrievedAt: Date(timeIntervalSince1970: 200),
                gameVersion: "test-build-1",
                contentFingerprint: "synthetic:\(sourceID)",
                derivativeOfSourceID: nil,
                extractionMethod: .syntheticTest,
                reviewerIDs: ["test"],
                coverage: .exactBuild,
                usagePermission: .committedNumericBenchmark,
                permissionBasis: .syntheticTest,
                license: nil,
                permissionEvidenceID: "test-source"
            ),
            context: BenchmarkContext(
                game: game,
                car: BenchmarkCarIdentity(
                    catalogID: "\(game.rawValue):2020-toyota-gr-supra",
                    year: 2020,
                    make: "Toyota",
                    model: "GR Supra"
                ),
                performanceClass: performanceClass,
                performanceIndex: performanceIndex,
                discipline: .road,
                build: BenchmarkBuild(
                    drivetrain: .rwd,
                    weightPounds: 3_340,
                    frontWeightPercent: 53,
                    peakHorsepower: 480,
                    peakTorqueFootPounds: 410,
                    tireCompound: BenchmarkTireCompound(id: "stock", displayName: "Stock"),
                    gearCount: 6,
                    partsCoverage: .complete,
                    partsFingerprint: "racetransmission=installed",
                    parts: [part],
                    notes: nil
                )
            ),
            fields: [observation(.frontTirePressure, value: 27)],
            unknowns: []
        )
    }

    private func metadataFixture(
        id: String,
        sourceID: String,
        game: ForzaGame
    ) -> CommunityTuneFixture {
        CommunityTuneFixture(
            id: id,
            source: BenchmarkSource(
                id: sourceID,
                kind: .reddit,
                game: game,
                url: "https://example.com/\(sourceID)",
                publisher: sourceID,
                publishedAt: nil,
                retrievedAt: Date(timeIntervalSince1970: 200),
                gameVersion: nil,
                contentFingerprint: "metadata:\(sourceID)",
                derivativeOfSourceID: nil,
                extractionMethod: .metadataOnly,
                reviewerIDs: [],
                coverage: .opaque,
                usagePermission: .metadataOnly,
                permissionBasis: .publicAvailability,
                license: nil,
                permissionEvidenceID: nil
            ),
            context: nil,
            fields: [],
            unknowns: [.init(path: "context", reason: "Not captured", note: nil)]
        )
    }

    private func observation(
        _ field: TuneFieldID,
        value: Double,
        step: Double? = nil
    ) -> BenchmarkFieldObservation {
        BenchmarkFieldObservation(
            id: field,
            unit: field.expectedUnit,
            status: .observed,
            value: value,
            observedStep: step,
            reason: nil,
            note: nil
        )
    }

    private func metric(_ id: String, in metrics: [BenchmarkGroupMetric]) -> BenchmarkGroupMetric? {
        metrics.first { $0.id == id }
    }
}
