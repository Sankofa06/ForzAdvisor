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

            if isSaved {
                Section("Adjust Feel") {
                    AdjustmentGrid(
                        activeAdjustment: activeAdjustment,
                        onAdjust: onAdjust
                    )
                    .padding(.vertical, 4)
                }
            }

            if !adjustmentChanges.isEmpty {
                Section("Last changes") {
                    ForEach(adjustmentChanges) { change in
                        AdjustmentChangeRow(change: change)
                    }
                }
            }

            ForEach(tune.sections) { section in
                Section {
                    TuneSectionView(section: section, copiedLineID: $copiedLineID)
                } header: {
                    Label(section.title, systemImage: section.symbolName)
                }
            }

            Section("Notes") {
                NoteRow(title: "Bias", text: tune.notes.bias)
                NoteRow(title: "If pushes wide", text: tune.notes.ifPushesWide)
                NoteRow(title: "If snaps on lift", text: tune.notes.ifSnapsOnLift)
                NoteRow(title: "Retune", text: tune.notes.retuneTrigger)
            }

            if !playerNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section("Garage Notes") {
                    Text(playerNotes)
                }
            }
        }
        .navigationTitle("Tune")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done", action: onDone)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                if isSaved {
                    Button("Edit", action: onEdit)
                        .disabled(isAdjusting)
                }
                Button(isSaved ? "Saved" : "Save", action: onSave)
                    .disabled(isSaved || isAdjusting)
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
                    .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
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
    @Binding var copiedLineID: TuneLine.ID?

    var body: some View {
        ForEach(section.lines) { line in
            Button {
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
