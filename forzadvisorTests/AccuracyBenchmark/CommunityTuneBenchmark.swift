//
//  CommunityTuneBenchmark.swift
//  forzadvisorTests
//
//  Test-target-only evidence and comparison harness. Community observations
//  are intentionally separate from production snapshots and output routing.
//

import Foundation
@testable import forzadvisor

enum BenchmarkSourceKind: String, Codable, Sendable {
    case youtube
    case reddit
    case forum
    case official
    case firstPartySubmission
    case syntheticTest
}

enum BenchmarkSourceCoverage: String, Codable, Sendable {
    case exactBuild
    case partialBuild
    case opaque
}

enum BenchmarkExtractionMethod: String, Codable, Sendable {
    case manualSingleReview
    case manualDualReview
    case firstPartyExport
    case metadataOnly
    case syntheticTest
}

enum BenchmarkUsagePermission: String, Codable, Sendable {
    case committedNumericBenchmark
    case localResearchOnly
    case metadataOnly
    case unknown
    case prohibited
}

enum BenchmarkPermissionBasis: String, Codable, Sendable {
    case creatorPermission
    case compatibleLicense
    case firstPartySubmitted
    case syntheticTest
    case publicAvailability
    case unspecified

    var permitsCommittedNumbers: Bool {
        switch self {
        case .creatorPermission, .compatibleLicense, .firstPartySubmitted, .syntheticTest:
            true
        case .publicAvailability, .unspecified:
            false
        }
    }
}

struct BenchmarkLicense: Codable, Equatable, Sendable {
    var name: String?
    var url: String?
}

struct BenchmarkSource: Codable, Equatable, Sendable {
    var id: String
    var kind: BenchmarkSourceKind
    var game: ForzaGame
    var url: String
    var publisher: String
    var publishedAt: Date?
    var retrievedAt: Date
    var gameVersion: String?
    var contentFingerprint: String
    var derivativeOfSourceID: String?
    var extractionMethod: BenchmarkExtractionMethod
    var reviewerIDs: [String]
    var coverage: BenchmarkSourceCoverage
    var usagePermission: BenchmarkUsagePermission
    var permissionBasis: BenchmarkPermissionBasis
    var license: BenchmarkLicense?
    var permissionEvidenceID: String?
}

struct BenchmarkCarIdentity: Codable, Equatable, Sendable {
    var catalogID: String
    var year: Int
    var make: String
    var model: String
}

struct BenchmarkTireCompound: Codable, Equatable, Sendable {
    var id: String
    var displayName: String
}

enum BenchmarkPartState: String, Codable, Sendable {
    case installed
    case notInstalled
    case unknown
}

enum BenchmarkPartsCoverage: String, Codable, Sendable {
    case complete
    case partial
    case unknown
}

struct BenchmarkBuildPart: Codable, Equatable, Sendable {
    var normalizedKey: String
    var canonicalTunePartID: TunePartID?
    var sourceLabel: String
    var state: BenchmarkPartState
}

struct BenchmarkBuild: Codable, Equatable, Sendable {
    var drivetrain: Drivetrain
    var weightPounds: Int
    var frontWeightPercent: Double
    var peakHorsepower: Int?
    var peakTorqueFootPounds: Int?
    var tireCompound: BenchmarkTireCompound
    var gearCount: Int
    var partsCoverage: BenchmarkPartsCoverage
    var partsFingerprint: String
    var parts: [BenchmarkBuildPart]
    var notes: String?

    var canonicalPartsFingerprint: String {
        parts
            .map { "\($0.normalizedKey.benchmarkNormalized)=\($0.state.rawValue)" }
            .sorted()
            .joined(separator: "|")
    }
}

struct BenchmarkContext: Codable, Equatable, Sendable {
    var game: ForzaGame
    var car: BenchmarkCarIdentity
    var performanceClass: PerformanceClass
    var performanceIndex: Int
    var discipline: DrivingDiscipline
    var build: BenchmarkBuild
}

enum BenchmarkFieldState: String, Codable, Sendable {
    case observed
    case notShown
    case notApplicable
    case ambiguous
}

struct BenchmarkFieldObservation: Codable, Equatable, Sendable {
    var id: TuneFieldID
    var unit: TuneUnit
    var status: BenchmarkFieldState
    var value: Double?
    var observedStep: Double?
    var reason: String?
    var note: String?
}

struct BenchmarkUnknown: Codable, Equatable, Sendable {
    var path: String
    var reason: String
    var note: String?
}

struct CommunityTuneFixture: Codable, Equatable, Sendable {
    var id: String
    var source: BenchmarkSource
    var context: BenchmarkContext?
    var fields: [BenchmarkFieldObservation]
    var unknowns: [BenchmarkUnknown]
}

struct CommunityTuneBenchmarkDocument: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var fixtures: [CommunityTuneFixture]
}

enum BenchmarkValidationMode: Sendable {
    case bundledFixture
    case localResearch
}

enum BenchmarkValidationCode: String, Codable, Sendable {
    case unsupportedSchema
    case blankIdentifier
    case duplicateFixtureID
    case duplicateSourceID
    case duplicateFieldID
    case invalidURL
    case invalidSource
    case invalidPermission
    case numericValuesForbidden
    case missingContext
    case invalidCarIdentity
    case invalidClassPI
    case invalidBuild
    case invalidParts
    case unitMismatch
    case nonFiniteValue
    case illegalFieldState
    case missingReason
    case invalidUnknown
}

