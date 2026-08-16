//
//  FH6IndependentReviewFileSummary.swift
//  forzadvisor
//

import SwiftUI

struct FH6IndependentReviewFileSummary: View {
    let carDisplayName: String
    let packet: FH6IndependentValidationReviewPacket

    var body: some View {
        Group {
            LabeledContent("Car", value: carDisplayName)
            LabeledContent(
                "Test drives",
                value: "\(packet.counts.includedFirstPartyTestDriveCount)"
            )
            LabeledContent(
                "Sender-local community outcomes",
                value: "\(packet.counts.includedLocalCommunityOutcomeCount)"
            )
            LabeledContent(
                "Permission-bound reviewed outcomes",
                value: "\(packet.counts.includedReviewedCommunityOutcomeCount)"
            )
            LabeledContent(
                "Total accepted evidence",
                value: "\(packet.counts.includedEvidenceCount)"
            )
            Label("Accuracy not established", systemImage: "xmark.shield")
            Label("Automatic promotion not permitted", systemImage: "hand.raised")
            Label("Independent human review required", systemImage: "person.badge.shield.checkmark")

            DisclosureGroup("Technical details") {
                LabeledContent("Catalog ID", value: packet.candidate.catalogID)
                fingerprint("Candidate binding", packet.candidate.bindingFingerprint)
                fingerprint("File fingerprint", packet.artifactFingerprint)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func fingerprint(_ title: String, _ value: String) -> some View {
        let prefix = String(value.prefix(12))
        return LabeledContent(title) {
            Text(prefix).font(.caption.monospaced())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) fingerprint")
        .accessibilityValue("Prefix \(prefix)")
    }
}
