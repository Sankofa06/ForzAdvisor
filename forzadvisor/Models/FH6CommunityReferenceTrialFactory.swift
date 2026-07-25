//
//  FH6CommunityReferenceTrialFactory.swift
//  forzadvisor
//

import CryptoKit
import Foundation

struct FH6CommunityReferenceTrialFactory {
    static let maximumExportBytes = 256 * 1_024

    var locale: Locale = .current
    private let validationFactory: FirstPartyValidationRecordFactory

    init(locale: Locale = .current) {
        self.locale = locale
        validationFactory = FirstPartyValidationRecordFactory(locale: locale)
    }

    func eligibility(
        for tune: TuneResult,
        savedTune: TuneResult?,
        isStreaming: Bool
    ) -> Result<TuneResult, FH6CommunityReferenceTrialIssue> {
        validationFactory
            .eligibility(for: tune, savedTune: savedTune, isStreaming: isStreaming)
            .mapError(FH6CommunityReferenceTrialIssue.ineligibleCandidate)
    }

    func make(
        tune: TuneResult,
        savedTune: TuneResult?,
        isStreaming: Bool,
        capture: FH6CommunityReferenceTrialCapture,
        recordID: UUID = UUID(),
        submissionID: UUID = UUID(),
        permissionReceiptID: UUID = UUID(),
        createdAt: Date = .now
    ) throws -> FH6CommunityReferenceTrialRecord {
        let projected = try eligibility(
            for: tune,
            savedTune: savedTune,
            isStreaming: isStreaming
        ).get()
        let source = try makeSource(from: capture.source)
        let proof = try makeCandidateProof(from: projected)
        guard let candidateFingerprint = candidateFingerprint(for: proof) else {
            throw FH6CommunityReferenceTrialIssue.invalidStoredRecord
        }
        let association = FH6CommunityReferenceCandidateAssociation(
            catalogID: proof.vehicle.catalogID,
            performanceClass: proof.vehicle.performanceClass,
            performanceIndex: proof.vehicle.performanceIndex,
            confirmed: true,
            candidateFingerprint: candidateFingerprint
        )
        guard capture.referenceCandidate.catalogID == association.catalogID,
              capture.referenceCandidate.performanceClass == association.performanceClass,
              capture.referenceCandidate.performanceIndex == association.performanceIndex,
              capture.referenceCandidate.confirmed,
              capture.referenceCandidate.candidateFingerprint.isEmpty
                || capture.referenceCandidate.candidateFingerprint == candidateFingerprint else {
            throw FH6CommunityReferenceTrialIssue.referenceContextMismatch
        }
        try validateCapture(capture)
        let symptoms = capture.candidateDeficiencySymptoms.sorted {
            $0.rawValue < $1.rawValue
        }
        let content = try semanticFingerprint(
            source: source,
            candidateAssociation: association,
            context: capture.context,
            runs: capture.runs,
            outcome: capture.outcome,
            symptoms: symptoms,
            attestations: capture.attestations
        )
        return FH6CommunityReferenceTrialRecord(
            schemaVersion: FH6CommunityReferenceTrialRecord.currentSchemaVersion,
            consentVersion: FH6CommunityReferenceTrialRecord.currentConsentVersion,
            protocolVersion: FH6CommunityReferenceTrialRecord.currentProtocolVersion,
            recordID: recordID,
            submissionID: submissionID,
            permissionReceiptID: permissionReceiptID,
            createdAt: createdAt,
            game: .fh6,
            source: source,
            candidateAssociation: association,
            candidateTuneID: projected.id,
            candidateProof: proof,
            context: capture.context,
            runs: capture.runs,
            outcome: capture.outcome,
            candidateDeficiencySymptoms: symptoms,
            attestations: capture.attestations,
            consentScope: FH6CommunityReferenceTrialRecord.consentScope,
            unknowns: FH6CommunityReferenceTrialRecord.unknowns,
            privacyExclusions: FH6CommunityReferenceTrialRecord.privacyExclusions,
            contentFingerprint: content
        )
    }