struct BenchmarkValidationIssue: Codable, Equatable, Error, Sendable {
    var code: BenchmarkValidationCode
    var path: String
    var message: String
}

extension CommunityTuneBenchmarkDocument {
    func validationIssues(mode: BenchmarkValidationMode) -> [BenchmarkValidationIssue] {
        var issues: [BenchmarkValidationIssue] = []
        if schemaVersion != Self.currentSchemaVersion {
            issues.append(.init(
                code: .unsupportedSchema,
                path: "schemaVersion",
                message: "Expected schema version \(Self.currentSchemaVersion)."
            ))
        }

        var fixtureIDs = Set<String>()
        var sourceIDs = Set<String>()
        for (index, fixture) in fixtures.enumerated() {
            let path = "fixtures[\(index)]"
            let fixtureID = fixture.id.benchmarkNormalized
            if fixtureID.isEmpty {
                issues.append(.init(code: .blankIdentifier, path: "\(path).id", message: "Fixture ID is required."))
            } else if !fixtureIDs.insert(fixtureID).inserted {
                issues.append(.init(code: .duplicateFixtureID, path: "\(path).id", message: "Fixture ID must be unique."))
            }

            let sourceID = fixture.source.id.benchmarkNormalized
            if sourceID.isEmpty {
                issues.append(.init(code: .blankIdentifier, path: "\(path).source.id", message: "Source ID is required."))
            } else if !sourceIDs.insert(sourceID).inserted {
                issues.append(.init(code: .duplicateSourceID, path: "\(path).source.id", message: "Source ID must be unique."))
            }

            issues.append(contentsOf: fixture.validationIssues(path: path, mode: mode))
        }
        return issues
    }
}

private extension CommunityTuneFixture {
    func validationIssues(path: String, mode: BenchmarkValidationMode) -> [BenchmarkValidationIssue] {
        var issues: [BenchmarkValidationIssue] = []
        let numericFields = fields.filter { $0.status == .observed }
        let sourcePath = "\(path).source"

        if source.publisher.benchmarkNormalized.isEmpty || source.contentFingerprint.benchmarkNormalized.isEmpty {
            issues.append(.init(code: .invalidSource, path: sourcePath, message: "Publisher and content fingerprint are required."))
        }
        guard let components = URLComponents(string: source.url),
              components.scheme?.lowercased() == "https",
              components.host?.isEmpty == false else {
            issues.append(.init(code: .invalidURL, path: "\(sourcePath).url", message: "Source URL must use HTTPS and include a host."))
            return issues + fieldIssues(path: path)
        }

        let reviewers = source.reviewerIDs.map(\.benchmarkNormalized).filter { !$0.isEmpty }
        if Set(reviewers).count != reviewers.count {
            issues.append(.init(code: .invalidSource, path: "\(sourcePath).reviewerIDs", message: "Reviewer IDs must be unique."))
        }
        if source.extractionMethod == .manualDualReview, Set(reviewers).count < 2 {
            issues.append(.init(code: .invalidSource, path: "\(sourcePath).reviewerIDs", message: "Dual review requires two independent reviewer IDs."))
        }

        switch source.usagePermission {
        case .committedNumericBenchmark:
            if !source.permissionBasis.permitsCommittedNumbers
                || source.permissionEvidenceID?.benchmarkNormalized.isEmpty != false {
                issues.append(.init(code: .invalidPermission, path: sourcePath, message: "Committed numbers require an accepted permission basis and evidence ID."))
            }
            if source.permissionBasis == .syntheticTest, mode == .bundledFixture {
                issues.append(.init(code: .invalidPermission, path: sourcePath, message: "Synthetic numeric fixtures belong in tests, not the bundled document."))
            }
            if source.permissionBasis == .compatibleLicense {
                let licenseName = source.license?.name?.benchmarkNormalized ?? ""
                let licenseURL = source.license?.url ?? ""
                let licenseComponents = URLComponents(string: licenseURL)
                if licenseName.isEmpty
                    || licenseComponents?.scheme?.lowercased() != "https"
                    || licenseComponents?.host?.isEmpty != false {
                    issues.append(.init(code: .invalidPermission, path: "\(sourcePath).license", message: "Compatible-license evidence requires a named HTTPS license."))
                }
            }
        case .localResearchOnly:
            if mode == .bundledFixture {
                issues.append(.init(code: .invalidPermission, path: sourcePath, message: "Local research fixtures cannot be committed as bundled resources."))
            }
        case .metadataOnly:
            if !numericFields.isEmpty {
                issues.append(.init(code: .numericValuesForbidden, path: "\(path).fields", message: "Metadata-only sources cannot contain observed numeric values."))
            }
        case .unknown, .prohibited:
            issues.append(.init(code: .invalidPermission, path: sourcePath, message: "Unknown or prohibited source permission fails closed."))
            if !numericFields.isEmpty {
                issues.append(.init(code: .numericValuesForbidden, path: "\(path).fields", message: "Numeric values require explicit benchmark permission."))
            }
        }

        if source.permissionBasis == .publicAvailability,
           source.usagePermission == .committedNumericBenchmark {
            issues.append(.init(code: .invalidPermission, path: sourcePath, message: "Public availability is not permission to commit numeric data."))
        }

        if !numericFields.isEmpty, context == nil {
            issues.append(.init(code: .missingContext, path: "\(path).context", message: "Numeric comparisons require an exact build context."))
        }
        if let context {
            if context.game != source.game {
                issues.append(.init(code: .invalidSource, path: "\(sourcePath).game", message: "Source game must match the fixture context."))
            }
            issues.append(contentsOf: context.validationIssues(path: "\(path).context"))
        } else if source.coverage != .opaque {
            issues.append(.init(code: .missingContext, path: "\(path).context", message: "Only opaque metadata-only sources may omit context."))
        }

        issues.append(contentsOf: fieldIssues(path: path))

        for (index, unknown) in unknowns.enumerated() {
            if unknown.path.benchmarkNormalized.isEmpty || unknown.reason.benchmarkNormalized.isEmpty {
                issues.append(.init(code: .invalidUnknown, path: "\(path).unknowns[\(index)]", message: "Unknowns require a path and reason."))
            }
        }
        return issues
    }

