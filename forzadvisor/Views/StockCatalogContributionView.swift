//
//  StockCatalogContributionView.swift
//  forzadvisor
//
//  Local capture and review workspace for first-party stock catalog facts.
//

import SwiftUI

struct StockCatalogContributionView: View {
    private let store: StockCatalogContributionStore

    @State private var snapshot:
        StockCatalogContributionStoreSnapshot = .empty
    @State private var game: ForzaGame
    @State private var gameVersion = ""
    @State private var platform:
        StockContributionPlatform = .xboxSeries
    @State private var year = ""
    @State private var make = ""
    @State private var model = ""
    @State private var performanceIndex = ""
    @State private var performanceClass: PerformanceClass = .a
    @State private var drivetrain: Drivetrain = .awd
    @State private var weightPounds = ""
    @State private var frontWeightPercent = ""
    @State private var peakHorsepower = ""
    @State private var peakTorque = ""
    @State private var observationScreens:
        [CatalogDataField: StockContributionObservationScreen] = [:]
    @State private var captureConfirmations =
        StockCatalogCaptureConfirmationState()
    @State private var pastedJSON = ""
    @State private var reviewConfirmations =
        StockCatalogReviewConfirmationState()
    @State private var statusMessage: String?

    init(
        initialGame: ForzaGame = .fh6,
        store: StockCatalogContributionStore = .init()
    ) {
        self.store = store
        _game = State(initialValue: initialGame)
    }