    func sourceID(
        for contentURL: String,
        kind: FH6CommunityReferenceKind
    ) -> String? {
        guard let canonicalURL = normalizedContentURL(contentURL, kind: kind),
              let digest = try? hash(SourceIDPayload(
                kind: kind,
                canonicalContentURL: canonicalURL
              )) else {
            return nil
        }
        return "\(kind.rawValue):\(digest)"
    }

    func isValidSourceCapture(
        kind: FH6CommunityReferenceKind,
        contentURL: String,
        publisherDisplayName: String
    ) -> Bool {
        guard let sourceID = sourceID(
            for: contentURL,
            kind: kind
        ) else {
            return false
        }
        return (try? makeSource(from: .init(
            kind: kind,
            contentURL: contentURL,
            publisherDisplayName: publisherDisplayName,
            sourceID: sourceID,
            retrievedAt: Date(timeIntervalSince1970: 0)
        ))) != nil
    }

    func matches(
        _ record: FH6CommunityReferenceTrialRecord,
        tune: TuneResult
    ) -> Bool {
        guard isValid(record),
              record.candidateTuneID == tune.id,
              case .success(let eligibleTune) = eligibility(
                for: tune,
                savedTune: tune,
                isStreaming: false
              ),
              let proof = try? makeCandidateProof(from: eligibleTune),
              proof == record.candidateProof,
              let fingerprint = candidateFingerprint(for: proof) else {
            return false
        }
        return record.candidateAssociation.candidateFingerprint == fingerprint
    }

    func isValid(_ record: FH6CommunityReferenceTrialRecord) -> Bool {
        guard record.schemaVersion == FH6CommunityReferenceTrialRecord.currentSchemaVersion,
              record.consentVersion == FH6CommunityReferenceTrialRecord.currentConsentVersion,
              record.protocolVersion == FH6CommunityReferenceTrialRecord.currentProtocolVersion,
              record.game == .fh6,
              record.consentScope == FH6CommunityReferenceTrialRecord.consentScope,
              record.unknowns == FH6CommunityReferenceTrialRecord.unknowns,
              record.privacyExclusions == FH6CommunityReferenceTrialRecord.privacyExclusions,
              isCanonicalFingerprint(record.contentFingerprint),
              isValidSource(record.source),
              isValidProof(record.candidateProof),
              record.candidateAssociation == .init(
                catalogID: record.candidateProof.vehicle.catalogID,
                performanceClass: record.candidateProof.vehicle.performanceClass,
                performanceIndex: record.candidateProof.vehicle.performanceIndex,
                confirmed: true,
                candidateFingerprint: candidateFingerprint(for: record.candidateProof) ?? ""
              ),
              validateRecordProtocol(record) else {
            return false
        }
        guard let expected = try? semanticFingerprint(
            source: record.source,
            candidateAssociation: record.candidateAssociation,
            context: record.context,
            runs: record.runs,
            outcome: record.outcome,
            symptoms: record.candidateDeficiencySymptoms,
            attestations: record.attestations
        ) else {
            return false
        }
        return expected == record.contentFingerprint
    }