    func fieldIssues(path: String) -> [BenchmarkValidationIssue] {
        var issues: [BenchmarkValidationIssue] = []
        var seen = Set<TuneFieldID>()
        for (index, field) in fields.enumerated() {
            let fieldPath = "\(path).fields[\(index)]"
            if !seen.insert(field.id).inserted {
                issues.append(.init(code: .duplicateFieldID, path: "\(fieldPath).id", message: "Field IDs must be unique inside a fixture."))
            }
            if field.unit != field.id.expectedUnit {
                issues.append(.init(code: .unitMismatch, path: "\(fieldPath).unit", message: "Unit does not match the stable tune field."))
            }
            if let value = field.value, !value.isFinite {
                issues.append(.init(code: .nonFiniteValue, path: "\(fieldPath).value", message: "Observed values must be finite."))
            }
            if let step = field.observedStep, !step.isFinite || step <= 0 {
                issues.append(.init(code: .nonFiniteValue, path: "\(fieldPath).observedStep", message: "Observed steps must be finite and positive."))
            }

            switch field.status {
            case .observed:
                if field.value == nil {
                    issues.append(.init(code: .illegalFieldState, path: fieldPath, message: "Observed fields require a value."))
                }
            case .notShown:
                if field.value != nil || field.observedStep != nil {
                    issues.append(.init(code: .illegalFieldState, path: fieldPath, message: "Not-shown fields cannot carry values or steps."))
                }
            case .notApplicable:
                if field.value != nil || field.observedStep != nil {
                    issues.append(.init(code: .illegalFieldState, path: fieldPath, message: "Not-applicable fields cannot carry values or steps."))
                }
                if field.reason?.benchmarkNormalized.isEmpty != false {
                    issues.append(.init(code: .missingReason, path: "\(fieldPath).reason", message: "Not-applicable fields require a reason."))
                }
            case .ambiguous:
                if field.value != nil || field.observedStep != nil {
                    issues.append(.init(code: .illegalFieldState, path: fieldPath, message: "Ambiguous fields cannot carry an invented value or step."))
                }
                if field.note?.benchmarkNormalized.isEmpty != false {
                    issues.append(.init(code: .missingReason, path: "\(fieldPath).note", message: "Ambiguous fields must explain the ambiguity."))
                }
            }
        }
        return issues
    }
}

private extension BenchmarkContext {
    func validationIssues(path: String) -> [BenchmarkValidationIssue] {
        var issues: [BenchmarkValidationIssue] = []
        if car.catalogID.benchmarkNormalized.isEmpty
            || car.year <= 0
            || car.make.benchmarkNormalized.isEmpty
            || car.model.benchmarkNormalized.isEmpty {
            issues.append(.init(code: .invalidCarIdentity, path: "\(path).car", message: "Catalog ID, year, make, and model are required."))
        }
        guard let piRange = game.performanceIndexRange(for: performanceClass),
              piRange.contains(performanceIndex) else {
            issues.append(.init(code: .invalidClassPI, path: path, message: "Performance class and PI are invalid for the selected game."))
            return issues + build.validationIssues(path: "\(path).build")
        }
        issues.append(contentsOf: build.validationIssues(path: "\(path).build"))
        return issues
    }
}

private extension BenchmarkBuild {
    var hasValidCompletePartsInventory: Bool {
        guard partsCoverage == .complete,
              !parts.isEmpty,
              !partsFingerprint.benchmarkNormalized.isEmpty,
              partsFingerprint == canonicalPartsFingerprint,
              !parts.contains(where: { $0.state == .unknown }) else {
            return false
        }

        let keys = parts.map { $0.normalizedKey.benchmarkNormalized }
        return keys.allSatisfy { !$0.isEmpty }
            && Set(keys).count == keys.count
            && parts.allSatisfy { !$0.sourceLabel.benchmarkNormalized.isEmpty }
    }

