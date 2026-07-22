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
    var allowsCopy = true
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
                        allowsCopy: allowsCopy,
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let line: TuneLine
    let isStreaming: Bool
    let allowsCopy: Bool
    @Binding var copiedLineID: TuneLine.ID?

    var body: some View {
        Button {
            guard !isStreaming, allowsCopy else { return }
            UIPasteboard.general.string = line.copyText
            copiedLineID = line.id
            UIAccessibility.post(
                notification: .announcement,
                argument: "Copied \(line.label), \(spokenValue)"
            )
        } label: {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) {
                        lineText
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            lineValue
                            copyIcon
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        lineText

                        Spacer(minLength: 16)

                        lineValue
                        copyIcon
                    }
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .disabled(isStreaming || !allowsCopy)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(line.label)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
    }

    private var lineText: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(line.label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let detail = line.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var lineValue: some View {
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
    }

    private var copyIcon: some View {
        Image(systemName: copiedLineID == line.id ? "checkmark" : "doc.on.doc")
            .font(.caption.weight(.semibold))
            .foregroundColor(copiedLineID == line.id ? .green : .gray)
            .frame(width: 16)
            .accessibilityHidden(true)
    }

    private var spokenValue: String {
        line.unit.isEmpty ? line.value : "\(line.value) \(line.unit)"
    }

    private var accessibilityValue: String {
        if let detail = line.detail {
            return "\(spokenValue). \(detail)"
        }
        return spokenValue
    }

    private var accessibilityHint: String {
        if isStreaming {
            return "Values are still streaming."
        }
        if !allowsCopy {
            return "This legacy value is unverified and cannot be copied."
        }
        if copiedLineID == line.id {
            return "Copied to clipboard."
        }
        return "Copies this setting to the clipboard."
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
