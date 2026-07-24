//
//  TuneResultView.swift
//  forzadvisor
//
//  Renders generated tune output in the same section order as the in-game menu.
//  Individual values can be copied while entering the tune on a console or PC.
//

import SwiftUI
import UIKit

struct TuneResultView: View {
    let tune: TuneResult
    let isSaved: Bool
    var isStreaming = false
    let playerNotes: String
    let thumbnailData: Data?
    let adjustmentChanges: [TuneAdjustmentChange]
    let activeFeedback: TuneFeedback?
    let onDone: () -> Void
    let onSave: () -> Void
    let onEdit: () -> Void
    let onVerifyTuneMenu: (() -> Void)?
    let onVerifyTirePressures: (() -> Void)?
    let onVerifyUpgradeParts: (() -> Void)?
    let latestFH5ResearchRecord: FH5ResearchObservationRecord?
    let fh5NumericReadiness: FH5NumericReadinessAssessment?
    let onOpenFH5Research: (() -> Void)?
    let onDeleteFH5ResearchRecord: (FH5ResearchObservationRecord) -> Void
    let fh5ResearchReviewEntries: [FH5ResearchReviewEntry]
    let onImportFH5ResearchReviewEntry: ((FH5ResearchReviewEntry) -> String?)?
    let onDeleteFH5ResearchReviewEntry: (FH5ResearchReviewEntry) -> Void
    let latestFH5ControlledExperimentRecord: FH5ControlledExperimentRecord?
    let fh5CandidateTrialAvailable: Bool
    let fh5CandidateOutcomeReport: FH5ControlledOutcomePolicyReport?
    let fh5CandidateTrialArtifact: FH5GeneratedCandidateArtifact?
    let fh5CandidateOutcomeReviewEntries:
        [FH5CandidateOutcomeReviewEntry]
    let fh5CandidateOutcomeCollectionReport:
        FH5CandidateOutcomeCollectionReport
    let fh5CandidateOutcomeReviewLoadError: String?
    let onImportFH5CandidateOutcomeReviewEntry:
        ((FH5CandidateOutcomeReviewEntry) -> String?)?
    let onDeleteFH5CandidateOutcomeReviewEntry:
        (FH5CandidateOutcomeReviewEntry) -> Void
    let onOpenFH5ControlledExperiment: (() -> Void)?
    let onDeleteFH5ControlledExperimentRecord:
        (FH5ControlledExperimentRecord) -> Void
    let latestValidationRecord: FirstPartyValidationRecord?
    let onRecordTestDrive: (() -> Void)?
    let onDeleteValidationRecord: (FirstPartyValidationRecord) -> Void
    let fh6ValidationReviewEntries: [FH6ValidationReviewEntry]
    let fh6ValidationReviewLoadError: String?
    let onImportFH6ValidationReviewEntry:
        ((FH6ValidationReviewEntry) -> String?)?
    let onDeleteFH6ValidationReviewEntry: (FH6ValidationReviewEntry) -> Void
    let onFeedback: (TuneFeedback) -> Void

    @State private var copiedLineID: TuneLine.ID?
    @State private var expandedSectionTitles = Set(TuneSection.menuOrder.map(\.title))
    @State private var copiedExport: CopiedExport?
    @State private var recordPendingDeletion: FirstPartyValidationRecord?
    @State private var researchRecordPendingDeletion: FH5ResearchObservationRecord?
    @State private var experimentRecordPendingDeletion:
        FH5ControlledExperimentRecord?
    @State private var showsFH5ResearchReview = false
    @State private var showsFH5CandidateOutcomeReview = false
    @State private var showsFH6ValidationReview = false

    private var isAdjusting: Bool {
        activeFeedback != nil
    }

    private var upgradePaths: [TuneControlUpgradePath] {
        TuneControlUpgradePlanner().paths(for: tune)
    }