    func validationIssues(path: String) -> [BenchmarkValidationIssue] {
        var issues: [BenchmarkValidationIssue] = []
        if !(1_500...7_000).contains(weightPounds)
            || !(30...70).contains(frontWeightPercent)
            || !(1...10).contains(gearCount)
            || peakHorsepower.map({ $0 <= 0 }) == true
            || peakTorqueFootPounds.map({ $0 <= 0 }) == true
            || tireCompound.id.benchmarkNormalized.isEmpty
            || tireCompound.displayName.benchmarkNormalized.isEmpty {
            issues.append(.init(code: .invalidBuild, path: path, message: "Build statistics, tire compound, or gear count are invalid."))
        }

        var partKeys = Set<String>()
        for (index, part) in parts.enumerated() {
            let key = part.normalizedKey.benchmarkNormalized
            if key.isEmpty || part.sourceLabel.benchmarkNormalized.isEmpty || !partKeys.insert(key).inserted {
                issues.append(.init(code: .invalidParts, path: "\(path).parts[\(index)]", message: "Parts require unique normalized keys and source labels."))
            }
        }
        if partsFingerprint != canonicalPartsFingerprint {
            issues.append(.init(code: .invalidParts, path: "\(path).partsFingerprint", message: "Parts fingerprint must match the normalized part observations."))
        }
        if partsCoverage == .complete && parts.isEmpty {
            issues.append(.init(code: .invalidParts, path: "\(path).parts", message: "Complete parts coverage requires a non-empty parts inventory."))
        }
        if partsCoverage == .complete && parts.contains(where: { $0.state == .unknown }) {
            issues.append(.init(code: .invalidParts, path: "\(path).partsCoverage", message: "Complete parts coverage cannot contain unknown part states."))
        }
        if partsCoverage == .complete,
           !hasValidCompletePartsInventory,
           !issues.contains(where: { $0.code == .invalidParts }) {
            issues.append(.init(code: .invalidParts, path: "\(path).parts", message: "Complete parts coverage requires a structurally valid canonical inventory."))
        }
        return issues
    }
}

enum BenchmarkCohortClassification: String, Codable, Sendable {
    case exact
    case exploratory
}

struct BenchmarkCohortIdentity: Equatable, Sendable {
    var classification: BenchmarkCohortClassification
    var fingerprint: String
}

extension CommunityTuneFixture {
    var cohortIdentity: BenchmarkCohortIdentity {
        guard let context,
              source.gameVersion?.benchmarkNormalized.isEmpty == false,
              source.coverage == .exactBuild,
              context.build.hasValidCompletePartsInventory,
              context.build.peakHorsepower != nil,
              context.build.peakTorqueFootPounds != nil,
              unknowns.isEmpty else {
            return .init(classification: .exploratory, fingerprint: "exploratory:\(id.benchmarkNormalized)")
        }

        let parts = context.build.canonicalPartsFingerprint
        let values = [
            context.game.rawValue,
            source.gameVersion?.benchmarkNormalized ?? "",
            context.car.catalogID.benchmarkNormalized,
            String(context.car.year),
            context.car.make.benchmarkNormalized,
            context.car.model.benchmarkNormalized,
            context.performanceClass.rawValue,
            String(context.performanceIndex),
            context.discipline.rawValue,
            context.build.drivetrain.rawValue,
            String(context.build.weightPounds),
            context.build.frontWeightPercent.benchmarkStableNumber,
            String(context.build.peakHorsepower ?? 0),
            String(context.build.peakTorqueFootPounds ?? 0),
            context.build.tireCompound.id.benchmarkNormalized,
            String(context.build.gearCount),
            parts
        ]
        return .init(classification: .exact, fingerprint: values.joined(separator: "::"))
    }
}

enum BenchmarkCandidateStatus: String, Codable, Sendable {
    case supported
    case unsupportedRuleset
    case notEvaluatedMetadataOnly
    case invalidCandidate
}

struct BenchmarkCandidateValue: Codable, Equatable, Sendable {
    var field: TuneFieldID
    var value: Double
}

struct BenchmarkCandidate: Codable, Equatable, Sendable {
    var status: BenchmarkCandidateStatus
    var values: [BenchmarkCandidateValue]
    var diagnostics: [String]

    var valuesByField: [TuneFieldID: Double] {
        Dictionary(uniqueKeysWithValues: values.map { ($0.field, $0.value) })
    }
}

enum RawLocalBenchmarkCandidateAdapter {
    static let id = "forzadvisor.raw-local-provider"
    static let version = "1"

