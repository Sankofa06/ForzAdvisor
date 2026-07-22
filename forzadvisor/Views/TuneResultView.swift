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
    let onVerifyTirePressures: (() -> Void)?
    let onVerifyUpgradeParts: (() -> Void)?
    let onFeedback: (TuneFeedback) -> Void

    @State private var copiedLineID: TuneLine.ID?
    @State private var expandedSectionTitles = Set(TuneSection.menuOrder.map(\.title))
    @State private var copiedExport: CopiedExport?

    private var isAdjusting: Bool {
        activeFeedback != nil
    }

    private var upgradePaths: [TuneControlUpgradePath] {
        TuneControlUpgradePlanner().paths(for: tune)
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
                        ProviderStatusView(providerInfo: tune.providerInfo)
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
                Section("Tune Coverage") {
                    TuneCoverageView(
                        report: report,
                        showsAlternativePathSummary: !upgradePaths.isEmpty
                    )
                }
                .forzAdvisorRowBackground()

                if !isStreaming, let onVerifyTirePressures {
                    Section("Tune Lab") {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Unlock verified tire settings", systemImage: "gauge.with.dots.needle.33percent")
                                .font(.subheadline.weight(.semibold))
                            Text("Read the front and rear ranges from the FH6 tire-pressure screen. ForzAdvisor keeps the observation on this device and regenerates this tune against the exact sliders.")
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

                if !isStreaming,
                   TuneClipboardFormatter.verifiedSettingsText(for: tune) != nil
                    || TuneClipboardFormatter.buildPlanText(for: tune) != nil {
                    Section("Take It To The Game") {
                        if let verifiedText = TuneClipboardFormatter.verifiedSettingsText(for: tune) {
                            exportButton(
                                title: "Copy verified settings",
                                copiedTitle: "Copied verified settings",
                                text: verifiedText,
                                kind: .verifiedSettings,
                                prominent: true
                            )
                        }
                        if let buildPlanText = TuneClipboardFormatter.buildPlanText(for: tune) {
                            exportButton(
                                title: "Copy build plan",
                                copiedTitle: "Copied build plan",
                                text: buildPlanText,
                                kind: .buildPlan,
                                prominent: false
                            )
                        }
                    }
                    .forzAdvisorRowBackground()
                }
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

            if isSaved && !isStreaming && !eligibleFeedback.isEmpty {
                Section("Guided Refinement") {
                    GuidedRefinementView(
                        feedbackOptions: eligibleFeedback,
                        activeFeedback: activeFeedback,
                        onFeedback: onFeedback
                    )
                    .padding(.vertical, 4)
                }
                .forzAdvisorRowBackground()
            }

            if !adjustmentChanges.isEmpty {
                Section("Last changes") {
                    ForEach(adjustmentChanges) { change in
                        AdjustmentChangeRow(change: change)
                    }
                }
                .forzAdvisorRowBackground()
            }

            if !displaySections.isEmpty {
                Section {
                    HStack(spacing: 10) {
                        Button("Expand all") {
                            expandedSectionTitles = Set(displaySections.map(\.title))
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

            ForEach(displaySections) { section in
                Section {
                    TuneSectionDisclosureView(
                        section: section,
                        isStreaming: isStreaming,
                        allowsCopy: tune.projectionReport != nil,
                        isExpanded: expandedBinding(for: section),
                        copiedLineID: $copiedLineID
                    )
                }
                .forzAdvisorRowBackground()
            }

            Section("Notes") {
                NoteRow(title: "Bias", text: tune.notes.bias)
                NoteRow(title: "If pushes wide", text: tune.notes.ifPushesWide)
                NoteRow(title: "If snaps on lift", text: tune.notes.ifSnapsOnLift)
                NoteRow(title: "Retune", text: tune.notes.retuneTrigger)
            }
            .forzAdvisorRowBackground()

            if !playerNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section("Garage Notes") {
                    Text(playerNotes)
                }
                .forzAdvisorRowBackground()
            }
        }
        .navigationTitle("Tune")
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
        let report = tune.projectionReport
        let hasPlan = !(report?.purchasePlan.isEmpty ?? true)
            || !(report?.confirmations.isEmpty ?? true)
        if report?.readyCount == 0, hasPlan {
            return "Save Plan"
        }
        return "Save"
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
    let providerInfo: TuneProviderInfo?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: providerInfo?.symbolName ?? "questionmark.circle")
                .font(.caption.weight(.semibold))
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(providerInfo?.statusTitle ?? "Provider not recorded")
                    .font(.caption.weight(.semibold))
                Text(providerInfo?.statusDetail ?? "This saved tune was created before provider tracking.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(providerInfo?.fallbackReason == nil ? ForzAdvisorTheme.accent : ForzAdvisorTheme.warning)
        .accessibilityIdentifier("providerStatus")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(providerInfo?.statusTitle ?? "Provider not recorded")
        .accessibilityValue(providerInfo?.statusDetail ?? "This saved tune was created before provider tracking.")
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
