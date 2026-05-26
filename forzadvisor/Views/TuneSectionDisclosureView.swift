//
//  TuneSectionDisclosureView.swift
//  forzadvisor
//
//  Collapsible tune-menu section card used by TuneResultView. It keeps value
//  copy affordances close to each line while TuneResultView owns screen flow.
//

import SwiftUI
import UIKit

struct TuneSectionDisclosureView: View {
    let section: TuneSection
    let isStreaming: Bool
    @Binding var isExpanded: Bool
    @Binding var copiedLineID: TuneLine.ID?

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 0) {
                if section.lines.isEmpty && isStreaming {
                    LoadingTuneSectionRow()
                }

                ForEach(section.lines) { line in
                    TuneLineCopyRow(
                        line: line,
                        isStreaming: isStreaming,
                        copiedLineID: $copiedLineID
                    )

                    if line.id != section.lines.last?.id {
                        Divider()
                            .padding(.leading, 2)
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: section.symbolName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ForzAdvisorTheme.accent)
                    .frame(width: 22)

                Text(section.title)
                    .font(.headline)

                Spacer()

                Text(section.lines.isEmpty ? "pending" : "\(section.lines.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(section.title), \(isExpanded ? "expanded" : "collapsed")")
        }
        .tint(ForzAdvisorTheme.accent)
        .padding(.vertical, 4)
    }
}

private struct TuneLineCopyRow: View {
    let line: TuneLine
    let isStreaming: Bool
    @Binding var copiedLineID: TuneLine.ID?

    var body: some View {
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
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .disabled(isStreaming)
    }
}

private struct LoadingTuneSectionRow: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("Waiting for values")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

extension TuneSection {
    static let menuOrder: [(title: String, symbolName: String)] = [
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