    static func candidate(for fixture: CommunityTuneFixture) async -> BenchmarkCandidate {
        guard let context = fixture.context else {
            return .init(status: .notEvaluatedMetadataOnly, values: [], diagnostics: [])
        }
        guard context.game == .fh6 else {
            return .init(
                status: .unsupportedRuleset,
                values: [],
                diagnostics: ["No local \(context.game.shortTitle) ruleset is available."]
            )
        }

        let car = CarInput(
            game: context.game,
            year: context.car.year,
            make: context.car.make,
            model: context.car.model,
            weightPounds: context.build.weightPounds,
            frontWeightPercent: context.build.frontWeightPercent,
            performanceIndex: context.performanceIndex,
            performanceClass: context.performanceClass,
            drivetrain: context.build.drivetrain,
            peakHorsepower: context.build.peakHorsepower,
            peakTorqueFootPounds: context.build.peakTorqueFootPounds
        )
        let request = TuneRequest(car: car, discipline: context.discipline, buildSnapshot: nil)

        do {
            let tune = try await LocalSampleTuneProvider().generateTune(for: request)
            var values: [TuneFieldID: Double] = [:]
            var diagnostics: [String] = []
            var duplicateFields = Set<TuneFieldID>()

            for section in tune.sections {
                for line in section.lines {
                    if let numericValue = line.numericValue {
                        guard let field = line.fieldID else {
                            diagnostics.append("untypedNumericLine:\(section.title)/\(line.label)")
                            continue
                        }
                        if values.updateValue(numericValue, forKey: field) != nil {
                            duplicateFields.insert(field)
                        }
                    } else if let field = line.fieldID {
                        diagnostics.append("malformedTypedValue:\(field.benchmarkStableID)")
                    }
                }
            }

            if !duplicateFields.isEmpty {
                diagnostics.append(contentsOf: duplicateFields
                    .map { "duplicateField:\($0.benchmarkStableID)" }
                    .sorted())
                return .init(status: .invalidCandidate, values: [], diagnostics: diagnostics.sorted())
            }
            return .init(
                status: .supported,
                values: values
                    .map { .init(field: $0.key, value: $0.value) }
                    .sorted { $0.field.benchmarkStableID < $1.field.benchmarkStableID },
                diagnostics: diagnostics.sorted()
            )
        } catch let error as LocalTuneProviderError {
            return .init(status: .unsupportedRuleset, values: [], diagnostics: [error.localizedDescription])
        } catch {
            return .init(status: .invalidCandidate, values: [], diagnostics: [String(describing: error)])
        }
    }
}

enum BenchmarkFieldComparisonStatus: String, Codable, Sendable {
    case withinBand
    case outsideBand
    case candidateMissing
    case referenceUnknown
    case notApplicable
    case unitMismatch
}

struct BenchmarkFieldComparison: Codable, Equatable, Sendable {
    var field: TuneFieldID
    var status: BenchmarkFieldComparisonStatus
    var candidate: Double?
    var reference: Double?
    var unit: TuneUnit
    var tolerance: Double?
    var signedDelta: Double?
    var absoluteDelta: Double?
    var bandDistance: Double?
    var stepDistance: Double?
    var relativePercentDelta: Double?
}

enum BenchmarkGroupMetricStatus: String, Codable, Sendable {
    case available
    case unavailable
}

struct BenchmarkGroupMetric: Codable, Equatable, Sendable {
    var id: String
    var status: BenchmarkGroupMetricStatus
    var candidate: Double?
    var reference: Double?
    var signedDelta: Double?
    var absoluteDelta: Double?
}

enum BenchmarkConsensusLabel: String, Codable, Sendable {
    case insufficientIndependentSources
    case pairwiseAgreement
    case communityCenter
}

struct BenchmarkFieldDistribution: Codable, Equatable, Sendable {
    var field: TuneFieldID
    var sampleCount: Int
    var median: Double
    var minimum: Double
    var maximum: Double
}

struct BenchmarkFixtureReport: Codable, Equatable, Sendable {
    var fixtureID: String
    var sourceID: String
    var source: BenchmarkSource
    var game: ForzaGame
    var cohortClassification: BenchmarkCohortClassification
    var cohortFingerprint: String
    var candidate: BenchmarkCandidate
    var fieldComparisons: [BenchmarkFieldComparison]
    var groupedMetrics: [BenchmarkGroupMetric]
}

struct BenchmarkCohortReport: Codable, Equatable, Sendable {
    var classification: BenchmarkCohortClassification
    var fingerprint: String
    var fixtureIDs: [String]
    var independentSourceCount: Int
    var consensusLabel: BenchmarkConsensusLabel
    var distributions: [BenchmarkFieldDistribution]
}

struct CommunityTuneBenchmarkReport: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var fixtureSnapshotHash: String
    var candidateAdapterID: String
    var candidateAdapterVersion: String
    var fixtures: [BenchmarkFixtureReport]
    var cohorts: [BenchmarkCohortReport]
}

enum BenchmarkTolerancePolicy {
    static func band(
        for field: TuneFieldID,
        reference: Double,
        observedStep: Double?
    ) -> Double {
        if let observedStep, observedStep.isFinite, observedStep > 0 {
            return observedStep
        }
        switch field {
        case .frontTirePressure, .rearTirePressure:
            return 0.5
        case .finalDrive, .gearRatio:
            return 0.05
        case .frontToe, .rearToe:
            return 0.1
        case .frontCamber, .rearCamber, .caster:
            return 0.2
        case .frontARB, .rearARB:
            return 2
        case .frontSpringRate, .rearSpringRate:
            return max(25, abs(reference) * 0.05)
        case .frontRideHeight, .rearRideHeight:
            return 0.2
        case .frontRebound, .rearRebound, .frontBump, .rearBump:
            return 0.5
        case .frontAero, .rearAero:
            return max(10, abs(reference) * 0.05)
        case .brakeBalance:
            return 2
        case .brakePressure:
            return 5
        case .differentialAcceleration,
             .differentialDeceleration,
             .frontDifferentialAcceleration,
             .frontDifferentialDeceleration,
             .rearDifferentialAcceleration,
             .rearDifferentialDeceleration,
             .differentialCenterBalance:
            return 5
        }
    }
}

enum CommunityTuneBenchmark {
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    static func decode(_ data: Data) throws -> CommunityTuneBenchmarkDocument {
        try decoder().decode(CommunityTuneBenchmarkDocument.self, from: data)
    }