    private var verifiedBuildShareCard: VerifiedBuildShareCard? {
        VerifiedBuildShareCardFactory().make(for: tune, isStreaming: isStreaming)
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    if let thumbnailData,
                       let image = UIImage(data: thumbnailData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(ForzAdvisorTheme.separator, lineWidth: 1)
                            }
                    } else {
                        ForzAdvisorIcon(
                            systemName: tune.request.discipline.symbolName,
                            tint: ForzAdvisorTheme.disciplineColor(tune.request.discipline),
                            size: 44
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(tune.request.car.displayName)
                            .font(.title2.weight(.bold))
                        Text("\(tune.request.discipline.title) - \(tune.request.car.performanceClass.rawValue) \(tune.request.car.performanceIndex) - \(tune.request.car.drivetrain.rawValue)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ProviderStatusView(tune: tune)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(ForzAdvisorTheme.heroRowBackground)

            if let catalogReference = tune.request.car.catalogReference {
                Section("Catalog Data Origin") {
                    CatalogProvenanceView(
                        reference: catalogReference,
                        showsOriginMessage: true,
                        valuesModified: tune.request.car.catalogValuesModified
                    )
                    .accessibilityIdentifier("tuneCatalogIdentity")
                }
                .forzAdvisorRowBackground()
            }

            if let report = tune.projectionReport {
                if tune.purpose == .fh5BuildPlan {
                    Section("FH5 Plan-Only Result") {
                        Label(
                            "Numeric FH5 tuning settings are unavailable until a separate validated FH5 ruleset exists. This local result is a build plan only.",
                            systemImage: "exclamationmark.shield"
                        )
                        .font(.subheadline)
                        .foregroundStyle(ForzAdvisorTheme.warning)
                        .accessibilityIdentifier("fh5PlanOnlyCaution")
                    }
                    .forzAdvisorRowBackground()
                }

                Section("Tune Coverage") {
                    TuneCoverageView(
                        report: report,
                        showsAlternativePathSummary: !upgradePaths.isEmpty,
                        isPlanOnly: tune.purpose == .fh5BuildPlan
                    )
                }
                .forzAdvisorRowBackground()

                FH5ResearchOutcomeSection(
                    isStreaming: isStreaming,
                    readiness: fh5NumericReadiness,
                    onOpenResearch: onOpenFH5Research,
                    researchRecord: latestFH5ResearchRecord,
                    canOpenReview: onImportFH5ResearchReviewEntry != nil,
                    onOpenReview: {
                        showsFH5ResearchReview = true
                    },
                    experimentRecord: latestFH5ControlledExperimentRecord,
                    candidateTrialAvailable: fh5CandidateTrialAvailable,
                    candidateOutcomeReport: fh5CandidateOutcomeReport,
                    candidateTrialArtifact:
                        fh5CandidateTrialArtifact,
                    candidateOutcomeCollectionReport:
                        fh5CandidateOutcomeCollectionReport,
                    canOpenCandidateOutcomeReview:
                        onImportFH5CandidateOutcomeReviewEntry != nil,
                    onOpenCandidateOutcomeReview: {
                        showsFH5CandidateOutcomeReview = true
                    },
                    onOpenExperiment: onOpenFH5ControlledExperiment,
                    onRequestDeleteResearch: {
                        researchRecordPendingDeletion = $0
                    },
                    onRequestDeleteExperiment: {
                        experimentRecordPendingDeletion = $0
                    }
                )

                if !isStreaming, let onVerifyTuneMenu {
                    Section("Tune Menu Lab") {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Verify the exact stock tune menu", systemImage: "slider.horizontal.3")
                                .font(.subheadline.weight(.semibold))
                            Text("Record every FH6 control as Adjustable, Shown locked, or Not shown. Exact ranges and steps let ForzAdvisor regenerate only values that fit this untouched stock build.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Verify Exact Tune Menu", action: onVerifyTuneMenu)
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("verifyTuneMenuButton")
                        }
                        .padding(.vertical, 4)
                    }
                    .forzAdvisorRowBackground()
                }

                if !isStreaming, let onVerifyTirePressures {
                    Section("Tune Lab") {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Unlock verified tire settings", systemImage: "gauge.with.dots.needle.33percent")
                                .font(.subheadline.weight(.semibold))
                            Text("Read the forward gear count from the FH6 transmission/gearing screen and the front and rear ranges from the tire-pressure screen. ForzAdvisor keeps the observation on this device and regenerates this tune against the exact controls.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Verify Tire Pressures", action: onVerifyTirePressures)
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("verifyTirePressuresButton")
                        }
                        .padding(.vertical, 4)
                    }
                    .forzAdvisorRowBackground()
                }

                if !isStreaming, let onVerifyUpgradeParts {
                    Section("Upgrade Lab") {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Verify tuning-control upgrades", systemImage: "wrench.and.screwdriver")
                                .font(.subheadline.weight(.semibold))
                            Text("Check the untouched stock car's upgrade shop in \(tune.request.car.game.shortTitle). ForzAdvisor will build exact alternative buy lists from only the parts you mark Offered.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Verify Upgrade Parts", action: onVerifyUpgradeParts)
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("verifyUpgradePartsButton")
                        }
                        .padding(.vertical, 4)
                    }
                    .forzAdvisorRowBackground()
                }

                if !isStreaming, !upgradePaths.isEmpty {
                    Section("Tuning-Control Upgrade Paths") {
                        TuneControlUpgradePathsView(paths: upgradePaths)
                    }
                    .forzAdvisorRowBackground()
                }

                TuneExportSection(
                    tune: tune,
                    shareCard: verifiedBuildShareCard,
                    isStreaming: isStreaming,
                    copiedExport: $copiedExport,
                    copiedLineID: $copiedLineID
                )
            } else {
                Section("Unverified Legacy Tune") {
                    Label(
                        "These saved values predate verification. Review them in game before use; copying and guided refinement are disabled.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.subheadline)
                    .foregroundStyle(ForzAdvisorTheme.warning)
                }
                .forzAdvisorRowBackground()
            }

            if isStreaming {
                Section {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Streaming structured on-device tune")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                    .foregroundStyle(ForzAdvisorTheme.accent)
                }
                .forzAdvisorRowBackground()
            }

            FH6AccuracyEvidenceSection(
                isStreaming: isStreaming,
                onRecordTestDrive: onRecordTestDrive,
                latestValidationRecord: latestValidationRecord,
                canOpenValidationReview:
                    onImportFH6ValidationReviewEntry != nil,
                recordPendingDeletion: $recordPendingDeletion,
                showsValidationReview: $showsFH6ValidationReview
            )

            GuidedRefinementSection(
                isVisible:
                    isSaved
                    && !isStreaming
                    && !eligibleFeedback.isEmpty,
                feedbackOptions: eligibleFeedback,
                activeFeedback: activeFeedback,
                onFeedback: onFeedback
            )

            AdjustmentChangesSection(changes: adjustmentChanges)

            TuneSectionsGroup(
                sections: displaySections,
                isStreaming: isStreaming,
                allowsCopy: tune.projectionReport != nil,
                expandedSectionTitles: $expandedSectionTitles,
                copiedLineID: $copiedLineID
            )

            TuneNotesSection(tune: tune)

            GarageNotesSection(playerNotes: playerNotes)
        }
        .navigationTitle(tune.purpose == .fh5BuildPlan ? "Build Plan" : "Tune")
        .forzAdvisorScreenChrome()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done", action: onDone)
                    .accessibilityIdentifier("doneTuneButton")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                if isSaved {
                    Button("Edit", action: onEdit)
                        .disabled(isAdjusting || isStreaming)
                }
                Button(isSaved ? "Saved" : saveButtonTitle, action: onSave)
                    .disabled(isSaved || isAdjusting || isStreaming)
                    .accessibilityIdentifier("saveTuneButton")
            }
        }
        .alert(
            "Delete local validation record?",
            isPresented: Binding(
                get: { recordPendingDeletion != nil },
                set: { if !$0 { recordPendingDeletion = nil } }
            ),
            presenting: recordPendingDeletion
        ) { record in
            Button("Delete Local Record", role: .destructive) {
                onDeleteValidationRecord(record)
                recordPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                recordPendingDeletion = nil
            }
        } message: { _ in
            Text("This removes only the local copy. It cannot recall JSON files you already shared.")
        }
        .alert(
            "Delete local FH5 observation?",
            isPresented: Binding(
                get: { researchRecordPendingDeletion != nil },
                set: { if !$0 { researchRecordPendingDeletion = nil } }
            ),
            presenting: researchRecordPendingDeletion
        ) { record in
            Button("Delete Local Observation", role: .destructive) {
                onDeleteFH5ResearchRecord(record)
                researchRecordPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                researchRecordPendingDeletion = nil
            }
        } message: { _ in
            Text("This removes only the local record. JSON copies you already shared cannot be recalled.")
        }
        .alert(
            "Delete local FH5 experiment?",
            isPresented: Binding(
                get: { experimentRecordPendingDeletion != nil },
                set: { if !$0 { experimentRecordPendingDeletion = nil } }
            ),
            presenting: experimentRecordPendingDeletion
        ) { record in
            Button("Delete Local Experiment", role: .destructive) {
                onDeleteFH5ControlledExperimentRecord(record)
                experimentRecordPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                experimentRecordPendingDeletion = nil
            }
        } message: { _ in
            Text("This removes only the local calibration record and does not change the saved FH5 plan.")
        }
        .sheet(isPresented: $showsFH5ResearchReview) {
            if let onImportFH5ResearchReviewEntry {
                FH5ResearchReviewView(
                    tune: tune,
                    entries: fh5ResearchReviewEntries,
                    onImport: onImportFH5ResearchReviewEntry,
                    onDelete: onDeleteFH5ResearchReviewEntry
                )
            }
        }
        .sheet(isPresented: $showsFH6ValidationReview) {
            if let onImportFH6ValidationReviewEntry {
                FH6ValidationReviewView(
                    tune: tune,
                    entries: fh6ValidationReviewEntries,
                    storageError: fh6ValidationReviewLoadError,
                    onImport: onImportFH6ValidationReviewEntry,
                    onDelete: onDeleteFH6ValidationReviewEntry
                )
            }
        }
        .sheet(isPresented: $showsFH5CandidateOutcomeReview) {
            if let artifact = fh5CandidateTrialArtifact,
               let onImportFH5CandidateOutcomeReviewEntry {
                FH5CandidateOutcomeReviewView(
                    artifact: artifact,
                    entries: fh5CandidateOutcomeReviewEntries,
                    report: fh5CandidateOutcomeCollectionReport,
                    storageError:
                        fh5CandidateOutcomeReviewLoadError,
                    onImport:
                        onImportFH5CandidateOutcomeReviewEntry,
                    onDelete:
                        onDeleteFH5CandidateOutcomeReviewEntry
                )
            }
        }
    }

    private var displaySections: [TuneSection] {
        tune.sections
    }

    private var eligibleFeedback: [TuneFeedback] {
        let ready = tune.projectionReport?.readyFieldIDs ?? []
        return TuneFeedback.allCases.filter {
            !ready.intersection($0.adjustment.affectedFields).isEmpty
        }
    }

    private var saveButtonTitle: String {
        if tune.purpose == .fh5BuildPlan {
            return "Save Plan"
        }
        let report = tune.projectionReport
        let hasPlan = !(report?.purchasePlan.isEmpty ?? true)
            || !(report?.confirmations.isEmpty ?? true)
        if report?.readyCount == 0, hasPlan {
            return "Save Plan"
        }
        return "Save"
    }

}