    func normalizedContentURL(
        _ rawValue: String,
        kind: FH6CommunityReferenceKind
    ) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              let rawHost = components.host?.lowercased(),
              components.user == nil,
              components.password == nil,
              components.fragment == nil,
              components.port == nil || components.port == 443,
              !isLocalOrIPAddress(rawHost),
              let canonicalHost = canonicalHost(rawHost, for: kind) else {
            return nil
        }
        components.scheme = "https"
        components.host = canonicalHost
        if components.port == 443 { components.port = nil }
        components.queryItems = components.queryItems?
            .filter { !isTrackingQueryName($0.name) }
            .sorted {
                if $0.name == $1.name { return ($0.value ?? "") < ($1.value ?? "") }
                return $0.name < $1.name
            }
        if components.queryItems?.isEmpty == true { components.queryItems = nil }
        if components.percentEncodedPath.count > 1,
           components.percentEncodedPath.hasSuffix("/") {
            components.percentEncodedPath.removeLast()
        }
        guard isContentPermalink(components, kind: kind) else {
            return nil
        }
        guard let canonical = components.string,
              canonicalString(canonical, maximumLength: 2_048) == canonical else {
            return nil
        }
        return canonical
    }

    func candidateFingerprint(
        for proof: FH6CommunityReferenceCandidateProof
    ) -> String? {
        guard canonicalString(proof.gameBuildVersion, maximumLength: 120)
                == proof.gameBuildVersion,
              proof.vehicle.stock,
              proof.shopParts.count == TunePartID.allCases.count,
              Set(proof.shopParts.map(\.partID)) == Set(TunePartID.allCases),
              proof.shopParts == proof.shopParts.sorted(by: {
                  $0.partID.rawValue < $1.partID.rawValue
              }),
              !proof.appliedFields.isEmpty,
              Set(proof.appliedFields.map(\.field)).count == proof.appliedFields.count,
              proof.appliedFields == proof.appliedFields.sorted(by: {
                  $0.field.stableID < $1.field.stableID
              }),
              proof.appliedFields.allSatisfy({
                  $0.value.isFinite && $0.unit == $0.field.expectedUnit
              }) else {
            return nil
        }
        return try? hash(CandidateIdentityPayload(
            gameBuildVersion: proof.gameBuildVersion,
            vehicle: proof.vehicle,
            shopParts: proof.shopParts,
            discipline: proof.discipline,
            ruleset: proof.ruleset,
            appliedFields: proof.appliedFields
        ))
    }

    private func makeSource(
        from capture: FH6CommunityReferenceSourceCapture
    ) throws -> FH6CommunityReferenceSourceMetadata {
        guard let url = normalizedContentURL(capture.contentURL, kind: capture.kind) else {
            throw FH6CommunityReferenceTrialIssue.invalidSourceURL
        }
        guard let publisher = canonicalString(capture.publisherDisplayName, maximumLength: 120),
              let sourceID = canonicalString(capture.sourceID, maximumLength: 160),
              let derivative = canonicalOptionalString(
                capture.derivativeOfSourceID,
                maximumLength: 160
              ) else {
            throw FH6CommunityReferenceTrialIssue.invalidSourceMetadata
        }
        guard derivative != sourceID else {
            throw FH6CommunityReferenceTrialIssue.selfDerivative
        }
        guard sourceID == self.sourceID(
            for: url,
            kind: capture.kind
        ) else {
            throw FH6CommunityReferenceTrialIssue.invalidSourceMetadata
        }
        let publisherFingerprint = try hash(PublisherIdentityPayload(
            kind: capture.kind,
            normalizedPublisherDisplayName: publisher.lowercased()
        ))
        let contentFingerprint = try hash(SourceIdentityPayload(
            kind: capture.kind,
            canonicalContentURL: url,
            sourceID: sourceID,
            derivativeOfSourceID: derivative
        ))
        return .init(
            kind: capture.kind,
            canonicalContentURL: url,
            publisherDisplayName: publisher,
            sourceID: sourceID,
            publisherIdentityFingerprint: publisherFingerprint,
            contentIdentityFingerprint: contentFingerprint,
            retrievedAt: capture.retrievedAt,
            derivativeOfSourceID: derivative,
            usageScope: .metadataOnly,
            permissionBasis: .publicAvailability
        )
    }

    private func makeCandidateProof(
        from tune: TuneResult
    ) throws -> FH6CommunityReferenceCandidateProof {
        guard let snapshot = tune.request.buildSnapshot,
              let catalog = snapshot.car.catalogReference,
              let year = snapshot.car.year,
              let horsepower = snapshot.car.peakHorsepower,
              let torque = snapshot.car.peakTorqueFootPounds,
              let tire = snapshot.tireCompound,
              let gearCount = snapshot.gearCount,
              let gameBuild = snapshot.gameBuild.version,
              let ruleset = tune.rulesetReference,
              let report = tune.projectionReport,
              let revision = validationFactory.revisionFingerprint(for: tune),
              let canonicalBuild = canonicalString(gameBuild, maximumLength: 120),
              let catalogID = canonicalString(catalog.entryID, maximumLength: 160),
              let make = canonicalString(snapshot.car.make, maximumLength: 120),
              let model = canonicalString(snapshot.car.model, maximumLength: 120),
              let tireID = canonicalString(tire.id, maximumLength: 160),
              let tireName = canonicalString(tire.displayName, maximumLength: 120),
              let rulesetID = canonicalString(ruleset.id, maximumLength: 160),
              let algorithm = canonicalString(ruleset.algorithmVersion, maximumLength: 120),
              let knowledge = canonicalString(ruleset.knowledgeRevision, maximumLength: 160),
              let fields = appliedFields(in: tune, report: report) else {
            throw FH6CommunityReferenceTrialIssue.invalidStoredRecord
        }
        let vehicle = FirstPartyValidationRecord.Vehicle(
            catalogID: catalogID,
            year: year,
            make: make,
            model: model,
            performanceClass: snapshot.car.performanceClass,
            performanceIndex: snapshot.car.performanceIndex,
            drivetrain: snapshot.car.drivetrain,
            weightPounds: snapshot.car.weightPounds,
            frontWeightPercent: snapshot.car.frontWeightPercent,
            peakHorsepower: horsepower,
            peakTorqueFootPounds: torque,
            tireCompoundID: tireID,
            tireCompoundDisplayName: tireName,
            gearCount: gearCount,
            stock: true
        )
        let parts = snapshot.capabilityProfile.parts.map {
            FirstPartyValidationRecord.ShopPart(
                partID: $0.partID,
                availability: $0.availability
            )
        }.sorted { $0.partID.rawValue < $1.partID.rawValue }
        let publicRuleset = FirstPartyValidationRecord.Ruleset(
            id: rulesetID,
            schemaVersion: ruleset.schemaVersion,
            algorithmVersion: algorithm,
            knowledgeRevision: knowledge,
            validationStatus: ruleset.validationStatus
        )
        let payload = CandidateProofPayload(
            gameBuildVersion: canonicalBuild,
            vehicle: vehicle,
            shopParts: parts,
            discipline: tune.request.discipline,
            ruleset: publicRuleset,
            appliedFields: fields,
            tuneRevisionFingerprint: revision
        )
        return .init(
            gameBuildVersion: canonicalBuild,
            vehicle: vehicle,
            shopParts: parts,
            discipline: tune.request.discipline,
            ruleset: publicRuleset,
            appliedFields: fields,
            tuneRevisionFingerprint: revision,
            proofFingerprint: try hash(payload)
        )
    }

    private func validateCapture(
        _ capture: FH6CommunityReferenceTrialCapture
    ) throws {
        guard capture.runs.map(\.role) == FH6CommunityReferenceTrialRecord.requiredRoles else {
            throw FH6CommunityReferenceTrialIssue.invalidSequence
        }
        guard capture.runs.allSatisfy({ $0.completed && $0.correctTuneConfirmed }) else {
            throw FH6CommunityReferenceTrialIssue.incompleteRun
        }
        guard capture.attestations.sameRouteAndConditions else {
            throw FH6CommunityReferenceTrialIssue.conditionsNotHeldConstant
        }
        guard capture.attestations.sameAssistsAndInput else {
            throw FH6CommunityReferenceTrialIssue.assistsOrInputChanged
        }
        guard capture.attestations.candidateSettingsApplied else {
            throw FH6CommunityReferenceTrialIssue.candidateSettingsNotApplied
        }
        guard capture.attestations.communityIdentityConfirmed else {
            throw FH6CommunityReferenceTrialIssue.communityIdentityNotConfirmed
        }
        guard capture.attestations.finalCandidateRestored else {
            throw FH6CommunityReferenceTrialIssue.candidateNotRestored
        }
        guard capture.attestations.firstPartyAuthorship else {
            throw FH6CommunityReferenceTrialIssue.authorshipNotConfirmed
        }
        guard capture.attestations.localStoragePermitted else {
            throw FH6CommunityReferenceTrialIssue.localStorageNotPermitted
        }
        if capture.outcome == .referencePreferred {
            guard !capture.candidateDeficiencySymptoms.isEmpty else {
                throw FH6CommunityReferenceTrialIssue.missingCandidateDeficiency
            }
        } else if !capture.candidateDeficiencySymptoms.isEmpty {
            throw FH6CommunityReferenceTrialIssue.unexpectedCandidateDeficiency
        }
    }

    private func validateRecordProtocol(
        _ record: FH6CommunityReferenceTrialRecord
    ) -> Bool {
        guard record.runs.map(\.role) == FH6CommunityReferenceTrialRecord.requiredRoles,
              record.runs.allSatisfy({ $0.completed && $0.correctTuneConfirmed }),
              record.attestations.sameRouteAndConditions,
              record.attestations.sameAssistsAndInput,
              record.attestations.candidateSettingsApplied,
              record.attestations.communityIdentityConfirmed,
              record.attestations.finalCandidateRestored,
              record.attestations.firstPartyAuthorship,
              record.attestations.localStoragePermitted,
              record.candidateDeficiencySymptoms
                == record.candidateDeficiencySymptoms.sorted(by: { $0.rawValue < $1.rawValue }),
              Set(record.candidateDeficiencySymptoms).count
                == record.candidateDeficiencySymptoms.count else {
            return false
        }
        return (record.outcome == .referencePreferred
                && !record.candidateDeficiencySymptoms.isEmpty)
            || (record.outcome != .referencePreferred
                && record.candidateDeficiencySymptoms.isEmpty)
    }

    private func isValidSource(
        _ source: FH6CommunityReferenceSourceMetadata
    ) -> Bool {
        guard normalizedContentURL(
            source.canonicalContentURL,
            kind: source.kind
        ) == source.canonicalContentURL,
              canonicalString(source.publisherDisplayName, maximumLength: 120)
                == source.publisherDisplayName,
              canonicalString(source.sourceID, maximumLength: 160) == source.sourceID,
              canonicalOptionalString(source.derivativeOfSourceID, maximumLength: 160)
                == source.derivativeOfSourceID,
              source.derivativeOfSourceID != source.sourceID,
              source.usageScope == .metadataOnly,
              source.permissionBasis == .publicAvailability,
              isCanonicalFingerprint(source.publisherIdentityFingerprint),
              isCanonicalFingerprint(source.contentIdentityFingerprint) else {
            return false
        }
        let publisher = PublisherIdentityPayload(
            kind: source.kind,
            normalizedPublisherDisplayName: source.publisherDisplayName.lowercased()
        )
        let content = SourceIdentityPayload(
            kind: source.kind,
            canonicalContentURL: source.canonicalContentURL,
            sourceID: source.sourceID,
            derivativeOfSourceID: source.derivativeOfSourceID
        )
        return (try? hash(publisher)) == source.publisherIdentityFingerprint
            && (try? hash(content)) == source.contentIdentityFingerprint
    }

    private func isValidProof(
        _ proof: FH6CommunityReferenceCandidateProof
    ) -> Bool {
        let expectedParts = Set(TunePartID.allCases)
        guard canonicalString(proof.gameBuildVersion, maximumLength: 120)
                == proof.gameBuildVersion,
              canonicalString(proof.vehicle.catalogID, maximumLength: 160)
                == proof.vehicle.catalogID,
              canonicalString(proof.vehicle.make, maximumLength: 120) == proof.vehicle.make,
              canonicalString(proof.vehicle.model, maximumLength: 120) == proof.vehicle.model,
              canonicalString(proof.vehicle.tireCompoundID, maximumLength: 160)
                == proof.vehicle.tireCompoundID,
              canonicalString(proof.vehicle.tireCompoundDisplayName, maximumLength: 120)
                == proof.vehicle.tireCompoundDisplayName,
              proof.vehicle.stock,
              proof.shopParts.count == expectedParts.count,
              Set(proof.shopParts.map(\.partID)) == expectedParts,
              proof.shopParts == proof.shopParts.sorted(by: {
                  $0.partID.rawValue < $1.partID.rawValue
              }),
              proof.shopParts.allSatisfy({
                  $0.availability == .available || $0.availability == .unavailable
              }),
              canonicalString(proof.ruleset.id, maximumLength: 160) == proof.ruleset.id,
              canonicalString(proof.ruleset.algorithmVersion, maximumLength: 120)
                == proof.ruleset.algorithmVersion,
              canonicalString(proof.ruleset.knowledgeRevision, maximumLength: 160)
                == proof.ruleset.knowledgeRevision,
              proof.ruleset.schemaVersion > 0,
              proof.ruleset.validationStatus != .deprecated,
              !proof.appliedFields.isEmpty,
              Set(proof.appliedFields.map(\.field)).count == proof.appliedFields.count,
              proof.appliedFields == proof.appliedFields.sorted(by: {
                  $0.field.stableID < $1.field.stableID
              }),
              proof.appliedFields.allSatisfy({
                  $0.value.isFinite && $0.unit == $0.field.expectedUnit
              }),
              isCanonicalFingerprint(proof.tuneRevisionFingerprint),
              isCanonicalFingerprint(proof.proofFingerprint),
              candidateFingerprint(for: proof) != nil else {
            return false
        }
        let payload = CandidateProofPayload(
            gameBuildVersion: proof.gameBuildVersion,
            vehicle: proof.vehicle,
            shopParts: proof.shopParts,
            discipline: proof.discipline,
            ruleset: proof.ruleset,
            appliedFields: proof.appliedFields,
            tuneRevisionFingerprint: proof.tuneRevisionFingerprint
        )
        return (try? hash(payload)) == proof.proofFingerprint
    }

    private func semanticFingerprint(
        source: FH6CommunityReferenceSourceMetadata,
        candidateAssociation: FH6CommunityReferenceCandidateAssociation,
        context: FH6CommunityReferenceTrialContext,
        runs: [FH6CommunityReferenceTrialRun],
        outcome: FH6CommunityReferenceTrialOutcome,
        symptoms: [TuneFeedback],
        attestations: FH6CommunityReferenceTrialAttestations
    ) throws -> String {
        try hash(SemanticPayload(
            schemaVersion: FH6CommunityReferenceTrialRecord.currentSchemaVersion,
            consentVersion: FH6CommunityReferenceTrialRecord.currentConsentVersion,
            protocolVersion: FH6CommunityReferenceTrialRecord.currentProtocolVersion,
            game: .fh6,
            source: SemanticSource(
                kind: source.kind,
                canonicalContentURL: source.canonicalContentURL,
                publisherDisplayName: source.publisherDisplayName,
                sourceID: source.sourceID,
                publisherIdentityFingerprint: source.publisherIdentityFingerprint,
                contentIdentityFingerprint: source.contentIdentityFingerprint,
                derivativeOfSourceID: source.derivativeOfSourceID,
                usageScope: source.usageScope,
                permissionBasis: source.permissionBasis
            ),
            candidateAssociation: candidateAssociation,
            context: context,
            runs: runs,
            outcome: outcome,
            candidateDeficiencySymptoms: symptoms,
            attestations: SemanticAttestations(
                sameRouteAndConditions: attestations.sameRouteAndConditions,
                sameAssistsAndInput: attestations.sameAssistsAndInput,
                candidateSettingsApplied: attestations.candidateSettingsApplied,
                communityIdentityConfirmed: attestations.communityIdentityConfirmed,
                finalCandidateRestored: attestations.finalCandidateRestored,
                firstPartyAuthorship: attestations.firstPartyAuthorship,
                localStoragePermitted: attestations.localStoragePermitted
            ),
            consentScope: FH6CommunityReferenceTrialRecord.consentScope,
            unknowns: FH6CommunityReferenceTrialRecord.unknowns,
            privacyExclusions: FH6CommunityReferenceTrialRecord.privacyExclusions
        ))
    }

    private func appliedFields(
        in tune: TuneResult,
        report: TuneProjectionReport
    ) -> [FirstPartyValidationRecord.AppliedField]? {
        let lines = tune.sections.flatMap(\.lines)
        guard lines.count == report.readyCount else { return nil }
        var seen = Set<TuneFieldID>()
        var fields: [FirstPartyValidationRecord.AppliedField] = []
        for line in lines {
            guard let field = line.fieldID,
                  report.readyFieldIDs.contains(field),
                  seen.insert(field).inserted,
                  line.unit == field.expectedDisplayUnit,
                  let value = LocalizedNumberText.parse(line.value, locale: locale),
                  value.isFinite else {
                return nil
            }
            fields.append(.init(field: field, value: value, unit: field.expectedUnit))
        }
        guard Set(fields.map(\.field)) == report.readyFieldIDs else { return nil }
        return fields.sorted { $0.field.stableID < $1.field.stableID }
    }

    private func canonicalHost(
        _ host: String,
        for kind: FH6CommunityReferenceKind
    ) -> String? {
        switch kind {
        case .youtube:
            switch host {
            case "youtube.com", "www.youtube.com", "m.youtube.com":
                return "youtube.com"
            case "youtu.be":
                return "youtu.be"
            default:
                return nil
            }
        case .reddit:
            switch host {
            case "reddit.com", "www.reddit.com", "old.reddit.com", "new.reddit.com":
                return "reddit.com"
            case "redd.it":
                return "redd.it"
            default:
                return nil
            }
        }
    }

    private func isContentPermalink(
        _ components: URLComponents,
        kind: FH6CommunityReferenceKind
    ) -> Bool {
        guard let host = components.host else { return false }
        let segments = components.percentEncodedPath
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        switch (kind, host) {
        case (.youtube, "youtube.com"):
            guard components.percentEncodedPath == "/watch",
                  let items = components.queryItems,
                  items.count == 1,
                  items[0].name == "v",
                  let contentID = items[0].value else {
                return false
            }
            return isSafeToken(contentID, maximumLength: 128)
        case (.youtube, "youtu.be"):
            return components.queryItems == nil
                && segments.count == 1
                && isSafeToken(segments[0], maximumLength: 128)
        case (.reddit, "reddit.com"):
            guard components.queryItems == nil,
                  segments.count == 4 || segments.count == 5,
                  segments[0].lowercased() == "r",
                  segments[2].lowercased() == "comments",
                  isSafeToken(segments[1], maximumLength: 64),
                  isSafeToken(segments[3], maximumLength: 32) else {
                return false
            }
            return segments.count == 4
                || isSafeToken(segments[4], maximumLength: 200)
        case (.reddit, "redd.it"):
            return components.queryItems == nil
                && segments.count == 1
                && isSafeToken(segments[0], maximumLength: 32)
        default:
            return false
        }
    }

    private func isSafeToken(_ value: String, maximumLength: Int) -> Bool {
        (1...maximumLength).contains(value.count)
            && value.unicodeScalars.allSatisfy {
                CharacterSet.alphanumerics.contains($0)
                    || $0 == "_" || $0 == "-"
            }
    }

    private func isLocalOrIPAddress(_ host: String) -> Bool {
        if host == "localhost" || host.hasSuffix(".local") || host.contains(":") {
            return true
        }
        let pieces = host.split(separator: ".")
        return pieces.count == 4 && pieces.allSatisfy {
            guard let octet = Int($0) else { return false }
            return (0...255).contains(octet)
        }
    }

    private func isTrackingQueryName(_ name: String) -> Bool {
        let lowered = name.lowercased()
        return lowered.hasPrefix("utm_")
            || ["fbclid", "gclid", "si", "feature", "ref", "ref_source"].contains(lowered)
    }

    private func canonicalOptionalString(
        _ value: String?,
        maximumLength: Int
    ) -> String?? {
        guard let value else { return .some(nil) }
        guard let canonical = canonicalString(value, maximumLength: maximumLength) else {
            return nil
        }
        return .some(canonical)
    }

    private func canonicalString(
        _ value: String,
        maximumLength: Int
    ) -> String? {
        let forbiddenFormatScalars = CharacterSet(charactersIn:
            "\u{061C}\u{200B}\u{200C}\u{200D}\u{200E}\u{200F}\u{202A}\u{202B}\u{202C}\u{202D}\u{202E}\u{2060}\u{2061}\u{2062}\u{2063}\u{2064}\u{2066}\u{2067}\u{2068}\u{2069}\u{FEFF}"
        )
        let forbidden = CharacterSet.controlCharacters
            .union(.illegalCharacters)
            .union(.newlines)
            .union(forbiddenFormatScalars)
        guard !value.unicodeScalars.contains(where: {
            forbidden.contains($0) || $0.properties.generalCategory == .format
        }) else {
            return nil
        }
        let canonical = value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard (1...maximumLength).contains(canonical.count) else { return nil }
        return canonical
    }

    private func isCanonicalFingerprint(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy {
            $0.isNumber || ("a"..."f").contains(String($0))
        }
    }

    private func hash<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let digest = SHA256.hash(data: try encoder.encode(value))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private struct PublisherIdentityPayload: Codable {
        var kind: FH6CommunityReferenceKind
        var normalizedPublisherDisplayName: String
    }

    private struct SourceIdentityPayload: Codable {
        var kind: FH6CommunityReferenceKind
        var canonicalContentURL: String
        var sourceID: String
        var derivativeOfSourceID: String?
    }

    private struct SourceIDPayload: Codable {
        var kind: FH6CommunityReferenceKind
        var canonicalContentURL: String
    }

    private struct CandidateProofPayload: Codable {
        var gameBuildVersion: String
        var vehicle: FirstPartyValidationRecord.Vehicle
        var shopParts: [FirstPartyValidationRecord.ShopPart]
        var discipline: DrivingDiscipline
        var ruleset: FirstPartyValidationRecord.Ruleset
        var appliedFields: [FirstPartyValidationRecord.AppliedField]
        var tuneRevisionFingerprint: String
    }

    private struct CandidateIdentityPayload: Codable {
        var gameBuildVersion: String
        var vehicle: FirstPartyValidationRecord.Vehicle
        var shopParts: [FirstPartyValidationRecord.ShopPart]
        var discipline: DrivingDiscipline
        var ruleset: FirstPartyValidationRecord.Ruleset
        var appliedFields: [FirstPartyValidationRecord.AppliedField]
    }

    private struct SemanticSource: Codable {
        var kind: FH6CommunityReferenceKind
        var canonicalContentURL: String
        var publisherDisplayName: String
        var sourceID: String
        var publisherIdentityFingerprint: String
        var contentIdentityFingerprint: String
        var derivativeOfSourceID: String?
        var usageScope: FH6CommunityReferenceUsageScope
        var permissionBasis: FH6CommunityReferencePermissionBasis
    }

    private struct SemanticAttestations: Codable {
        var sameRouteAndConditions: Bool
        var sameAssistsAndInput: Bool
        var candidateSettingsApplied: Bool
        var communityIdentityConfirmed: Bool
        var finalCandidateRestored: Bool
        var firstPartyAuthorship: Bool
        var localStoragePermitted: Bool
    }

    private struct SemanticPayload: Codable {
        var schemaVersion: Int
        var consentVersion: String
        var protocolVersion: String
        var game: ForzaGame
        var source: SemanticSource
        var candidateAssociation: FH6CommunityReferenceCandidateAssociation
        var context: FH6CommunityReferenceTrialContext
        var runs: [FH6CommunityReferenceTrialRun]
        var outcome: FH6CommunityReferenceTrialOutcome
        var candidateDeficiencySymptoms: [TuneFeedback]
        var attestations: SemanticAttestations
        var consentScope: [String]
        var unknowns: [String]
        var privacyExclusions: [String]
    }
}