    static func run(
        documentData: Data,
        mode: BenchmarkValidationMode = .localResearch
    ) async throws -> CommunityTuneBenchmarkReport {
        try await run(document: decode(documentData), mode: mode)
    }

    static func run(
        document: CommunityTuneBenchmarkDocument,
        mode: BenchmarkValidationMode = .localResearch
    ) async throws -> CommunityTuneBenchmarkReport {
        let issues = document.validationIssues(mode: mode)
        guard issues.isEmpty else {
            throw BenchmarkHarnessError.invalidDocument(issues)
        }

        var fixtureReports: [BenchmarkFixtureReport] = []
        for fixture in document.fixtures.sorted(by: { $0.id < $1.id }) {
            let candidate = await RawLocalBenchmarkCandidateAdapter.candidate(for: fixture)
            let identity = fixture.cohortIdentity
            let fieldComparisons = candidate.status == .supported
                ? compare(candidate: candidate, fixture: fixture)
                : []
            let groupedMetrics = candidate.status == .supported
                ? groupedMetrics(candidate: candidate, fixture: fixture)
                : []
            fixtureReports.append(.init(
                fixtureID: fixture.id,
                sourceID: fixture.source.id,
                source: canonicalSource(fixture.source),
                game: fixture.source.game,
                cohortClassification: identity.classification,
                cohortFingerprint: identity.fingerprint,
                candidate: candidate,
                fieldComparisons: fieldComparisons,
                groupedMetrics: groupedMetrics
            ))
        }

        return .init(
            schemaVersion: CommunityTuneBenchmarkReport.currentSchemaVersion,
            fixtureSnapshotHash: stableDocumentFingerprint(document),
            candidateAdapterID: RawLocalBenchmarkCandidateAdapter.id,
            candidateAdapterVersion: RawLocalBenchmarkCandidateAdapter.version,
            fixtures: fixtureReports,
            cohorts: cohortReports(for: document.fixtures)
        )
    }

    static func encodedReport(_ report: CommunityTuneBenchmarkReport) throws -> Data {
        try encoder().encode(report)
    }

    static func compare(
        candidate: BenchmarkCandidate,
        fixture: CommunityTuneFixture
    ) -> [BenchmarkFieldComparison] {
        guard candidate.status == .supported else { return [] }
        let candidateValues = candidate.valuesByField
        return fixture.fields.map { observation in
            switch observation.status {
            case .notShown, .ambiguous:
                return emptyComparison(observation, status: .referenceUnknown)
            case .notApplicable:
                return emptyComparison(observation, status: .notApplicable)
            case .observed:
                guard observation.unit == observation.id.expectedUnit else {
                    return emptyComparison(observation, status: .unitMismatch)
                }
                guard let reference = observation.value,
                      let candidateValue = candidateValues[observation.id] else {
                    return .init(
                        field: observation.id,
                        status: .candidateMissing,
                        candidate: candidateValues[observation.id],
                        reference: observation.value,
                        unit: observation.unit,
                        tolerance: nil,
                        signedDelta: nil,
                        absoluteDelta: nil,
                        bandDistance: nil,
                        stepDistance: nil,
                        relativePercentDelta: nil
                    )
                }
                let tolerance = BenchmarkTolerancePolicy.band(
                    for: observation.id,
                    reference: reference,
                    observedStep: observation.observedStep
                )
                let delta = candidateValue - reference
                let absolute = abs(delta)
                return .init(
                    field: observation.id,
                    status: absolute <= tolerance ? .withinBand : .outsideBand,
                    candidate: candidateValue,
                    reference: reference,
                    unit: observation.unit,
                    tolerance: tolerance,
                    signedDelta: delta,
                    absoluteDelta: absolute,
                    bandDistance: absolute / tolerance,
                    stepDistance: observation.observedStep.map { absolute / $0 },
                    relativePercentDelta: abs(reference) > 1e-9 ? delta / abs(reference) * 100 : nil
                )
            }
        }.sorted { $0.field.benchmarkStableID < $1.field.benchmarkStableID }
    }

