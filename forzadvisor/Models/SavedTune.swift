//
//  SavedTune.swift
//  forzadvisor
//
//  SwiftData persistence model for garage entries. Stores searchable tune
//  metadata alongside the encoded TuneResult used by the tune detail screen.
//

import Foundation
import SwiftData

@Model
final class SavedTune {
    @Attribute(.unique) var id: UUID
    var carName: String
    var year: Int?
    var make: String = ""
    var model: String = ""
    var weightPounds: Int = 0
    var frontWeightPercent: Double = 0
    var disciplineRawValue: String
    var performanceClassRawValue: String
    var performanceIndex: Int
    var drivetrainRawValue: String
    var playerNotes: String = ""
    var generatedAt: Date
    var createdAt: Date
    var updatedAt: Date

    @Attribute(.externalStorage) private var tuneData: Data
    @Attribute(.externalStorage) var thumbnailData: Data?
    @Attribute(.externalStorage) private var firstPartyValidationRecordsData: Data? = nil
    @Attribute(.externalStorage) private var fh5ResearchObservationRecordsData: Data? = nil
    @Attribute(.externalStorage) private var fh5ResearchReviewEntriesData: Data? = nil
    @Attribute(.externalStorage) private var fh5ControlledExperimentRecordsData: Data? = nil
    @Attribute(.externalStorage) private var fh5CandidateOutcomeReviewEntriesData: Data? = nil
    @Attribute(.externalStorage) private var fh6ValidationReviewEntriesData: Data? = nil

    @MainActor
    init(
        tune: TuneResult,
        playerNotes: String = "",
        thumbnailData: Data? = nil,
        now: Date = .now
    ) throws {
        self.id = tune.id
        self.carName = tune.request.car.displayName
        self.year = tune.request.car.year
        self.make = tune.request.car.make
        self.model = tune.request.car.model
        self.weightPounds = tune.request.car.weightPounds
        self.frontWeightPercent = tune.request.car.frontWeightPercent
        self.disciplineRawValue = tune.request.discipline.rawValue
        self.performanceClassRawValue = tune.request.car.performanceClass.rawValue
        self.performanceIndex = tune.request.car.performanceIndex
        self.drivetrainRawValue = tune.request.car.drivetrain.rawValue
        self.playerNotes = playerNotes
        self.generatedAt = tune.generatedAt
        self.createdAt = now
        self.updatedAt = now
        self.tuneData = try Self.encoder.encode(tune)
        self.thumbnailData = thumbnailData
        self.firstPartyValidationRecordsData = nil
        self.fh5ResearchObservationRecordsData = nil
        self.fh5ResearchReviewEntriesData = nil
        self.fh5ControlledExperimentRecordsData = nil
        self.fh5CandidateOutcomeReviewEntriesData = nil
        self.fh6ValidationReviewEntriesData = nil
    }

    @MainActor
    var tuneResult: TuneResult? {
        try? Self.decoder.decode(TuneResult.self, from: tuneData)
    }

    var discipline: DrivingDiscipline? {
        DrivingDiscipline(rawValue: disciplineRawValue)
    }

    var disciplineTitle: String {
        discipline?.title ?? disciplineRawValue
    }

    var disciplineSymbolName: String {
        discipline?.symbolName ?? "wrench.adjustable"
    }

    @MainActor
    var carInput: CarInput? {
        if let storedCar = tuneResult?.request.car {
            return storedCar
        }

        guard let performanceClass = PerformanceClass(rawValue: performanceClassRawValue),
              let drivetrain = Drivetrain(rawValue: drivetrainRawValue)
        else { return nil }

        return CarInput(
            game: .fh6,
            year: year,
            make: make,
            model: model,
            weightPounds: weightPounds,
            frontWeightPercent: frontWeightPercent,
            performanceIndex: performanceIndex,
            performanceClass: performanceClass,
            drivetrain: drivetrain,
            peakHorsepower: tuneResult?.request.car.peakHorsepower,
            peakTorqueFootPounds: tuneResult?.request.car.peakTorqueFootPounds
        )
    }