private struct GuidedRefinementSection: View {
    let isVisible: Bool
    let feedbackOptions: [TuneFeedback]
    let activeFeedback: TuneFeedback?
    let onFeedback: (TuneFeedback) -> Void

    var body: some View {
        if isVisible {
            Section("Guided Refinement") {
                GuidedRefinementView(
                    feedbackOptions: feedbackOptions,
                    activeFeedback: activeFeedback,
                    onFeedback: onFeedback
                )
                .padding(.vertical, 4)
            }
            .forzAdvisorRowBackground()
        }
    }
}

private struct AdjustmentChangesSection: View {
    let changes: [TuneAdjustmentChange]

    var body: some View {
        if !changes.isEmpty {
            Section("Last changes") {
                ForEach(changes) { change in
                    AdjustmentChangeRow(change: change)
                }
            }
            .forzAdvisorRowBackground()
        }
    }
}

private struct TuneNotesSection: View {
    let tune: TuneResult

    var body: some View {
        if tune.purpose != .fh5BuildPlan {
            Section("Notes") {
                NoteRow(title: "Bias", text: tune.notes.bias)
                NoteRow(
                    title: "If pushes wide",
                    text: tune.notes.ifPushesWide
                )
                NoteRow(
                    title: "If snaps on lift",
                    text: tune.notes.ifSnapsOnLift
                )
                NoteRow(title: "Retune", text: tune.notes.retuneTrigger)
            }
            .forzAdvisorRowBackground()
        }
    }
}