    static func groupedMetrics(
        candidate: BenchmarkCandidate,
        fixture: CommunityTuneFixture
    ) -> [BenchmarkGroupMetric] {
        guard candidate.status == .supported, let context = fixture.context else { return [] }
        let candidateValues = candidate.valuesByField
        let referenceValues = Dictionary(uniqueKeysWithValues: fixture.fields.compactMap { field -> (TuneFieldID, Double)? in
            guard field.status == .observed, let value = field.value else { return nil }
            return (field.id, value)
        })
        var metrics: [BenchmarkGroupMetric] = []

        func value(_ field: TuneFieldID, in values: [TuneFieldID: Double]) -> Double? {
            values[field]
        }
        func difference(_ first: TuneFieldID, _ second: TuneFieldID, in values: [TuneFieldID: Double]) -> Double? {
            guard let firstValue = value(first, in: values), let secondValue = value(second, in: values) else { return nil }
            return firstValue - secondValue
        }
        func share(_ first: TuneFieldID, _ second: TuneFieldID, in values: [TuneFieldID: Double]) -> Double? {
            guard let firstValue = value(first, in: values), let secondValue = value(second, in: values) else { return nil }
            let total = firstValue + secondValue
            guard abs(total) > 1e-9 else { return nil }
            return firstValue / total
        }
        func ratio(_ numerator: TuneFieldID, _ denominator: TuneFieldID, in values: [TuneFieldID: Double]) -> Double? {
            guard let numeratorValue = value(numerator, in: values),
                  let denominatorValue = value(denominator, in: values),
                  abs(denominatorValue) > 1e-9 else { return nil }
            return numeratorValue / denominatorValue
        }
        func append(_ id: String, candidate candidateValue: Double?, reference referenceValue: Double?) {
            guard let candidateValue, candidateValue.isFinite,
                  let referenceValue, referenceValue.isFinite else {
                metrics.append(.init(id: id, status: .unavailable, candidate: candidateValue, reference: referenceValue, signedDelta: nil, absoluteDelta: nil))
                return
            }
            let delta = candidateValue - referenceValue
            metrics.append(.init(id: id, status: .available, candidate: candidateValue, reference: referenceValue, signedDelta: delta, absoluteDelta: abs(delta)))
        }

        append("tires.frontMinusRear", candidate: difference(.frontTirePressure, .rearTirePressure, in: candidateValues), reference: difference(.frontTirePressure, .rearTirePressure, in: referenceValues))
        append("tires.frontShare", candidate: share(.frontTirePressure, .rearTirePressure, in: candidateValues), reference: share(.frontTirePressure, .rearTirePressure, in: referenceValues))
        append("antirollBars.frontShare", candidate: share(.frontARB, .rearARB, in: candidateValues), reference: share(.frontARB, .rearARB, in: referenceValues))

        let candidateSpringShare = share(.frontSpringRate, .rearSpringRate, in: candidateValues)
        let referenceSpringShare = share(.frontSpringRate, .rearSpringRate, in: referenceValues)
        append("springs.frontShare", candidate: candidateSpringShare, reference: referenceSpringShare)
        let frontWeightShare = context.build.frontWeightPercent / 100
        append("springs.frontWeightResidual", candidate: candidateSpringShare.map { $0 - frontWeightShare }, reference: referenceSpringShare.map { $0 - frontWeightShare })

        append("damping.reboundFrontShare", candidate: share(.frontRebound, .rearRebound, in: candidateValues), reference: share(.frontRebound, .rearRebound, in: referenceValues))
        append("damping.bumpFrontShare", candidate: share(.frontBump, .rearBump, in: candidateValues), reference: share(.frontBump, .rearBump, in: referenceValues))
        append("damping.frontBumpReboundRatio", candidate: ratio(.frontBump, .frontRebound, in: candidateValues), reference: ratio(.frontBump, .frontRebound, in: referenceValues))
        append("damping.rearBumpReboundRatio", candidate: ratio(.rearBump, .rearRebound, in: candidateValues), reference: ratio(.rearBump, .rearRebound, in: referenceValues))

        append("rideHeight.rearMinusFront", candidate: difference(.rearRideHeight, .frontRideHeight, in: candidateValues), reference: difference(.rearRideHeight, .frontRideHeight, in: referenceValues))
        append("alignment.camberFrontMinusRear", candidate: difference(.frontCamber, .rearCamber, in: candidateValues), reference: difference(.frontCamber, .rearCamber, in: referenceValues))
        append("alignment.toeFrontMinusRear", candidate: difference(.frontToe, .rearToe, in: candidateValues), reference: difference(.frontToe, .rearToe, in: referenceValues))
        append("aero.frontShare", candidate: share(.frontAero, .rearAero, in: candidateValues), reference: share(.frontAero, .rearAero, in: referenceValues))

        append("differential.singleAxleSpread", candidate: difference(.differentialAcceleration, .differentialDeceleration, in: candidateValues), reference: difference(.differentialAcceleration, .differentialDeceleration, in: referenceValues))
        append("differential.frontSpread", candidate: difference(.frontDifferentialAcceleration, .frontDifferentialDeceleration, in: candidateValues), reference: difference(.frontDifferentialAcceleration, .frontDifferentialDeceleration, in: referenceValues))
        append("differential.rearSpread", candidate: difference(.rearDifferentialAcceleration, .rearDifferentialDeceleration, in: candidateValues), reference: difference(.rearDifferentialAcceleration, .rearDifferentialDeceleration, in: referenceValues))
        append("differential.accelerationFrontShare", candidate: share(.frontDifferentialAcceleration, .rearDifferentialAcceleration, in: candidateValues), reference: share(.frontDifferentialAcceleration, .rearDifferentialAcceleration, in: referenceValues))
        append("differential.decelerationFrontShare", candidate: share(.frontDifferentialDeceleration, .rearDifferentialDeceleration, in: candidateValues), reference: share(.frontDifferentialDeceleration, .rearDifferentialDeceleration, in: referenceValues))
        append("differential.centerRear", candidate: value(.differentialCenterBalance, in: candidateValues), reference: value(.differentialCenterBalance, in: referenceValues))

        if context.build.gearCount > 1 {
            for index in 1..<context.build.gearCount {
                append(
                    "gearing.spacing.\(index)-\(index + 1)",
                    candidate: ratio(.gearRatio(index + 1), .gearRatio(index), in: candidateValues),
                    reference: ratio(.gearRatio(index + 1), .gearRatio(index), in: referenceValues)
                )
            }
        }
        return metrics.sorted { $0.id < $1.id }
    }