    @MainActor
    func update(
        with tune: TuneResult,
        playerNotes: String? = nil,
        thumbnailData: Data? = nil,
        now: Date = .now
    ) throws {
        carName = tune.request.car.displayName
        year = tune.request.car.year
        make = tune.request.car.make
        model = tune.request.car.model
        weightPounds = tune.request.car.weightPounds
        frontWeightPercent = tune.request.car.frontWeightPercent
        disciplineRawValue = tune.request.discipline.rawValue
        performanceClassRawValue = tune.request.car.performanceClass.rawValue
        performanceIndex = tune.request.car.performanceIndex
        drivetrainRawValue = tune.request.car.drivetrain.rawValue
        if let playerNotes {
            self.playerNotes = playerNotes
        }
        generatedAt = tune.generatedAt
        updatedAt = now
        tuneData = try Self.encoder.encode(tune)
        if let thumbnailData {
            self.thumbnailData = thumbnailData
        }
    }

    @MainActor
    var firstPartyValidationRecords: [FirstPartyValidationRecord] {
        (try? decodedValidationRecords()) ?? []
    }

    @MainActor
    func validationRecords(matching tune: TuneResult) -> [FirstPartyValidationRecord] {
        guard let fingerprint = FirstPartyValidationRecordFactory().revisionFingerprint(for: tune) else {
            return []
        }
        return firstPartyValidationRecords
            .filter {
                $0.tuneRevisionFingerprint == fingerprint
                    && FirstPartyValidationRecordFactory().isValid($0)
            }
            .sorted { $0.createdAt < $1.createdAt }
    }

    @MainActor
    func betaValidationEvidenceSnapshot(
        matching tune: TuneResult
    ) throws -> SavedTuneBetaValidationEvidenceSnapshot {
        let validationFactory = FirstPartyValidationRecordFactory()
        let validationFingerprint = validationFactory.revisionFingerprint(for: tune)
        let validationRecords = try decodedValidationRecords()
            .filter {
                validationFingerprint != nil
                    && $0.tuneRevisionFingerprint == validationFingerprint
            }
            .sorted { $0.createdAt < $1.createdAt }

        let researchFactory = FH5ResearchObservationFactory()
        guard let currentTune = tuneResult,
              researchFactory.planRevisionFingerprint(for: currentTune)
                == researchFactory.planRevisionFingerprint(for: tune) else {
            return SavedTuneBetaValidationEvidenceSnapshot(
                validationRecordCount: validationRecords.count,
                fh5ResearchObservationCount: 0,
                fh5ResearchReviewCount: 0,
                fh5ControlledExperimentCount: 0
            )
        }
        let researchRecords = try decodedFH5ResearchObservationRecords()
            .filter { researchFactory.matches($0, tune: currentTune) }
        let reviewIngestor = FH5ResearchReviewIngestor()
        let reviewEntries = try decodedFH5ResearchReviewEntries()
            .filter { entry in
                guard let validated = try? reviewIngestor.validate(
                    entry.canonicalExportJSON
                ) else {
                    return false
                }
                return reviewIngestor.matchesSavedPlan(validated, tune: currentTune)
            }
        let researchRecord = researchRecords.max { $0.capturedAt < $1.capturedAt }
        let experimentFactory = FH5ControlledExperimentFactory()
        let experimentRecords = try decodedFH5ControlledExperimentRecords()
            .filter { record in
                guard let researchRecord else { return false }
                return experimentFactory.matches(
                    record,
                    tune: currentTune,
                    researchRecord: researchRecord
                )
            }

        return SavedTuneBetaValidationEvidenceSnapshot(
            validationRecordCount: validationRecords.count,
            fh5ResearchObservationCount: researchRecords.count,
            fh5ResearchReviewCount: reviewEntries.count,
            fh5ControlledExperimentCount: experimentRecords.count
        )
    }