private struct GarageNotesSection: View {
    let playerNotes: String

    var body: some View {
        if !playerNotes.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty {
            Section("Garage Notes") {
                Text(playerNotes)
            }
            .forzAdvisorRowBackground()
        }
    }
}

private struct FH6AccuracyEvidenceSection: View {
    let isStreaming: Bool
    let onRecordTestDrive: (() -> Void)?
    let latestValidationRecord: FirstPartyValidationRecord?
    let canOpenValidationReview: Bool
    @Binding var recordPendingDeletion: FirstPartyValidationRecord?
    @Binding var showsValidationReview: Bool

    var body: some View {
        if !isStreaming,
           onRecordTestDrive != nil
            || latestValidationRecord != nil
            || canOpenValidationReview {
            Section("Accuracy Evidence") {
                if let onRecordTestDrive {
                    VStack(alignment: .leading, spacing: 8) {
                        Button(
                            "Record Test Drive",
                            action: onRecordTestDrive
                        )
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("recordTestDriveButton")
                        Text(
                            "Create permission-clear evidence from one test session after applying every exported setting."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }

                if let record = latestValidationRecord,
                   let json = record.deterministicJSONString {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(
                            "Latest session recorded",
                            systemImage: "checkmark.seal"
                        )
                        .font(.subheadline.weight(.semibold))
                        Text(sessionSummary(for: record))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ShareLink(
                            item: json,
                            subject: Text("ForzAdvisor validation record")
                        ) {
                            Label(
                                "Share validation JSON",
                                systemImage: "square.and.arrow.up"
                            )
                            .frame(
                                maxWidth: .infinity,
                                minHeight: 44,
                                alignment: .leading
                            )
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier(
                            "shareValidationRecordButton"
                        )
                        Button(
                            "Delete latest local record",
                            role: .destructive
                        ) {
                            recordPendingDeletion = record
                        }
                        .accessibilityIdentifier(
                            "deleteValidationRecordButton"
                        )
                    }
                    .padding(.vertical, 2)
                }

                if canOpenValidationReview {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(
                            "Review shared test-drive outcomes",
                            systemImage:
                                "rectangle.stack.badge.checkmark"
                        )
                        .font(.subheadline.weight(.semibold))
                        Text(
                            "Import exact, permission-bound ForzAdvisor JSON for this saved setup. Review shows observed outcomes and conditions only; it never changes the tune."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Button("Open Validation Review") {
                            showsValidationReview = true
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier(
                            "openFH6ValidationReviewButton"
                        )
                    }
                    .padding(.vertical, 2)
                }
            }
            .forzAdvisorRowBackground()
        }
    }

    private func sessionSummary(
        for record: FirstPartyValidationRecord
    ) -> String {
        let session = record.session
        let runSuffix = session.runCount == 1 ? "" : "s"
        return "\(session.courseType.title) · \(session.runCount) run\(runSuffix) · \(record.outcome.verdict.rawValue.capitalized)"
    }
}

private struct FH5ResearchOutcomeSection: View {
    let isStreaming: Bool
    let readiness: FH5NumericReadinessAssessment?
    let onOpenResearch: (() -> Void)?
    let researchRecord: FH5ResearchObservationRecord?
    let canOpenReview: Bool
    let onOpenReview: () -> Void
    let experimentRecord: FH5ControlledExperimentRecord?
    let candidateTrialAvailable: Bool
    let candidateOutcomeReport: FH5ControlledOutcomePolicyReport?
    let candidateTrialArtifact: FH5GeneratedCandidateArtifact?
    let candidateOutcomeCollectionReport:
        FH5CandidateOutcomeCollectionReport
    let canOpenCandidateOutcomeReview: Bool
    let onOpenCandidateOutcomeReview: () -> Void
    let onOpenExperiment: (() -> Void)?
    let onRequestDeleteResearch: (FH5ResearchObservationRecord) -> Void
    let onRequestDeleteExperiment: (FH5ControlledExperimentRecord) -> Void

    var body: some View {
        if !isStreaming,
           onOpenResearch != nil || researchRecord != nil || canOpenReview {
            Section("FH5 Research Lab") {
                if let readiness {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(
                            "Numeric readiness \(readiness.completedCount)/\(readiness.items.count)",
                            systemImage: "checklist"
                        )
                        .font(.subheadline.weight(.semibold))

                        ForEach(readiness.items) { item in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: readinessSymbol(for: item.state))
                                    .foregroundStyle(readinessColor(for: item.state))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.gate.title)
                                        .font(.caption.weight(.semibold))
                                    Text(item.detail)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Text(
                            "Menu evidence never becomes tune-quality evidence by itself. Numeric output stays locked until every gate passes."
                        )
                        .font(.caption)
                        .foregroundStyle(ForzAdvisorTheme.warning)
                    }
                    .padding(.vertical, 2)
                    .accessibilityIdentifier("fh5NumericReadiness")
                }

                if let onOpenResearch {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(
                            "Record the untouched stock tuning menu",
                            systemImage: "checklist.checked"
                        )
                        .font(.subheadline.weight(.semibold))
                        Text(
                            "Use Horizon Test Track with English units to record raw first-party control availability and slider ranges. This evidence is not a tune."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Button(
                            "Open FH5 Research Lab",
                            action: onOpenResearch
                        )
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("openFH5ResearchLabButton")
                    }
                    .padding(.vertical, 2)
                }

                if let researchRecord {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(
                            "Latest stock observation recorded",
                            systemImage: "checkmark.seal"
                        )
                        .font(.subheadline.weight(.semibold))
                        Text(
                            "\(researchRecord.platform.title) · \(researchRecord.gameVersion) · \(researchRecord.forwardGearCount) forward gears"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Text(
                            "Raw evidence recorded. Numeric FH5 tuning remains unavailable."
                        )
                        .font(.caption)
                        .foregroundStyle(ForzAdvisorTheme.warning)

                        if let json = researchRecord.deterministicJSONString {
                            ShareLink(
                                item: json,
                                subject: Text(
                                    "ForzAdvisor FH5 stock observation"
                                )
                            ) {
                                Label(
                                    "Share deidentified observation JSON",
                                    systemImage: "square.and.arrow.up"
                                )
                                .frame(
                                    maxWidth: .infinity,
                                    minHeight: 44,
                                    alignment: .leading
                                )
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier(
                                "shareFH5ResearchObservationButton"
                            )
                        } else {
                            Text(
                                "JSON sharing is unavailable because deidentified structured reuse was not enabled for this record."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Button(
                            "Delete latest local observation",
                            role: .destructive
                        ) {
                            onRequestDeleteResearch(researchRecord)
                        }
                        .accessibilityIdentifier(
                            "deleteFH5ResearchObservationButton"
                        )
                    }
                    .padding(.vertical, 2)
                }

                if canOpenReview {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(
                            "Compare permission-bound observations",
                            systemImage: "rectangle.stack.badge.checkmark"
                        )
                        .font(.subheadline.weight(.semibold))
                        Text(
                            "Import exact ForzAdvisor JSON from other first-party sessions. Review reports only replicated or conflicting raw observations; they never unlock a tune."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Button("Open Research Review", action: onOpenReview)
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier(
                                "openFH5ResearchReviewButton"
                            )
                    }
                    .padding(.vertical, 2)
                }

                FH5ControlledExperimentSummary(
                    record: experimentRecord,
                    candidateTrialAvailable: candidateTrialAvailable,
                    candidateOutcomeReport: candidateOutcomeReport,
                    candidateTrialArtifact: candidateTrialArtifact,
                    candidateOutcomeCollectionReport:
                        candidateOutcomeCollectionReport,
                    canOpenCandidateOutcomeReview:
                        canOpenCandidateOutcomeReview,
                    onOpenCandidateOutcomeReview:
                        onOpenCandidateOutcomeReview,
                    onOpen: onOpenExperiment,
                    onRequestDelete: onRequestDeleteExperiment
                )
            }
            .forzAdvisorRowBackground()
        }
    }

    private func readinessSymbol(
        for state: FH5NumericReadinessState
    ) -> String {
        switch state {
        case .complete: "checkmark.circle.fill"
        case .pending: "circle.dotted"
        case .blocked: "lock.circle.fill"
        }
    }

    private func readinessColor(
        for state: FH5NumericReadinessState
    ) -> Color {
        switch state {
        case .complete: ForzAdvisorTheme.success
        case .pending: .secondary
        case .blocked: ForzAdvisorTheme.warning
        }
    }
}

private struct FH5ControlledExperimentSummary: View {
    let record: FH5ControlledExperimentRecord?
    let candidateTrialAvailable: Bool
    let candidateOutcomeReport: FH5ControlledOutcomePolicyReport?
    let candidateTrialArtifact: FH5GeneratedCandidateArtifact?
    let candidateOutcomeCollectionReport:
        FH5CandidateOutcomeCollectionReport
    let canOpenCandidateOutcomeReview: Bool
    let onOpenCandidateOutcomeReview: () -> Void
    let onOpen: (() -> Void)?
    let onRequestDelete: (FH5ControlledExperimentRecord) -> Void
    @State private var showsCandidateShareConfirmation = false
    @State private var candidateShareAuthorization =
        FH5CandidateOutcomeShareAuthorization()
    @State private var candidateSharePayload:
        FH5CandidateOutcomeSharePayload?

    var body: some View {
        Group {
            if let onOpen {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        candidateTrialAvailable
                            ? "Run one experimental candidate trial"
                            : "Run one controlled paired experiment",
                        systemImage: "testtube.2"
                    )
                    .font(.subheadline.weight(.semibold))
                    Text(
                        candidateTrialAvailable
                            ? "Replicated evidence qualifies this saved plan for one generated A-B-B-A hypothesis. It is not a tune or advice, and the candidate stays locked inside Outcome Lab."
                            : "Outcome Lab guides a fixed A-B-B-A Horizon Test Track test. It changes one adjustable control by one observed step, then requires a return to stock."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Button(
                        candidateTrialAvailable
                            ? "Open Experimental Candidate Trial"
                            : "Open FH5 Outcome Lab",
                        action: onOpen
                    )
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier(
                            "openFH5ControlledExperimentButton"
                        )
                }
                .padding(.vertical, 2)
            }

            if let record {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        "Latest paired experiment recorded",
                        systemImage: "checkmark.circle"
                    )
                    .font(.subheadline.weight(.semibold))
                    if record.schemaVersion
                        == FH5ControlledExperimentRecord
                            .calibrationSchemaVersion {
                        Text(
                            "\(record.change.field.projectionLabel): \(formatted(record.change.baselineValue, unit: record.change.unit)) → \(formatted(record.change.candidateValue, unit: record.change.unit))"
                        )
                        .font(.caption)
                    } else {
                        Text(
                            "Candidate-bound experimental outcome saved locally. The candidate value is not added to this plan or exposed as tune output."
                        )
                        .font(.caption)
                    }
                    Text(
                        "\(record.targetSymptom.title) · \(record.outcome.title)"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Text(
                        "Calibration evidence only. No numeric ruleset or tune was promoted."
                    )
                    .font(.caption)
                    .foregroundStyle(ForzAdvisorTheme.warning)

                    if record.schemaVersion
                        == FH5ControlledExperimentRecord
                            .candidateBoundSchemaVersion {
                        Text(
                            "Candidate outcomes can be shared only as explicit, deidentified experiment JSON. They are not tunes and cannot unlock numeric FH5 output."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        if let report = candidateOutcomeReport {
                            Label(
                                "\(report.matchingRecordCount)/\(FH5ControlledOutcomeThreshold.currentExperimental.minimumUniqueRecords) exact local candidate outcomes collected",
                                systemImage: "chart.bar.doc.horizontal"
                            )
                            .font(.caption.weight(.semibold))
                            Text(
                                "Variant preferred: \(report.variantPreferredCount) · Baseline preferred: \(report.baselinePreferredCount) · Non-decisive: \(report.nonDecisiveCount)"
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }

                        if candidateArtifactMatchesRecord,
                           record.attestations
                            .deidentifiedReusePermitted {
                            Button {
                                showsCandidateShareConfirmation = true
                            } label: {
                                Label(
                                    "Review One-Time Share",
                                    systemImage:
                                        "square.and.arrow.up"
                                )
                                .frame(
                                    maxWidth: .infinity,
                                    minHeight: 44,
                                    alignment: .leading
                                )
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier(
                                "shareFH5CandidateOutcomeButton"
                            )
                            Text(
                                "Manual system share only. No background upload. The recipient must regenerate the exact candidate locally and confirm direct receipt and reuse permission."
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        } else {
                            Text(
                                "Sharing requires deidentified reuse permission and an exact locally regenerated candidate."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    } else if let json = record.deterministicJSONString {
                        ShareLink(
                            item: json,
                            subject: Text(
                                "ForzAdvisor FH5 paired experiment"
                            )
                        ) {
                            Label(
                                "Share deidentified experiment JSON",
                                systemImage: "square.and.arrow.up"
                            )
                            .frame(
                                maxWidth: .infinity,
                                minHeight: 44,
                                alignment: .leading
                            )
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier(
                            "shareFH5ControlledExperimentButton"
                        )
                    } else {
                        Text(
                            "JSON sharing is unavailable because deidentified calibration reuse was not enabled for this record."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Button(
                        "Delete latest local experiment",
                        role: .destructive
                    ) {
                        onRequestDelete(record)
                    }
                    .accessibilityIdentifier(
                        "deleteFH5ControlledExperimentButton"
                    )
                }
                .padding(.vertical, 2)
            }

            if canOpenCandidateOutcomeReview,
               candidateTrialArtifact != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        "Review exact experimental candidate outcomes",
                        systemImage:
                            "rectangle.stack.badge.checkmark"
                    )
                    .font(.subheadline.weight(.semibold))
                    Text(
                        "Only canonical, permission-bound outcomes for the exact candidate independently regenerated on this device can enter the separate review queue."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Button(
                        "Open Candidate Outcome Review",
                        action: onOpenCandidateOutcomeReview
                    )
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(
                        "openFH5CandidateOutcomeReviewButton"
                    )
                    Text(
                        candidateOutcomeCollectionReport.summary
                    )
                    .font(.caption)
                }
                .padding(.vertical, 2)
            }
        }
        .confirmationDialog(
            "Share this exact candidate outcome?",
            isPresented: $showsCandidateShareConfirmation,
            titleVisibility: .visible
        ) {
            Button("Share This Candidate Outcome") {
                candidateShareAuthorization.confirm()
                guard let record,
                      let artifact = candidateTrialArtifact,
                      let export = try?
                        FH5CandidateOutcomeExchange().prepareShare(
                            from: record,
                            currentArtifact: artifact,
                            authorization:
                                &candidateShareAuthorization
                        ),
                      let json = export.deterministicJSONString else {
                    candidateShareAuthorization.invalidate()
                    candidateSharePayload = nil
                    return
                }
                candidateSharePayload =
                    FH5CandidateOutcomeSharePayload(json: json)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This one share contains the exact experiment context, change, and outcome. Copies cannot be recalled."
            )
        }
        .sheet(item: $candidateSharePayload) { payload in
            FH5CandidateOutcomeSystemShareSheet(
                activityItems: [payload.json]
            )
        }
        .onChange(of: candidateShareStateIdentity) {
            showsCandidateShareConfirmation = false
            candidateShareAuthorization.invalidate()
            candidateSharePayload = nil
        }
    }

    private func formatted(_ value: Double, unit: TuneUnit) -> String {
        let number = value.formatted(
            .number.precision(.fractionLength(0...3))
        )
        return "\(number) \(unit.rawValue)"
    }

    private var candidateArtifactMatchesRecord: Bool {
        guard let record,
              let artifact = candidateTrialArtifact else {
            return false
        }
        return FH5CandidateOutcomeExchange().canShare(
            record,
            currentArtifact: artifact
        )
    }

    private var candidateShareStateIdentity: String {
        [
            record?.recordID.uuidString ?? "no-record",
            record?.contentFingerprint ?? "no-record-content",
            record?.candidateBinding?
                .generatedCandidateFingerprint
                ?? "no-record-binding",
            candidateTrialArtifact?.candidateBinding
                .generatedCandidateFingerprint
                ?? "no-current-artifact"
        ].joined(separator: "|")
    }
}

private struct FH5CandidateOutcomeSharePayload: Identifiable {
    let id = UUID()
    let json: String
}

private struct FH5CandidateOutcomeSystemShareSheet:
    UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(
        context: Context
    ) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}

private struct TuneSectionsGroup: View {
    let sections: [TuneSection]
    let isStreaming: Bool
    let allowsCopy: Bool
    @Binding var expandedSectionTitles: Set<String>
    @Binding var copiedLineID: TuneLine.ID?

    var body: some View {
        Group {
            if !sections.isEmpty {
                Section {
                    HStack(spacing: 10) {
                        Button("Expand all") {
                            expandedSectionTitles = Set(sections.map(\.title))
                        }
                        .buttonStyle(.bordered)
                        .disabled(isStreaming)

                        Button("Collapse all") {
                            expandedSectionTitles.removeAll()
                        }
                        .buttonStyle(.bordered)
                        .disabled(isStreaming)
                    }
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .forzAdvisorRowBackground()
            }

            ForEach(sections) { section in
                Section {
                    TuneSectionDisclosureView(
                        section: section,
                        isStreaming: isStreaming,
                        allowsCopy: allowsCopy,
                        isExpanded: expandedBinding(for: section),
                        copiedLineID: $copiedLineID
                    )
                }
                .forzAdvisorRowBackground()
            }
        }
    }

    private func expandedBinding(for section: TuneSection) -> Binding<Bool> {
        Binding {
            expandedSectionTitles.contains(section.title)
        } set: { isExpanded in
            if isExpanded {
                expandedSectionTitles.insert(section.title)
            } else {
                expandedSectionTitles.remove(section.title)
            }
        }
    }
}

private struct TuneExportSection: View {
    let tune: TuneResult
    let shareCard: VerifiedBuildShareCard?
    let isStreaming: Bool
    @Binding var copiedExport: CopiedExport?
    @Binding var copiedLineID: TuneLine.ID?

    private var verifiedText: String? {
        TuneClipboardFormatter.verifiedSettingsText(for: tune)
    }

    private var buildPlanText: String? {
        TuneClipboardFormatter.buildPlanText(for: tune)
    }

    var body: some View {
        if !isStreaming, verifiedText != nil || buildPlanText != nil {
            Section("Take It To The Game") {
                if let verifiedText {
                    exportButton(
                        title: "Copy verified settings",
                        copiedTitle: "Copied verified settings",
                        text: verifiedText,
                        kind: .verifiedSettings,
                        prominent: true
                    )
                }
                if let buildPlanText {
                    exportButton(
                        title: "Copy build plan",
                        copiedTitle: "Copied build plan",
                        text: buildPlanText,
                        kind: .buildPlan,
                        prominent: false
                    )
                }
                if let shareCard {
                    VStack(alignment: .leading, spacing: 8) {
                        ShareLink(
                            item: shareCard.text,
                            subject: Text(shareCard.subject)
                        ) {
                            Label(
                                "Share verified build",
                                systemImage: "square.and.arrow.up"
                            )
                            .frame(
                                maxWidth: .infinity,
                                minHeight: 44,
                                alignment: .leading
                            )
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("shareVerifiedBuildButton")
                        .accessibilityHint(
                            "Opens the system share sheet with only this verified build card."
                        )

                        Text(
                            "Sharing sends this card to an app you choose. Garage notes and screenshots are excluded."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
            .forzAdvisorRowBackground()
        }
    }

    @ViewBuilder
    private func exportButton(
        title: String,
        copiedTitle: String,
        text: String,
        kind: CopiedExport,
        prominent: Bool
    ) -> some View {
        if prominent {
            exportActionButton(
                title: title,
                copiedTitle: copiedTitle,
                text: text,
                kind: kind
            )
            .buttonStyle(.borderedProminent)
        } else {
            exportActionButton(
                title: title,
                copiedTitle: copiedTitle,
                text: text,
                kind: kind
            )
            .buttonStyle(.bordered)
        }
    }

    private func exportActionButton(
        title: String,
        copiedTitle: String,
        text: String,
        kind: CopiedExport
    ) -> some View {
        Button {
            UIPasteboard.general.string = text
            copiedLineID = nil
            copiedExport = kind
        } label: {
            Label(
                copiedExport == kind ? copiedTitle : title,
                systemImage: copiedExport == kind ? "checkmark" : "doc.on.doc"
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier(kind.accessibilityIdentifier)
    }
}

private enum CopiedExport {
    case verifiedSettings
    case buildPlan

    var accessibilityIdentifier: String {
        switch self {
        case .verifiedSettings: "copyVerifiedSettingsButton"
        case .buildPlan: "copyBuildPlanButton"
        }
    }
}

private struct TuneCoverageView: View {
    let report: TuneProjectionReport
    let showsAlternativePathSummary: Bool
    let isPlanOnly: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(summary, systemImage: report.readyCount > 0 ? "checkmark.shield" : "shield.lefthalf.filled")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(report.readyCount > 0 ? ForzAdvisorTheme.accent : ForzAdvisorTheme.warning)

            if showsAlternativePathSummary {
                Text("Exact alternative buy lists are shown under Tuning-Control Upgrade Paths.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !report.purchasePlan.isEmpty {
                coverageGroup(title: "Buy to unlock") {
                    ForEach(report.purchasePlan, id: \.part.id) { item in
                        Text("\(item.part.label) — \(item.unlocks.map(\.projectionLabel).joined(separator: ", "))")
                    }
                }
            }

            if !report.confirmations.isEmpty {
                coverageGroup(title: "Confirm installed or available in game") {
                    ForEach(report.confirmations, id: \.setting.id) { item in
                        Text("\(item.setting.projectionLabel): \(item.candidateParts.map(\.label).joined(separator: " or "))")
                    }
                }
            }

            if report.requiresInGameConfirmation {
                Text("Exact tuning-screen ranges are still needed before withheld numbers can be trusted.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("tuneCoverage")
    }

    private var summary: String {
        if isPlanOnly {
            return "Build planning only — no numeric settings included"
        }
        if report.readyCount == 0 {
            return "No generated settings verified yet"
        }
        return "\(report.readyCount) verified setting\(report.readyCount == 1 ? "" : "s")"
    }

    private func coverageGroup<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
                .font(.caption)
        }
    }
}

private struct ProviderStatusView: View {
    let tune: TuneResult

    private var statusTitle: String {
        tune.purpose == .fh5BuildPlan
            ? "Local FH5 build planner"
            : tune.providerInfo?.statusTitle ?? "Provider not recorded"
    }

    private var statusDetail: String {
        tune.purpose == .fh5BuildPlan
            ? "Created locally without formulas, a model, an API, or numeric tuning values."
            : tune.providerInfo?.statusDetail ?? "This saved tune was created before provider tracking."
    }

    private var symbolName: String {
        tune.purpose == .fh5BuildPlan
            ? "wrench.and.screwdriver"
            : tune.providerInfo?.symbolName ?? "questionmark.circle"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbolName)
                .font(.caption.weight(.semibold))
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.caption.weight(.semibold))
                Text(statusDetail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(tune.providerInfo?.fallbackReason == nil ? ForzAdvisorTheme.accent : ForzAdvisorTheme.warning)
        .accessibilityIdentifier("providerStatus")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(statusTitle)
        .accessibilityValue(statusDetail)
    }
}

private struct GuidedRefinementView: View {
    let feedbackOptions: [TuneFeedback]
    let activeFeedback: TuneFeedback?
    let onFeedback: (TuneFeedback) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What happened on the last run?")
                .font(.subheadline.weight(.semibold))
            Text("Pick the closest symptom and ForzAdvisor will make a bounded change, then explain every moved setting.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(feedbackOptions) { feedback in
                    Button {
                        onFeedback(feedback)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                if activeFeedback == feedback {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: feedback.symbolName)
                                        .frame(width: 18)
                                }

                                Text(feedback.title)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.85)

                                Spacer(minLength: 0)
                            }

                            Text(feedback.prompt)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .frame(minHeight: 72, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            ForzAdvisorTheme.mutedSurface,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(ForzAdvisorTheme.separator, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(activeFeedback != nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("feedbackButton-\(feedback.rawValue)")
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(feedback.title)
                    .accessibilityHint(feedback.prompt)
                    .accessibilityValue(activeFeedback == feedback ? "Adjusting" : "")
                }
            }
        }
    }
}

private struct AdjustmentChangeRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let change: TuneAdjustmentChange

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    changeText
                    changeValues
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    changeText

                    Spacer(minLength: 16)

                    changeValues
                }
            }
        }
        .padding(.vertical, 3)
        .accessibilityIdentifier("adjustmentChangeRow")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var changeText: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(change.lineLabel)
                .font(.subheadline.weight(.semibold))
            Text(change.sectionTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let rationale = change.rationale {
                Text(rationale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var changeValues: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(change.oldValue)
                .foregroundStyle(.secondary)
            Image(systemName: "arrow.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            Text(change.newValue)
                .fontWeight(.semibold)
                .foregroundStyle(ForzAdvisorTheme.accent)
            if !change.unit.isEmpty {
                Text(change.unit)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(.subheadline, design: .monospaced))
    }

    private var accessibilityLabel: String {
        var parts = [
            "\(change.lineLabel), \(change.sectionTitle)",
            "changed from \(change.oldValue) to \(change.newValue)\(change.unit.isEmpty ? "" : " \(change.unit)")"
        ]
        if let rationale = change.rationale {
            parts.append(rationale)
        }
        return parts.joined(separator: ". ")
    }
}

private struct NoteRow: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.body)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}