    static func cohortReports(for fixtures: [CommunityTuneFixture]) -> [BenchmarkCohortReport] {
        let grouped = Dictionary(grouping: fixtures) { $0.cohortIdentity.fingerprint }
        return grouped.map { fingerprint, fixtures in
            let sortedFixtures = fixtures.sorted { $0.id < $1.id }
            let representatives = independentRepresentatives(from: sortedFixtures)
            let independentCount = representatives.count
            let consensus: BenchmarkConsensusLabel = switch independentCount {
            case 3...: .communityCenter
            case 2: .pairwiseAgreement
            default: .insufficientIndependentSources
            }
            return .init(
                classification: sortedFixtures[0].cohortIdentity.classification,
                fingerprint: fingerprint,
                fixtureIDs: sortedFixtures.map(\.id),
                independentSourceCount: independentCount,
                consensusLabel: consensus,
                distributions: fieldDistributions(for: representatives)
            )
        }.sorted { $0.fingerprint < $1.fingerprint }
    }

    private static func independentRepresentatives(
        from sortedFixtures: [CommunityTuneFixture]
    ) -> [CommunityTuneFixture] {
        var seenPublishers = Set<String>()
        var seenFingerprints = Set<String>()
        var seenSourceIDs = Set<String>()
        var representatives: [CommunityTuneFixture] = []

        for fixture in sortedFixtures {
            let publisher = fixture.source.publisher.benchmarkNormalized
            let fingerprint = fixture.source.contentFingerprint.benchmarkNormalized
            let sourceID = fixture.source.id.benchmarkNormalized
            let isDerivative = !(fixture.source.derivativeOfSourceID?.benchmarkNormalized ?? "").isEmpty
            let hasObservedNumbers = fixture.fields.contains { field in
                field.status == .observed && field.value?.isFinite == true
            }
            guard !isDerivative,
                  hasObservedNumbers,
                  !publisher.isEmpty,
                  !fingerprint.isEmpty,
                  !sourceID.isEmpty,
                  !seenPublishers.contains(publisher),
                  !seenFingerprints.contains(fingerprint),
                  !seenSourceIDs.contains(sourceID) else {
                continue
            }

            seenPublishers.insert(publisher)
            seenFingerprints.insert(fingerprint)
            seenSourceIDs.insert(sourceID)
            representatives.append(fixture)
        }
        return representatives
    }

    private static func fieldDistributions(for fixtures: [CommunityTuneFixture]) -> [BenchmarkFieldDistribution] {
        var values: [TuneFieldID: [Double]] = [:]
        for fixture in fixtures {
            for field in fixture.fields where field.status == .observed {
                if let value = field.value {
                    values[field.id, default: []].append(value)
                }
            }
        }
        return values.map { field, samples in
            let sorted = samples.sorted()
            return .init(
                field: field,
                sampleCount: sorted.count,
                median: median(sorted),
                minimum: sorted[0],
                maximum: sorted[sorted.count - 1]
            )
        }.sorted { $0.field.benchmarkStableID < $1.field.benchmarkStableID }
    }

    private static func median(_ sorted: [Double]) -> Double {
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2
            : sorted[middle]
    }

    private static func emptyComparison(
        _ observation: BenchmarkFieldObservation,
        status: BenchmarkFieldComparisonStatus
    ) -> BenchmarkFieldComparison {
        .init(
            field: observation.id,
            status: status,
            candidate: nil,
            reference: nil,
            unit: observation.unit,
            tolerance: nil,
            signedDelta: nil,
            absoluteDelta: nil,
            bandDistance: nil,
            stepDistance: nil,
            relativePercentDelta: nil
        )
    }

    private static func stableDocumentFingerprint(_ document: CommunityTuneBenchmarkDocument) -> String {
        let canonical = CommunityTuneBenchmarkDocument(
            schemaVersion: document.schemaVersion,
            fixtures: document.fixtures.map { fixture in
                var fixture = fixture
                fixture.source = canonicalSource(fixture.source)
                if var context = fixture.context {
                    context.build.parts.sort { $0.normalizedKey < $1.normalizedKey }
                    fixture.context = context
                }
                fixture.fields.sort { $0.id.benchmarkStableID < $1.id.benchmarkStableID }
                fixture.unknowns.sort { $0.path < $1.path }
                return fixture
            }.sorted { $0.id < $1.id }
        )
        let data = (try? encoder().encode(canonical)) ?? Data()
        let hash = data.reduce(UInt64(14_695_981_039_346_656_037)) { hash, byte in
            (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return "fnv1a64:\(hash.hexString)"
    }

    private static func canonicalSource(_ source: BenchmarkSource) -> BenchmarkSource {
        var source = source
        source.reviewerIDs.sort()
        return source
    }
}

enum BenchmarkHarnessError: Error, Equatable {
    case invalidDocument([BenchmarkValidationIssue])
}

private extension String {
    var benchmarkNormalized: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private extension Double {
    var benchmarkStableNumber: String {
        String(format: "%.9g", locale: Locale(identifier: "en_US_POSIX"), self)
    }
}

private extension UInt64 {
    var hexString: String {
        String(format: "%016llx", self)
    }
}

extension TuneFieldID {
    var benchmarkStableID: String {
        let data = try? JSONEncoder().encode(self)
        return data.flatMap { try? JSONDecoder().decode(String.self, from: $0) } ?? String(describing: self)
    }
}
