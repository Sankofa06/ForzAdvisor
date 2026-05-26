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
    let activeAdjustment: TuneAdjustment?
    let onDone: () -> Void
    let onSave: () -> Void
    let onEdit: () -> Void
    let onAdjust: (TuneAdjustment) -> Void

    @State private var copiedLineID: TuneLine.ID?
    @State private var expandedSectionTitles = Set(TuneSection.menuOrder.map(\.title))
    @State private var didCopyFullTune = false

    private var isAdjusting: Bool {
        activeAdjustment != nil
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
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(ForzAdvisorTheme.heroRowBackground)

            Section {
                Button {
                    UIPasteboard.general.string = TuneClipboardFormatter.fullTuneText(
                        for: tune,
                        playerNotes: playerNotes
                    )
                    copiedLineID = nil
                    didCopyFullTune = true
                } label: {
                    Label(
                        didCopyFullTune ? "Copied full tune" : "Copy full tune",
                        systemImage: didCopyFullTune ? "checkmark" : "doc.on.doc"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isStreaming)
            }
            .forzAdvisorRowBackground()

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

            if isSaved && !isStreaming {
                Section("Adjust Feel") {
                    AdjustmentGrid(
                        activeAdjustment: activeAdjustment,
                        onAdjust: onAdjust
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

            ForEach(displaySections) { section in
                Section {
                    TuneSectionDisclosureView(
                        section: section,
                        isStreaming: isStreaming,
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
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                if isSaved {
                    Button("Edit", action: onEdit)
                        .disabled(isAdjusting || isStreaming)
                }
                Button(isSaved ? "Saved" : "Save", action: onSave)
                    .disabled(isSaved || isAdjusting || isStreaming)
            }
        }
    }

    private var displaySections: [TuneSection] {
        guard isStreaming else { return tune.sections }
        return TuneSection.menuOrder.map { item in
            tune.section(item.title) ?? TuneSection(
                title: item.title,
                symbolName: item.symbolName,
                lines: []
            )
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

private struct AdjustmentGrid: View {
    let activeAdjustment: TuneAdjustment?
    let onAdjust: (TuneAdjustment) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(TuneAdjustment.allCases) { adjustment in
                Button {
                    onAdjust(adjustment)
                } label: {
                    HStack(spacing: 8) {
                        if activeAdjustment == adjustment {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: adjustment.symbolName)
                                .frame(width: 18)
                        }

                        Text(adjustment.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                    .padding(.horizontal, 10)
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
                .disabled(activeAdjustment != nil)
            }
        }
    }
}

private struct AdjustmentChangeRow: View {
    let change: TuneAdjustmentChange

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(change.lineLabel)
                    .font(.subheadline.weight(.semibold))
                Text(change.sectionTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(change.oldValue)
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
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
        .padding(.vertical, 3)
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
    }
}