    @MainActor
    func appendValidationRecord(_ record: FirstPartyValidationRecord) throws {
        guard FirstPartyValidationRecordFactory().isValid(record) else {
            throw FirstPartyValidationError.invalidStoredRecord
        }
        var records = try decodedValidationRecords()
        guard !records.contains(where: { $0.recordID == record.recordID }) else { return }
        records.append(record)
        firstPartyValidationRecordsData = try Self.encoder.encode(records)
        updatedAt = .now
    }

    @MainActor
    @discardableResult
    func deleteValidationRecord(id: UUID) throws -> Bool {
        var records = try decodedValidationRecords()
        let priorCount = records.count
        records.removeAll { $0.recordID == id }
        guard records.count != priorCount else { return false }
        firstPartyValidationRecordsData = records.isEmpty ? nil : try Self.encoder.encode(records)
        updatedAt = .now
        return true
    }

    @MainActor
    var fh5ResearchObservationRecords: [FH5ResearchObservationRecord] {
        (try? decodedFH5ResearchObservationRecords()) ?? []
    }

    @MainActor
    func fh5ResearchObservationRecords(
        matching tune: TuneResult
    ) -> [FH5ResearchObservationRecord] {
        let factory = FH5ResearchObservationFactory()
        guard let currentTune = tuneResult,
              factory.planRevisionFingerprint(for: currentTune)
                == factory.planRevisionFingerprint(for: tune) else {
            return []
        }
        return fh5ResearchObservationRecords
            .filter { factory.matches($0, tune: currentTune) }
            .sorted { $0.capturedAt < $1.capturedAt }
    }

    @MainActor
    func appendFH5ResearchObservationRecord(
        _ record: FH5ResearchObservationRecord
    ) throws {
        guard let currentTune = tuneResult,
              FH5ResearchObservationFactory().matches(record, tune: currentTune) else {
            throw FH5ResearchIssue.invalidStoredRecord
        }
        var records = try decodedFH5ResearchObservationRecords()
        guard !records.contains(where: {
            $0.recordID == record.recordID
                || $0.contentFingerprint == record.contentFingerprint
        }) else {
            return
        }
        records.append(record)
        fh5ResearchObservationRecordsData = try Self.encoder.encode(records)
        updatedAt = .now
    }

    @MainActor
    @discardableResult
    func deleteFH5ResearchObservationRecord(id: UUID) throws -> Bool {
        var records = try decodedFH5ResearchObservationRecords()
        let priorCount = records.count
        records.removeAll { $0.recordID == id }
        guard records.count != priorCount else { return false }
        fh5ResearchObservationRecordsData = records.isEmpty
            ? nil
            : try Self.encoder.encode(records)
        updatedAt = .now
        return true
    }

    @MainActor
    var fh5ResearchReviewEntries: [FH5ResearchReviewEntry] {
        (try? decodedFH5ResearchReviewEntries()) ?? []
    }

    @MainActor
    func fh5ResearchReviewEntries(
        matching tune: TuneResult
    ) -> [FH5ResearchReviewEntry] {
        let factory = FH5ResearchObservationFactory()
        guard let currentTune = tuneResult,
              let currentRevision = factory.planRevisionFingerprint(for: currentTune),
              currentRevision == factory.planRevisionFingerprint(for: tune) else {
            return []
        }
        let ingestor = FH5ResearchReviewIngestor()
        return fh5ResearchReviewEntries.filter { entry in
            guard let validated = try? ingestor.validate(entry.canonicalExportJSON) else {
                return false
            }
            return ingestor.matchesSavedPlan(validated, tune: currentTune)
        }
    }