    var body: some View {
        Form {
            Section {
                ForzAdvisorScreenHeader(
                    title: "Stock Catalog Contribution",
                    subtitle:
                        "Record first-party untouched-stock facts for later human review.",
                    systemImage: "car.badge.gearshape",
                    tint: ForzAdvisorTheme.warmAccent
                )
            }
            .listRowBackground(ForzAdvisorTheme.heroRowBackground)

            identitySection
            stockSection
            fieldAttestationSection
            capturePermissionSection
            capturedSection
            importSection
            reviewedSection

            Section("Collection-Only Boundary") {
                Text(
                    StockCatalogContributionPolicy.collectionBoundary
                )
                .font(.caption)
                Text(
                    StockCatalogContributionPolicy.permissionBoundary
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .forzAdvisorRowBackground()

            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(
                            "stockContributionStatus"
                        )
                }
                .forzAdvisorRowBackground()
            }
        }
        .navigationTitle("Expand the Catalog")
        .forzAdvisorScreenChrome()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ModalCopilotToolbarLink(
                    destination: .stockCatalogContribution
                )
            }
        }
        .accessibilityIdentifier("stockCatalogContribution")
        .onChange(of: captureDraftFingerprint) { previous, current in
            captureConfirmations.invalidateIfDraftChanged(
                from: previous,
                to: current
            )
        }
        .onChange(of: pastedJSON) { previous, current in
            reviewConfirmations.invalidateIfPayloadChanged(
                from: previous,
                to: current
            )
        }
        .task {
            snapshot = store.load()
            if snapshot.recoveredFromMalformedData {
                statusMessage =
                    "Stored contribution data was unreadable and was excluded. The bundled catalog and tunes were unchanged."
            }
            for field in StockCatalogContributionValidator
                .expectedFields where observationScreens[field] == nil {
                observationScreens[field] = defaultScreen(for: field)
            }
        }
    }

    private var identitySection: some View {
        Section("Exact Game And Car Identity") {
            Picker("Game", selection: $game) {
                ForEach(ForzaGame.allCases) {
                    Text($0.shortTitle).tag($0)
                }
            }
            Picker("Platform", selection: $platform) {
                ForEach(StockContributionPlatform.allCases) {
                    Text($0.rawValue).tag($0)
                }
            }
            TextField("Exact game version/build", text: $gameVersion)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Year", text: $year)
                .keyboardType(.numberPad)
            TextField("Make", text: $make)
            TextField("Model", text: $model)
        }
        .forzAdvisorRowBackground()
    }

    private var stockSection: some View {
        Section("Untouched Stock Specifications") {
            Picker("Class", selection: $performanceClass) {
                ForEach(game.supportedPerformanceClasses) {
                    Text($0.rawValue).tag($0)
                }
            }
            TextField("Performance index", text: $performanceIndex)
                .keyboardType(.numberPad)
            Picker("Drivetrain", selection: $drivetrain) {
                ForEach(Drivetrain.allCases) {
                    Text($0.rawValue).tag($0)
                }
            }
            TextField("Weight (lb)", text: $weightPounds)
                .keyboardType(.numberPad)
            TextField(
                "Front weight (%)",
                text: $frontWeightPercent
            )
            .keyboardType(.decimalPad)
            TextField("Peak horsepower", text: $peakHorsepower)
                .keyboardType(.numberPad)
            TextField("Peak torque (lb-ft)", text: $peakTorque)
                .keyboardType(.numberPad)
        }
        .forzAdvisorRowBackground()
    }

    private var fieldAttestationSection: some View {
        Section("Complete Field Observation") {
            Text(
                "Choose the in-game screen personally used for every required field. Saving stamps one direct, untouched-stock observation per field in this capture session."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            ForEach(
                StockCatalogContributionValidator.expectedFields,
                id: \.rawValue
            ) { field in
                Picker(
                    fieldTitle(field),
                    selection: Binding(
                        get: {
                            observationScreens[field]
                                ?? defaultScreen(for: field)
                        },
                        set: { observationScreens[field] = $0 }
                    )
                ) {
                    ForEach(
                        StockContributionObservationScreen.allCases
                    ) {
                        Text($0.rawValue).tag($0)
                    }
                }
            }
        }
        .forzAdvisorRowBackground()
    }

    private var capturePermissionSection: some View {
        Section("Capture And Rights") {
            Toggle(
                "Exact untouched stock confirmed",
                isOn: $captureConfirmations.exactStockConfirmed
            )
            Toggle(
                "Personally read directly from the game",
                isOn: $captureConfirmations.personallyReadConfirmed
            )
            Toggle(
                "English units confirmed where relevant",
                isOn: $captureConfirmations.englishUnitsConfirmed
            )
            Toggle(
                "I authored these structured facts",
                isOn: $captureConfirmations.authorshipConfirmed
            )
            Toggle(
                "Allow local storage",
                isOn: $captureConfirmations.localStorageConfirmed
            )
            Divider()
            Text(
                "All reuse rights default off. All four are required before a canonical export can leave this device."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            Toggle(
                "Tester-authored structured facts",
                isOn: $captureConfirmations.testerFactsRight
            )
            Toggle(
                "Deidentified structured reuse",
                isOn: $captureConfirmations.reuseRight
            )
            Toggle(
                "Catalog curation use",
                isOn: $captureConfirmations.curationRight
            )
            Toggle(
                "Future bundled redistribution",
                isOn: $captureConfirmations.redistributionRight
            )
            Text(
                StockCatalogContributionPolicy.permissionBoundary
            )
            .font(.caption)
            Button("Save Local Contribution") {
                saveContribution()
            }
            .accessibilityIdentifier("saveStockContribution")
        }
        .forzAdvisorRowBackground()
    }

    private var capturedSection: some View {
        Section("Local Contributions") {
            if snapshot.captured.isEmpty {
                Text("No local contributions.")
                    .foregroundStyle(.secondary)
            }
            ForEach(snapshot.captured) { record in
                CapturedStockContributionRow(
                    record: record,
                    onDelete: { deleteCaptured(record.id) }
                )
            }
        }
        .forzAdvisorRowBackground()
    }

    private var importSection: some View {
        Section("Review A Received Contribution") {
            TextEditor(text: $pastedJSON)
                .frame(minHeight: 140)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier(
                    "stockContributionImportJSON"
                )
            Toggle(
                "I received this exact export directly",
                isOn: $reviewConfirmations.directReceiptConfirmed
            )
            Toggle(
                "Tester-authored facts grant confirmed",
                isOn: $reviewConfirmations.testerFactsConfirmed
            )
            Toggle(
                "Deidentified reuse grant confirmed",
                isOn: $reviewConfirmations.reuseConfirmed
            )
            Toggle(
                "Catalog curation grant confirmed",
                isOn: $reviewConfirmations.curationConfirmed
            )
            Toggle(
                "Future bundled redistribution grant confirmed",
                isOn: $reviewConfirmations.redistributionConfirmed
            )
            Button("Import For Collection Review") {
                importContribution()
            }
            .accessibilityIdentifier("importStockContribution")
        }
        .forzAdvisorRowBackground()
    }

    private var reviewedSection: some View {
        Section("Reviewed Queue") {
            if snapshot.reviewed.isEmpty {
                Text("No reviewed contributions.")
                    .foregroundStyle(.secondary)
            }
            ForEach(snapshot.reviewed) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    if let validated =
                        try? StockCatalogContributionIngestor()
                        .validate(entry.canonicalExportJSON) {
                        Text(
                            "\(validated.export.vehicle.year) \(validated.export.vehicle.make) \(validated.export.vehicle.model)"
                        )
                        .font(.headline)
                        Text(
                            "\(validated.export.game.shortTitle) · \(dispositionTitle(entry.disposition))"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    } else {
                        Text("Excluded unreadable contribution")
                    }
                    Button("Delete Reviewed Contribution", role: .destructive) {
                        deleteReviewed(entry.id)
                    }
                }
            }
        }
        .forzAdvisorRowBackground()
    }

    private func saveContribution() {
        let capturedAt = Date()
        guard let year = Int(year),
              let performanceIndex = Int(performanceIndex),
              let weightPounds = Int(weightPounds),
              let frontWeightPercent =
                Double(frontWeightPercent),
              let peakHorsepower = Int(peakHorsepower),
              let peakTorque = Int(peakTorque) else {
            statusMessage = "Enter every numeric stock specification."
            return
        }
        let fields =
            StockCatalogContributionValidator.expectedFields
        let record = StockCatalogContributionRecord(
            capturedAt: capturedAt,
            game: game,
            gameVersion: gameVersion,
            platform: platform,
            vehicle: .init(
                year: year,
                make: make,
                model: model,
                stock: .init(
                    performanceIndex: performanceIndex,
                    performanceClass: performanceClass,
                    drivetrain: drivetrain,
                    weightPounds: weightPounds,
                    frontWeightPercent: frontWeightPercent,
                    peakHorsepower: peakHorsepower,
                    peakTorqueFootPounds: peakTorque
                )
            ),
            reviewedFields: fields,
            fieldAttestations: fields.map {
                .init(
                    field: $0,
                    observationScreen:
                        observationScreens[$0]
                            ?? defaultScreen(for: $0),
                    directlyReadInGame:
                        captureConfirmations.personallyReadConfirmed,
                    untouchedStockConfirmed:
                        captureConfirmations.exactStockConfirmed,
                    englishUnitsConfirmedWhenRelevant:
                        captureConfirmations.englishUnitsConfirmed,
                    observedAt: capturedAt
                )
            },
            exactUntouchedStockConfirmed:
                captureConfirmations.exactStockConfirmed,
            personallyReadFromGameConfirmed:
                captureConfirmations.personallyReadConfirmed,
            firstPartyAuthorshipConfirmed:
                captureConfirmations.authorshipConfirmed,
            localStoragePermissionConfirmed:
                captureConfirmations.localStorageConfirmed,
            rights: .init(
                testerAuthoredStructuredFacts:
                    captureConfirmations.testerFactsRight,
                deidentifiedStructuredReuse:
                    captureConfirmations.reuseRight,
                catalogCurationUse:
                    captureConfirmations.curationRight,
                futureBundledRedistribution:
                    captureConfirmations.redistributionRight
            )
        )
        guard StockCatalogContributionValidator()
            .isValid(record) else {
            statusMessage =
                StockCatalogContributionError.invalidRecord
                .localizedDescription
            return
        }
        snapshot.captured.append(record)
        if persist(
            success:
                "Saved locally. This did not change the bundled catalog or create tuning output."
        ) {
            captureConfirmations.reset()
        }
    }

    private func importContribution() {
        let data = Data(pastedJSON.utf8)
        do {
            let entry = try StockCatalogContributionReviewEntry
                .locallyReviewed(
                    canonicalExportJSON: data,
                    reviewerConfirmedDirectReceipt:
                        reviewConfirmations.directReceiptConfirmed,
                    reviewerConfirmedTesterAuthoredStructuredFacts:
                        reviewConfirmations.testerFactsConfirmed,
                    reviewerConfirmedStructuredReusePermission:
                        reviewConfirmations.reuseConfirmed,
                    reviewerConfirmedCatalogCurationPermission:
                        reviewConfirmations.curationConfirmed,
                    reviewerConfirmedBundledRedistributionPermission:
                        reviewConfirmations.redistributionConfirmed,
                    existing: snapshot.reviewed
                )
            snapshot.reviewed.append(entry)
            if persist(success: dispositionMessage(entry.disposition)) {
                reviewConfirmations.reset()
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func deleteCaptured(_ id: UUID) {
        snapshot.captured.removeAll { $0.id == id }
        persist(success: "Deleted the local contribution.")
    }

    private func deleteReviewed(_ id: UUID) {
        snapshot.reviewed.removeAll { $0.id == id }
        snapshot.reviewed = StockCatalogContributionReviewQueue
            .reclassify(snapshot.reviewed).entries
        persist(success: "Deleted the reviewed contribution.")
    }

    @discardableResult
    private func persist(success: String) -> Bool {
        do {
            try store.save(snapshot)
            statusMessage = success
            return true
        } catch {
            snapshot = store.load()
            statusMessage = error.localizedDescription
            return false
        }
    }

    private var captureDraftFingerprint: String {
        let observations = StockCatalogContributionValidator
            .expectedFields.map {
                draftPart($0.rawValue)
                    + draftPart(
                        (observationScreens[$0]
                            ?? defaultScreen(for: $0)).rawValue
                    )
            }.joined()
        return [
            game.rawValue, gameVersion, platform.rawValue, year, make,
            model, performanceIndex, performanceClass.rawValue,
            drivetrain.rawValue, weightPounds, frontWeightPercent,
            peakHorsepower, peakTorque, observations
        ].map(draftPart).joined()
    }

    private func draftPart(_ value: String) -> String {
        "\(value.utf8.count):\(value)"
    }

    private func dispositionMessage(
        _ disposition: StockCatalogReviewDisposition
    ) -> String {
        switch disposition {
        case .received:
            "Received for collection review. No catalog or tune changed."
        case .matchingObservation:
            "Stored as a matching observation without averaging or approval."
        case .conflictingObservation(let fields):
            "Stored with deterministic conflicts: "
                + fields.map(fieldTitle).joined(separator: ", ")
                + ". No value was averaged, ranked, or approved."
        case .exactDuplicate:
            "Exact duplicate excluded."
        case .excluded:
            "Contribution excluded."
        }
    }

    private func dispositionTitle(
        _ disposition: StockCatalogReviewDisposition
    ) -> String {
        switch disposition {
        case .received: "Received"
        case .exactDuplicate: "Exact duplicate"
        case .matchingObservation: "Matching observation"
        case .conflictingObservation: "Conflicting observation"
        case .excluded: "Excluded"
        }
    }

    private func defaultScreen(
        for field: CatalogDataField
    ) -> StockContributionObservationScreen {
        switch field {
        case .identity, .performanceIndex, .performanceClass,
                .drivetrain, .weightPounds, .frontWeightPercent,
                .peakHorsepower, .peakTorqueFootPounds:
            .garage
        }
    }

    private func fieldTitle(_ field: CatalogDataField) -> String {
        switch field {
        case .identity: "Identity"
        case .performanceIndex: "Performance index"
        case .performanceClass: "Performance class"
        case .drivetrain: "Drivetrain"
        case .weightPounds: "Weight"
        case .frontWeightPercent: "Front weight"
        case .peakHorsepower: "Peak horsepower"
        case .peakTorqueFootPounds: "Peak torque"
        }
    }
}

private struct CapturedStockContributionRow: View {
    let record: StockCatalogContributionRecord
    let onDelete: () -> Void

    private var exportText: String? {
        guard let data = try? StockCatalogContributionExporter()
            .canonicalJSON(for: record) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                "\(record.vehicle.year) \(record.vehicle.make) \(record.vehicle.model)"
            )
            .font(.headline)
            Text(
                "\(record.game.shortTitle) · \(record.gameVersion) · \(record.platform.rawValue)"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            if let exportText {
                ShareLink(item: exportText) {
                    Label(
                        "Share Canonical Contribution",
                        systemImage: "square.and.arrow.up"
                    )
                }
                .accessibilityIdentifier(
                    "shareStockContribution-\(record.id)"
                )
            } else {
                Text(
                    "Local only. The complete four-right grant was not recorded."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Button(
                "Delete Local Contribution",
                role: .destructive,
                action: onDelete
            )
        }
    }
}
