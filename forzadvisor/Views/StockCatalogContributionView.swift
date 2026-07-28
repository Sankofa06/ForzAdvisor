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
    @State private var draft: StockCatalogContributionDraft
    @State private var pastedJSON = ""
    @State private var reviewConfirmations =
        StockCatalogReviewConfirmationState()
    @State private var maintainerReviewConfirmed = false
    @State private var preparedMaintainerPacket: String?
    @State private var selectedCurationCandidate = ""
    @State private var proposedCatalogID = ""
    @State private var proposedCatalogRevision = ""
    @State private var curationChoices =
        StockCatalogCurationChoiceState()
    @State private var identitySourceTitle = ""
    @State private var identitySourceURL = ""
    @State private var identitySourceAccessDate = ""
    @State private var identityRightsEvidenceReference = ""
    @State private var identityRightsEvidenceDigest = ""
    @State private var rightsIndependentlyReviewed = false
    @State private var noSourceFactsCopied = false
    @State private var noSourceProseCopied = false
    @State private var noSourceMediaCopied = false
    @State private var allPermissionedFieldEvidenceUsed = false
    @State private var separateReleaseReviewConfirmed = false
    @State private var preparedCurationPreflight: String?
    @State private var statusMessage: String?

    init(
        draft: StockCatalogContributionDraft = .init(game: .fh6),
        store: StockCatalogContributionStore = .init()
    ) {
        self.store = store
        _draft = State(initialValue: draft)
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
            maintainerReviewSection
            curationPreflightSection

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
            draft.captureConfirmations.invalidateIfDraftChanged(
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
        .onChange(of: curationDraftFingerprint) {
            previous, current in
            if previous != current {
                preparedCurationPreflight = nil
            }
        }
        .task {
            snapshot = store.load()
            if snapshot.recoveredFromMalformedData {
                statusMessage =
                    "Stored contribution data was unreadable and was excluded. The bundled catalog and tunes were unchanged."
            }
        }
    }

    private var identitySection: some View {
        Section("Exact Game And Car Identity") {
            Picker("Game", selection: $draft.game) {
                ForEach(ForzaGame.allCases) {
                    Text($0.shortTitle).tag($0)
                }
            }
            .disabled(draft.isGameSelectionLocked)
            if draft.isGameSelectionLocked {
                Text(
                    "Game is fixed to the selected official roster identity."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Picker("Platform", selection: $draft.platform) {
                Text("Select platform")
                    .tag(nil as StockContributionPlatform?)
                ForEach(StockContributionPlatform.allCases) {
                    Text($0.rawValue)
                        .tag(Optional($0))
                }
            }
            TextField(
                "Exact game version/build",
                text: $draft.gameVersion
            )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Year", text: $draft.year)
                .keyboardType(.numberPad)
            TextField("Make", text: $draft.make)
            TextField("Model", text: $draft.model)
        }
        .forzAdvisorRowBackground()
    }

    private var stockSection: some View {
        Section("Untouched Stock Specifications") {
            Picker("Class", selection: $draft.performanceClass) {
                Text("Select class")
                    .tag(nil as PerformanceClass?)
                ForEach(draft.game.supportedPerformanceClasses) {
                    Text($0.rawValue)
                        .tag(Optional($0))
                }
            }
            TextField(
                "Performance index",
                text: $draft.performanceIndex
            )
                .keyboardType(.numberPad)
            Picker("Drivetrain", selection: $draft.drivetrain) {
                Text("Select drivetrain")
                    .tag(nil as Drivetrain?)
                ForEach(Drivetrain.allCases) {
                    Text($0.rawValue)
                        .tag(Optional($0))
                }
            }
            TextField("Weight (lb)", text: $draft.weightPounds)
                .keyboardType(.numberPad)
            TextField(
                "Front weight (%)",
                text: $draft.frontWeightPercent
            )
            .keyboardType(.decimalPad)
            TextField(
                "Peak horsepower",
                text: $draft.peakHorsepower
            )
                .keyboardType(.numberPad)
            TextField(
                "Peak torque (lb-ft)",
                text: $draft.peakTorque
            )
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
                            draft.observationScreens[field]
                        },
                        set: {
                            draft.observationScreens[field] = $0
                        }
                    )
                ) {
                    Text("Select screen")
                        .tag(
                            nil as
                                StockContributionObservationScreen?
                        )
                    ForEach(
                        StockContributionObservationScreen.allCases
                    ) {
                        Text($0.rawValue)
                            .tag(Optional($0))
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
                isOn:
                    $draft.captureConfirmations
                    .exactStockConfirmed
            )
            Toggle(
                "Personally read directly from the game",
                isOn:
                    $draft.captureConfirmations
                    .personallyReadConfirmed
            )
            Toggle(
                "English units confirmed where relevant",
                isOn:
                    $draft.captureConfirmations
                    .englishUnitsConfirmed
            )
            Toggle(
                "I authored these structured facts",
                isOn:
                    $draft.captureConfirmations
                    .authorshipConfirmed
            )
            Toggle(
                "Allow local storage",
                isOn:
                    $draft.captureConfirmations
                    .localStorageConfirmed
            )
            Divider()
            Text(
                "All reuse rights default off. All four are required before a canonical export can leave this device."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            Toggle(
                "Tester-authored structured facts",
                isOn:
                    $draft.captureConfirmations
                    .testerFactsRight
            )
            Toggle(
                "Deidentified structured reuse",
                isOn:
                    $draft.captureConfirmations.reuseRight
            )
            Toggle(
                "Catalog curation use",
                isOn:
                    $draft.captureConfirmations.curationRight
            )
            Toggle(
                "Future bundled redistribution",
                isOn:
                    $draft.captureConfirmations
                    .redistributionRight
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

    private var maintainerReviewSection: some View {
        Section("Maintainer Review Packet") {
            Text(
                "Prepare a canonical evidence packet from the reviewed queue for separate human catalog curation. It omits submission and local review identifiers, never chooses sources or verification status, and cannot add or change a car."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Toggle(
                "I understand this requires independent source review",
                isOn: $maintainerReviewConfirmed
            )
            .accessibilityIdentifier(
                "confirmStockCatalogMaintainerReview"
            )

            Button("Prepare Maintainer Review Packet") {
                prepareMaintainerReviewPacket()
            }
            .disabled(
                snapshot.reviewed.isEmpty
                    || !maintainerReviewConfirmed
            )
            .accessibilityIdentifier(
                "prepareStockCatalogMaintainerReview"
            )

            if let preparedMaintainerPacket {
                ShareLink(item: preparedMaintainerPacket) {
                    Label(
                        "Share Maintainer Review Packet",
                        systemImage: "square.and.arrow.up"
                    )
                }
                .accessibilityIdentifier(
                    "shareStockCatalogMaintainerReview"
                )
            }
        }
        .forzAdvisorRowBackground()
    }

    private var curationPreflightSection: some View {
        Section("Catalog Curation Preflight") {
            Text(
                "After preparing a maintainer packet, explicitly select one non-conflicting prospective addition. Preflight binds that exact packet and the entire current base catalog for a separate release review."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            if preparedMaintainerPacket == nil {
                Text("Prepare a maintainer review packet first.")
                    .foregroundStyle(.secondary)
            } else if eligibleCurationCandidates.isEmpty {
                Text(
                    "No candidate currently has an absent catalog comparison and two distinct permission-complete observations."
                )
                .foregroundStyle(.secondary)
            } else {
                Picker(
                    "Candidate",
                    selection: $selectedCurationCandidate
                ) {
                    Text("Select a candidate").tag("")
                    ForEach(
                        eligibleCurationCandidates,
                        id: \.key
                    ) { option in
                        Text(option.title).tag(option.key)
                    }
                }
                .accessibilityIdentifier(
                    "stockCatalogCurationCandidate"
                )
            }

            TextField(
                "Proposed catalog ID (fh5-… or fh6-…)",
                text: $proposedCatalogID
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            TextField(
                "Proposed catalog revision",
                text: $proposedCatalogRevision
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            Picker(
                "Proposed verification status",
                selection:
                    $curationChoices
                    .proposedVerificationStatus
            ) {
                Text("Select verification status")
                    .tag(nil as CatalogVerificationStatus?)
                Text(CatalogVerificationStatus.officialRoster.label)
                    .tag(
                        Optional(
                            CatalogVerificationStatus
                                .officialRoster
                        )
                    )
                Text(
                    CatalogVerificationStatus
                        .communityCrossChecked.label
                )
                .tag(
                    Optional(
                        CatalogVerificationStatus
                            .communityCrossChecked
                    )
                )
                Text(CatalogVerificationStatus.inGameVerified.label)
                    .tag(
                        Optional(
                            CatalogVerificationStatus
                                .inGameVerified
                        )
                    )
            }

            Divider()
            Text("Official Identity Source Rights Review")
                .font(.subheadline.weight(.semibold))
            TextField(
                "Safe source title",
                text: $identitySourceTitle
            )
            TextField(
                "HTTPS source URL",
                text: $identitySourceURL
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            TextField(
                "Access date (YYYY-MM-DD)",
                text: $identitySourceAccessDate
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            Picker(
                "Rights basis",
                selection:
                    $curationChoices.identityRightsBasis
            ) {
                Text("Select rights basis")
                    .tag(nil as StockCatalogIdentityRightsBasis?)
                ForEach(StockCatalogIdentityRightsBasis.allCases) {
                    Text($0.label)
                        .tag(Optional($0))
                }
            }
            TextField(
                "Rights evidence reference",
                text: $identityRightsEvidenceReference
            )
            TextField(
                "Rights evidence SHA-256",
                text: $identityRightsEvidenceDigest
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            Toggle(
                "Rights independently reviewed",
                isOn: $rightsIndependentlyReviewed
            )
            Toggle(
                "No source facts copied into candidate",
                isOn: $noSourceFactsCopied
            )
            Toggle(
                "No source prose copied into candidate",
                isOn: $noSourceProseCopied
            )
            Toggle(
                "No source media copied into candidate",
                isOn: $noSourceMediaCopied
            )
            Toggle(
                "Use all permissioned observation evidence for every field",
                isOn: $allPermissionedFieldEvidenceUsed
            )
            Toggle(
                "Separate release review required",
                isOn: $separateReleaseReviewConfirmed
            )

            Text(StockCatalogCurationPreflightPolicy.reviewBoundary)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Prepare Canonical Curation Preflight") {
                prepareCurationPreflight()
            }
            .disabled(!canPrepareCurationPreflight)
            .accessibilityIdentifier(
                "prepareStockCatalogCurationPreflight"
            )

            if let preparedCurationPreflight {
                ShareLink(item: preparedCurationPreflight) {
                    Label(
                        "Share Curation Preflight",
                        systemImage: "square.and.arrow.up"
                    )
                }
                .accessibilityIdentifier(
                    "shareStockCatalogCurationPreflight"
                )
                if let preflightData =
                        preparedCurationPreflight.data(
                            using: .utf8
                        ),
                   let packetText = preparedMaintainerPacket,
                   let packetData = packetText.data(
                       using: .utf8
                   ) {
                    NavigationLink(
                        "Open Catalog Addition Review"
                    ) {
                        StockCatalogAdditionReviewView(
                            preflightCanonicalJSON:
                                preflightData,
                            packetCanonicalJSON: packetData
                        )
                    }
                    .accessibilityIdentifier(
                        "openStockCatalogAdditionReview"
                    )
                }
            }
        }
        .forzAdvisorRowBackground()
    }

    private struct CurationCandidateOption {
        let key: String
        let title: String
        let groupID: String
        let variant:
            StockCatalogMaintainerEvidenceVariant
    }

    private var eligibleCurationCandidates:
        [CurationCandidateOption] {
        guard let preparedMaintainerPacket,
              let data = preparedMaintainerPacket.data(using: .utf8),
              let packet = try?
                StockCatalogMaintainerReviewPacketExporter()
                .validate(data) else {
            return []
        }
        return packet.candidates.compactMap { candidate in
            let variant = candidate.variant
            guard variant.catalogComparison.status == .absent,
                  variant.observations.count >= 2,
                  variant.observations.allSatisfy(
                      \.permission.isComplete
                  ) else {
                return nil
            }
            let key =
                "\(candidate.groupID):\(variant.variantID)"
            return CurationCandidateOption(
                key: key,
                title:
                    "\(variant.vehicle.year) \(variant.vehicle.make) \(variant.vehicle.model) · \(variant.game.shortTitle) · \(variant.observations.count) observations",
                groupID: candidate.groupID,
                variant: variant
            )
        }
    }

    private var canPrepareCurationPreflight: Bool {
        preparedMaintainerPacket != nil
            && eligibleCurationCandidates.contains {
                $0.key == selectedCurationCandidate
            }
            && !proposedCatalogID.isEmpty
            && !proposedCatalogRevision.isEmpty
            && curationChoices.proposedVerificationStatus
                != nil
            && !identitySourceTitle.isEmpty
            && !identitySourceURL.isEmpty
            && !identitySourceAccessDate.isEmpty
            && curationChoices.identityRightsBasis != nil
            && !identityRightsEvidenceReference.isEmpty
            && !identityRightsEvidenceDigest.isEmpty
            && rightsIndependentlyReviewed
            && noSourceFactsCopied
            && noSourceProseCopied
            && noSourceMediaCopied
            && allPermissionedFieldEvidenceUsed
            && separateReleaseReviewConfirmed
    }

    private func prepareCurationPreflight() {
        guard canPrepareCurationPreflight,
              let packetText = preparedMaintainerPacket,
              let packetData = packetText.data(using: .utf8),
              let identityRightsBasis =
                curationChoices.identityRightsBasis,
              let proposedVerificationStatus =
                curationChoices.proposedVerificationStatus,
              let option = eligibleCurationCandidates.first(
                  where: { $0.key == selectedCurationCandidate }
              ) else {
            preparedCurationPreflight = nil
            statusMessage =
                "Complete every preflight field and confirmation, then explicitly select an eligible candidate."
            return
        }
        let observations = option.variant.observations
        let decisions = StockCatalogContributionValidator
            .expectedFields.map { field in
                StockCatalogCurationFieldDecision(
                    field: field,
                    observationDigests: observations.filter {
                        $0.permission.isComplete
                            && $0.fields.contains {
                                $0.field == field
                            }
                    }.map(\.observationDigest).sorted()
                )
            }
        let request = StockCatalogCurationPreflightRequest(
            groupID: option.groupID,
            variantID: option.variant.variantID,
            fieldDecisions: decisions,
            identitySourceRightsReview: .init(
                sourceTitle: identitySourceTitle,
                sourceURL: identitySourceURL,
                accessedOn: identitySourceAccessDate,
                rightsBasis: identityRightsBasis,
                rightsEvidenceReference:
                    identityRightsEvidenceReference,
                rightsEvidenceSHA256:
                    identityRightsEvidenceDigest,
                rightsIndependentlyReviewed:
                    rightsIndependentlyReviewed,
                noSourceFactsCopied: noSourceFactsCopied,
                noSourceProseCopied: noSourceProseCopied,
                noSourceMediaCopied: noSourceMediaCopied
            ),
            proposal: .init(
                catalogID: proposedCatalogID,
                revision: proposedCatalogRevision,
                verificationStatus:
                    proposedVerificationStatus
            ),
            allPermissionedEvidenceUsedForEveryField:
                allPermissionedFieldEvidenceUsed,
            separateReleaseReviewConfirmed:
                separateReleaseReviewConfirmed
        )
        do {
            let catalog = try BundledCarCatalog.load().get()
            let artifact = try StockCatalogCurationPreflightExporter()
                .makeArtifact(
                    packetCanonicalJSON: packetData,
                    baseCatalog: catalog,
                    request: request
                )
            guard let text = String(
                data: artifact.canonicalJSON,
                encoding: .utf8
            ) else {
                throw StockCatalogCurationPreflightError.invalidJSON
            }
            preparedCurationPreflight = text
            statusMessage =
                "Prepared a canonical prospective curation preflight. It did not change the catalog, verify the candidate, or activate tuning."
        } catch {
            preparedCurationPreflight = nil
            statusMessage = error.localizedDescription
        }
    }

    private func saveContribution() {
        let capturedAt = Date()
        let fields =
            StockCatalogContributionValidator.expectedFields
        let selectedScreens = fields.compactMap { field in
            draft.observationScreens[field].map {
                (field, $0)
            }
        }
        guard let platform = draft.platform,
              let performanceClass = draft.performanceClass,
              let drivetrain = draft.drivetrain,
              selectedScreens.count == fields.count else {
            statusMessage =
                "Choose a platform, performance class, drivetrain, and observation screen for every field."
            return
        }
        guard let year = Int(draft.year),
              let performanceIndex =
                Int(draft.performanceIndex),
              let weightPounds = Int(draft.weightPounds),
              let frontWeightPercent =
                Double(draft.frontWeightPercent),
              let peakHorsepower =
                Int(draft.peakHorsepower),
              let peakTorque = Int(draft.peakTorque) else {
            statusMessage = "Enter every numeric stock specification."
            return
        }
        let record = StockCatalogContributionRecord(
            capturedAt: capturedAt,
            game: draft.game,
            gameVersion: draft.gameVersion,
            platform: platform,
            vehicle: .init(
                year: year,
                make: draft.make,
                model: draft.model,
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
            fieldAttestations: selectedScreens.map {
                .init(
                    field: $0.0,
                    observationScreen: $0.1,
                    directlyReadInGame:
                        draft.captureConfirmations
                        .personallyReadConfirmed,
                    untouchedStockConfirmed:
                        draft.captureConfirmations
                        .exactStockConfirmed,
                    englishUnitsConfirmedWhenRelevant:
                        draft.captureConfirmations
                        .englishUnitsConfirmed,
                    observedAt: capturedAt
                )
            },
            exactUntouchedStockConfirmed:
                draft.captureConfirmations
                .exactStockConfirmed,
            personallyReadFromGameConfirmed:
                draft.captureConfirmations
                .personallyReadConfirmed,
            firstPartyAuthorshipConfirmed:
                draft.captureConfirmations
                .authorshipConfirmed,
            localStoragePermissionConfirmed:
                draft.captureConfirmations
                .localStorageConfirmed,
            rights: .init(
                testerAuthoredStructuredFacts:
                    draft.captureConfirmations
                    .testerFactsRight,
                deidentifiedStructuredReuse:
                    draft.captureConfirmations.reuseRight,
                catalogCurationUse:
                    draft.captureConfirmations
                    .curationRight,
                futureBundledRedistribution:
                    draft.captureConfirmations
                    .redistributionRight
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
            draft.captureConfirmations.reset()
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
                invalidateMaintainerReviewPacket()
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
        if persist(success: "Deleted the reviewed contribution.") {
            invalidateMaintainerReviewPacket()
        }
    }

    private func prepareMaintainerReviewPacket() {
        guard maintainerReviewConfirmed else {
            statusMessage =
                "Confirm independent source review before preparing a packet."
            return
        }
        do {
            let catalog = try BundledCarCatalog.load().get()
            let artifact =
                try StockCatalogMaintainerReviewPacketExporter()
                .makeArtifact(
                    reviewedEntries: snapshot.reviewed,
                    baseCatalog: catalog
                )
            guard let packet = String(
                data: artifact.canonicalJSON,
                encoding: .utf8
            ) else {
                throw StockCatalogMaintainerReviewPacketError.invalidJSON
            }
            preparedMaintainerPacket = packet
            selectedCurationCandidate = ""
            preparedCurationPreflight = nil
            statusMessage =
                "Prepared \(artifact.packet.candidates.count) candidate group(s) and \(artifact.packet.conflicts.count) conflict group(s); excluded \(artifact.packet.excludedObservationCount) observation(s). No catalog or tune changed."
        } catch {
            preparedMaintainerPacket = nil
            statusMessage = error.localizedDescription
        }
    }

    private func invalidateMaintainerReviewPacket() {
        preparedMaintainerPacket = nil
        maintainerReviewConfirmed = false
        selectedCurationCandidate = ""
        preparedCurationPreflight = nil
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
                        draft.observationScreens[$0]?
                            .rawValue ?? ""
                    )
            }.joined()
        return [
            draft.game.rawValue,
            draft.gameVersion,
            draft.platform?.rawValue ?? "",
            draft.year,
            draft.make,
            draft.model,
            draft.performanceIndex,
            draft.performanceClass?.rawValue ?? "",
            draft.drivetrain?.rawValue ?? "",
            draft.weightPounds,
            draft.frontWeightPercent,
            draft.peakHorsepower,
            draft.peakTorque,
            observations
        ].map(draftPart).joined()
    }

    private var curationDraftFingerprint: String {
        [
            preparedMaintainerPacket ?? "",
            selectedCurationCandidate,
            proposedCatalogID,
            proposedCatalogRevision,
            curationChoices.proposedVerificationStatus?
                .rawValue ?? "",
            identitySourceTitle,
            identitySourceURL,
            identitySourceAccessDate,
            curationChoices.identityRightsBasis?.rawValue ?? "",
            identityRightsEvidenceReference,
            identityRightsEvidenceDigest,
            String(rightsIndependentlyReviewed),
            String(noSourceFactsCopied),
            String(noSourceProseCopied),
            String(noSourceMediaCopied),
            String(allPermissionedFieldEvidenceUsed),
            String(separateReleaseReviewConfirmed)
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