    @MainActor
    func fh5ResearchReviewReport(
        matching tune: TuneResult
    ) -> FH5ResearchReviewReport {
        let matchingEntries = fh5ResearchReviewEntries(matching: tune)
        return FH5ResearchReviewEvaluator().evaluate(
            matchingEntries.map { entry in
                FH5ResearchReviewInput(entry: entry)
            }
        )
    }

    @MainActor
    func appendFH5ResearchReviewEntry(_ entry: FH5ResearchReviewEntry) throws {
        guard entry.schemaVersion == FH5ResearchReviewEntry.currentSchemaVersion,
              let currentTune = tuneResult else {
            throw FH5ResearchReviewError.planMismatch
        }
        guard entry.hasConsistentLocalReviewTimestamp else {
            throw FH5ResearchReviewError.permissionNotConfirmed
        }
        let ingestor = FH5ResearchReviewIngestor()
        let validated = try ingestor.validate(entry.canonicalExportJSON)
        guard ingestor.matchesSavedPlan(validated, tune: currentTune) else {
            throw FH5ResearchReviewError.planMismatch
        }
        let bindingReport = FH5ResearchReviewEvaluator().evaluate([
            FH5ResearchReviewInput(entry: entry)
        ])
        guard bindingReport.verifiedUniqueObservationCount == 1,
              bindingReport.quarantinedCount == 0 else {
            throw FH5ResearchReviewError.permissionNotConfirmed
        }

        var entries = try decodedFH5ResearchReviewEntries()
        guard !entries.contains(where: {
            $0.id == entry.id
                || $0.permission.canonicalExportDigest
                    == entry.permission.canonicalExportDigest
        }) else {
            return
        }
        entries.append(entry)
        fh5ResearchReviewEntriesData = try Self.encoder.encode(entries)
        updatedAt = .now
    }

    @MainActor
    @discardableResult
    func deleteFH5ResearchReviewEntry(id: UUID) throws -> Bool {
        var entries = try decodedFH5ResearchReviewEntries()
        let priorCount = entries.count
        entries.removeAll { $0.id == id }
        guard entries.count != priorCount else { return false }
        fh5ResearchReviewEntriesData = entries.isEmpty
            ? nil
            : try Self.encoder.encode(entries)
        updatedAt = .now
        return true
    }

    @MainActor
    var fh5ControlledExperimentRecords: [FH5ControlledExperimentRecord] {
        (try? decodedFH5ControlledExperimentRecords()) ?? []
    }

    @MainActor
    func fh5ControlledExperimentRecords(
        matching tune: TuneResult,
        researchRecord: FH5ResearchObservationRecord?
    ) -> [FH5ControlledExperimentRecord] {
        let researchFactory = FH5ResearchObservationFactory()
        guard let currentTune = tuneResult,
              researchFactory.planRevisionFingerprint(for: currentTune)
                == researchFactory.planRevisionFingerprint(for: tune),
              let researchRecord else {
            return []
        }
        let factory = FH5ControlledExperimentFactory()
        return fh5ControlledExperimentRecords
            .filter {
                factory.matches(
                    $0,
                    tune: currentTune,
                    researchRecord: researchRecord
                )
            }
            .sorted { $0.createdAt < $1.createdAt }
    }

    @MainActor
    func appendFH5ControlledExperimentRecord(
        _ record: FH5ControlledExperimentRecord
    ) throws {
        guard let currentTune = tuneResult else {
            throw FH5ControlledExperimentIssue.staleSavedRevision
        }
        let researchRecords = fh5ResearchObservationRecords(matching: currentTune)
        guard let researchRecord = researchRecords.last,
              FH5ControlledExperimentFactory().matches(
                record,
                tune: currentTune,
                researchRecord: researchRecord
              ) else {
            throw FH5ControlledExperimentIssue.invalidStoredRecord
        }
        var records = try decodedFH5ControlledExperimentRecords()
        guard !records.contains(where: {
            $0.recordID == record.recordID
                || $0.contentFingerprint == record.contentFingerprint
        }) else {
            return
        }
        records.append(record)
        fh5ControlledExperimentRecordsData = try Self.encoder.encode(records)
        updatedAt = .now
    }

