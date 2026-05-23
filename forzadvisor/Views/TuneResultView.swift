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

            ForEach(displaySections) { section in
                Section {
                    TuneSectionView(
                        section: section,
                        isStreaming: isStreaming,
                        copiedLineID: $copiedLineID
                    )
                } header: {
                    Label(section.title, systemImage: section.symbolName)
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
        return TuneSection.loadingOrder.map { item in
            tune.section(item.title) ?? TuneSection(
                title: item.title,
                symbolName: item.symbolName,
                lines: []
            )
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

private struct TuneSectionView: View {
    let section: TuneSection
    let isStreaming: Bool
    @Binding var copiedLineID: TuneLine.ID?

    var body: some View {
        if section.lines.isEmpty && isStreaming {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Waiting for values")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }

        ForEach(section.lines) { line in
            Button {
                guard !isStreaming else { return }
                UIPasteboard.general.string = line.copyText
                copiedLineID = line.id
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(line.label)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let detail = line.detail {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer(minLength: 16)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(line.value)
                            .font(.system(.title3, design: .monospaced).weight(.semibold))
                            .foregroundStyle(ForzAdvisorTheme.accent)
                        if !line.unit.isEmpty {
                            Text(line.unit)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Image(systemName: copiedLineID == line.id ? "checkmark" : "doc.on.doc")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(copiedLineID == line.id ? .green : .gray)
                        .frame(width: 16)
                }
                .contentShape(Rectangle())
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .disabled(isStreaming)
        }
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

private extension TuneSection {
    static let loadingOrder: [(title: String, symbolName: String)] = [
        ("Tires", "circle.dashed"),
        ("Gearing", "gearshape.2"),
        ("Alignment", "arrow.left.and.right"),
        ("Antiroll Bars", "arrow.up.left.and.arrow.down.right"),
        ("Springs", "waveform.path.ecg"),
        ("Damping", "slider.horizontal.3"),
        ("Aero", "wind"),
        ("Brakes", "exclamationmark.octagon"),
        ("Differential", "point.3.connected.trianglepath.dotted")
    ]
}