    @MainActor
    @discardableResult
    func deleteFH5ControlledExperimentRecord(id: UUID) throws -> Bool {
        var records = try decodedFH5ControlledExperimentRecords()
        let priorCount = records.count
        records.removeAll { $0.recordID == id }
        guard records.count != priorCount else { return false }
        fh5ControlledExperimentRecordsData = records.isEmpty
            ? nil
            : try Self.encoder.encode(records)
        updatedAt = .now
        return true
    }

    @MainActor
    var fh5CandidateOutcomeReviewEntries:
        [FH5CandidateOutcomeReviewEntry] {
        (try? decodedFH5CandidateOutcomeReviewEntries()) ?? []
    }

    @MainActor
    func allFH5CandidateOutcomeReviewEntries()
        throws -> [FH5CandidateOutcomeReviewEntry] {
        try decodedFH5CandidateOutcomeReviewEntries()
            .sorted {
                if $0.importedAt != $1.importedAt {
                    return $0.importedAt < $1.importedAt
                }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    @MainActor
    func fh5CandidateOutcomeReviewEntries(
        matching artifact: FH5GeneratedCandidateArtifact
    ) throws -> [FH5CandidateOutcomeReviewEntry] {
        let exchange = FH5CandidateOutcomeExchange()
        let associationFingerprint = try exchange
            .associationFingerprint(for: artifact)
        return try decodedFH5CandidateOutcomeReviewEntries()
            .filter {
                $0.permission.associationFingerprint
                    == associationFingerprint
            }
            .sorted {
                if $0.importedAt != $1.importedAt {
                    return $0.importedAt < $1.importedAt
                }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    @MainActor
    func fh5CandidateOutcomeCollectionReport(
        matching artifact: FH5GeneratedCandidateArtifact
    ) throws -> FH5CandidateOutcomeCollectionReport {
        let exchange = FH5CandidateOutcomeExchange()
        let associationFingerprint = try exchange
            .associationFingerprint(for: artifact)
        return FH5CandidateOutcomeCollectionEvaluator().evaluate(
            localRecords: try decodedFH5ControlledExperimentRecords(),
            reviewedEntries:
                try decodedFH5CandidateOutcomeReviewEntries(),
            matchingAssociationFingerprint: associationFingerprint
        )
    }

    @MainActor
    func appendFH5CandidateOutcomeReviewEntry(
        _ entry: FH5CandidateOutcomeReviewEntry
    ) throws {
        let exchange = FH5CandidateOutcomeExchange()
        guard exchange.isValidReviewEntry(entry),
              let validated = try? exchange.validate(
                entry.canonicalExportJSON
              ),
              let currentTune = tuneResult else {
            throw FH5CandidateOutcomeExchangeError
                .candidateMismatch
        }
        let association = validated.export.association
        let researchRecords = fh5ResearchObservationRecords(
            matching: currentTune
        )
        let reviewInputs = fh5ResearchReviewEntries(
            matching: currentTune
        ).map { FH5ResearchReviewInput(entry: $0) }
        let freshArtifact: FH5GeneratedCandidateArtifact
        do {
            freshArtifact = try FH5CandidateTrialCoordinator()
                .generate(
                    tune: currentTune,
                    savedTune: currentTune,
                    isStreaming: false,
                    researchRecords: researchRecords,
                    reviewInputs: reviewInputs,
                    input: association.context.input,
                    surface: association.context.surface
                )
        } catch {
            throw FH5CandidateOutcomeExchangeError
                .candidateMismatch
        }
        guard try exchange.matches(
            validated,
            locallyRegeneratedArtifact: freshArtifact
        ) else {
            throw FH5CandidateOutcomeExchangeError
                .candidateMismatch
        }
        let oneEntryReport = FH5CandidateOutcomeCollectionEvaluator()
            .evaluate(
                localRecords: [],
                reviewedEntries: [entry],
                matchingAssociationFingerprint:
                    validated.export.associationFingerprint
            )
        guard oneEntryReport.verifiedUniqueSessionCount == 1,
              oneEntryReport.quarantinedCount == 0 else {
            throw FH5CandidateOutcomeExchangeError
                .permissionNotConfirmed
        }

        var entries = try decodedFH5CandidateOutcomeReviewEntries()
        guard !entries.contains(where: {
            $0.id == entry.id
                || $0.permission.canonicalExportDigest
                    == entry.permission.canonicalExportDigest
        }) else {
            return
        }
        entries.append(entry)
        fh5CandidateOutcomeReviewEntriesData =
            try Self.encoder.encode(entries)
        updatedAt = .now
    }

    @MainActor
    @discardableResult
    func deleteFH5CandidateOutcomeReviewEntry(
        id: UUID
    ) throws -> Bool {
        var entries = try decodedFH5CandidateOutcomeReviewEntries()
        let priorCount = entries.count
        entries.removeAll { $0.id == id }
        guard entries.count != priorCount else { return false }
        fh5CandidateOutcomeReviewEntriesData = entries.isEmpty
            ? nil
            : try Self.encoder.encode(entries)
        updatedAt = .now
        return true
    }

    @MainActor
    func fh6ValidationReviewEntries(
        matching tune: TuneResult
    ) throws -> [FH6ValidationReviewEntry] {
        guard let currentTune = tuneResult else {
            throw FH6ValidationReviewError.tuneMismatch
        }
        let ingestor = FH6ValidationReviewIngestor()
        return try decodedFH6ValidationReviewEntries()
            .filter { entry in
                guard let validated = try? ingestor.validate(entry.canonicalExportJSON) else {
                    return false
                }
                return ingestor.matchesSavedTune(validated, tune: currentTune)
                    && ingestor.matchesSavedTune(validated, tune: tune)
            }
            .sorted {
                if $0.importedAt != $1.importedAt {
                    return $0.importedAt < $1.importedAt
                }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    @MainActor
    func fh6ValidationReviewReport(
        matching tune: TuneResult
    ) throws -> FH6ValidationReviewReport {
        try FH6ValidationReviewEvaluator().evaluate(
            fh6ValidationReviewEntries(matching: tune)
        )
    }

    @MainActor
    func appendFH6ValidationReviewEntry(
        _ entry: FH6ValidationReviewEntry
    ) throws {
        guard entry.schemaVersion == FH6ValidationReviewEntry.currentSchemaVersion,
              let currentTune = tuneResult else {
            throw FH6ValidationReviewError.tuneMismatch
        }
        guard entry.hasConsistentLocalReviewTimestamp else {
            throw FH6ValidationReviewError.permissionNotConfirmed
        }

        let ingestor = FH6ValidationReviewIngestor()
        let validated = try ingestor.validate(entry.canonicalExportJSON)
        guard ingestor.matchesSavedTune(validated, tune: currentTune) else {
            throw FH6ValidationReviewError.tuneMismatch
        }
        let bindingReport = FH6ValidationReviewEvaluator().evaluate([entry])
        guard bindingReport.verifiedUniqueSessionCount == 1,
              bindingReport.quarantinedCount == 0,
              bindingReport.invalidCount == 0 else {
            throw FH6ValidationReviewError.permissionNotConfirmed
        }

        var entries = try decodedFH6ValidationReviewEntries()
        guard !entries.contains(where: {
            $0.id == entry.id
                || $0.permission.canonicalExportDigest
                    == entry.permission.canonicalExportDigest
        }) else {
            return
        }
        entries.append(entry)
        fh6ValidationReviewEntriesData = try Self.encoder.encode(entries)
        updatedAt = .now
    }

    @MainActor
    @discardableResult
    func deleteFH6ValidationReviewEntry(id: UUID) throws -> Bool {
        var entries = try decodedFH6ValidationReviewEntries()
        let priorCount = entries.count
        entries.removeAll { $0.id == id }
        guard entries.count != priorCount else { return false }
        fh6ValidationReviewEntriesData = entries.isEmpty
            ? nil
            : try Self.encoder.encode(entries)
        updatedAt = .now
        return true
    }

    @MainActor
    private func decodedValidationRecords() throws -> [FirstPartyValidationRecord] {
        guard let firstPartyValidationRecordsData else { return [] }
        do {
            let records = try Self.decoder.decode(
                [FirstPartyValidationRecord].self,
                from: firstPartyValidationRecordsData
            )
            guard records.allSatisfy(FirstPartyValidationRecordFactory().isValid)
            else {
                throw SavedTuneValidationRecordError.corruptStorage
            }
            return records
        } catch {
            throw SavedTuneValidationRecordError.corruptStorage
        }
    }

    @MainActor
    private func decodedFH5ResearchObservationRecords() throws
        -> [FH5ResearchObservationRecord] {
        guard let fh5ResearchObservationRecordsData else { return [] }
        do {
            let records = try Self.decoder.decode(
                [FH5ResearchObservationRecord].self,
                from: fh5ResearchObservationRecordsData
            )
            guard records.allSatisfy(FH5ResearchObservationFactory().isValid) else {
                throw SavedTuneFH5ResearchRecordError.corruptStorage
            }
            return records
        } catch {
            throw SavedTuneFH5ResearchRecordError.corruptStorage
        }
    }

    @MainActor
    private func decodedFH5ResearchReviewEntries() throws
        -> [FH5ResearchReviewEntry] {
        guard let fh5ResearchReviewEntriesData else { return [] }
        do {
            let entries = try Self.decoder.decode(
                [FH5ResearchReviewEntry].self,
                from: fh5ResearchReviewEntriesData
            )
            let ingestor = FH5ResearchReviewIngestor()
            guard entries.allSatisfy({ entry in
                guard entry.schemaVersion == FH5ResearchReviewEntry.currentSchemaVersion,
                      entry.hasConsistentLocalReviewTimestamp,
                      let validated = try? ingestor.validate(entry.canonicalExportJSON) else {
                    return false
                }
                return entry.permission.submissionID == validated.export.submissionID
                    && entry.permission.permissionReceiptID
                        == validated.export.permissionReceiptID
                    && entry.permission.consentVersion == validated.export.consentVersion
                    && entry.permission.canonicalExportDigest
                        == validated.canonicalExportDigest
                    && entry.permission.contentFingerprint
                        == validated.export.contentFingerprint
            }) else {
                throw FH5ResearchReviewError.corruptStorage
            }
            return entries
        } catch {
            throw FH5ResearchReviewError.corruptStorage
        }
    }

    @MainActor
    private func decodedFH5ControlledExperimentRecords() throws
        -> [FH5ControlledExperimentRecord] {
        guard let fh5ControlledExperimentRecordsData else { return [] }
        do {
            let records = try Self.decoder.decode(
                [FH5ControlledExperimentRecord].self,
                from: fh5ControlledExperimentRecordsData
            )
            guard records.allSatisfy(FH5ControlledExperimentFactory().isValid)
            else {
                throw SavedTuneFH5ControlledExperimentError.corruptStorage
            }
            return records
        } catch {
            throw SavedTuneFH5ControlledExperimentError.corruptStorage
        }
    }

    @MainActor
    private func decodedFH5CandidateOutcomeReviewEntries() throws
        -> [FH5CandidateOutcomeReviewEntry] {
        guard let fh5CandidateOutcomeReviewEntriesData else {
            return []
        }
        do {
            let entries = try Self.decoder.decode(
                [FH5CandidateOutcomeReviewEntry].self,
                from: fh5CandidateOutcomeReviewEntriesData
            )
            guard entries.allSatisfy(
                FH5CandidateOutcomeExchange()
                    .isValidReviewEntry
            ) else {
                throw FH5CandidateOutcomeExchangeError
                    .corruptStorage
            }
            return entries
        } catch {
            throw FH5CandidateOutcomeExchangeError.corruptStorage
        }
    }

    @MainActor
    private func decodedFH6ValidationReviewEntries() throws
        -> [FH6ValidationReviewEntry] {
        guard let fh6ValidationReviewEntriesData else { return [] }
        do {
            let entries = try Self.decoder.decode(
                [FH6ValidationReviewEntry].self,
                from: fh6ValidationReviewEntriesData
            )
            let ingestor = FH6ValidationReviewIngestor()
            guard entries.allSatisfy({ entry in
                guard entry.schemaVersion == FH6ValidationReviewEntry.currentSchemaVersion,
                      entry.hasConsistentLocalReviewTimestamp,
                      let validated = try? ingestor.validate(
                          entry.canonicalExportJSON
                      ) else {
                    return false
                }
                return entry.permission.submissionID == validated.export.submissionID
                    && entry.permission.permissionReceiptID
                        == validated.export.permissionReceiptID
                    && entry.permission.consentVersion == validated.export.consentVersion
                    && entry.permission.canonicalExportDigest
                        == validated.canonicalExportDigest
                    && entry.permission.contentFingerprint
                        == validated.export.contentFingerprint
            }) else {
                throw FH6ValidationReviewError.corruptStorage
            }
            return entries
        } catch {
            throw FH6ValidationReviewError.corruptStorage
        }
    }

#if DEBUG
    @MainActor
    func replaceTuneDataForTesting(_ data: Data) {
        tuneData = data
    }

    @MainActor
    func replaceValidationRecordsDataForTesting(_ data: Data?) {
        firstPartyValidationRecordsData = data
    }

    @MainActor
    func replaceFH5ResearchObservationRecordsDataForTesting(_ data: Data?) {
        fh5ResearchObservationRecordsData = data
    }

    @MainActor
    func replaceFH5ResearchReviewEntriesDataForTesting(_ data: Data?) {
        fh5ResearchReviewEntriesData = data
    }

    @MainActor
    func replaceFH5ControlledExperimentRecordsDataForTesting(_ data: Data?) {
        fh5ControlledExperimentRecordsData = data
    }

    @MainActor
    func replaceFH5CandidateOutcomeReviewEntriesDataForTesting(
        _ data: Data?
    ) {
        fh5CandidateOutcomeReviewEntriesData = data
    }

    @MainActor
    func replaceFH6ValidationReviewEntriesDataForTesting(_ data: Data?) {
        fh6ValidationReviewEntriesData = data
    }
#endif

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

struct SavedTuneBetaValidationEvidenceSnapshot: Equatable, Sendable {
    let validationRecordCount: Int
    let fh5ResearchObservationCount: Int
    let fh5ResearchReviewCount: Int
    let fh5ControlledExperimentCount: Int

    var totalRecordCount: Int {
        validationRecordCount
            + fh5ResearchObservationCount
            + fh5ResearchReviewCount
            + fh5ControlledExperimentCount
    }
}

enum SavedTuneValidationRecordError: LocalizedError, Equatable {
    case corruptStorage

    var errorDescription: String? {
        "Stored validation records are corrupt. No records were changed."
    }
}

enum SavedTuneFH5ResearchRecordError: LocalizedError, Equatable {
    case corruptStorage

    var errorDescription: String? {
        "Stored FH5 research observations are corrupt. The plan and other evidence were not changed."
    }
}

enum SavedTuneFH5ControlledExperimentError: LocalizedError, Equatable {
    case corruptStorage

    var errorDescription: String? {
        "Stored FH5 controlled experiments are corrupt. The plan and other evidence were not changed."
    }
}
