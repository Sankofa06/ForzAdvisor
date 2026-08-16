//
//  FH6IndependentReviewFilesView.swift
//  forzadvisor
//

import SwiftUI

struct FH6IndependentReviewFilesView: View {
    let tune: TuneResult
    @Binding var state: FH6IndependentReviewPresentationState
    let preparedInputStateFingerprint: String?
    let onPrepare: (() throws -> String)?
    let candidateRevisionFingerprint: String?
    let onValidate: ((Data) throws -> FH6IndependentValidationReviewPacket)?

    var body: some View {
        Form {
            Section("Review-only files") {
                Text("Create a file for an independent human reviewer, or inspect a file someone shared with you. Neither action changes or validates the tune.")
                    .font(.subheadline)
                Text("Pasted files remain in memory only and are cleared when Validation Review closes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .forzAdvisorRowBackground()

            if let onPrepare {
                prepareSection(onPrepare: onPrepare)
            }

            if let onValidate, candidateRevisionFingerprint != nil {
                inspectSection(onValidate: onValidate)
            }

            if onPrepare == nil && onValidate == nil {
                Section {
                    ContentUnavailableView(
                        "Review Files Unavailable",
                        systemImage: "doc.badge.ellipsis",
                        description: Text("This saved setup is not currently eligible to create or inspect an independent review file.")
                    )
                }
                .forzAdvisorRowBackground()
            }

            Section {
                DisclosureGroup("Technical details") {
                    Text(FH6IndependentValidationReviewPacketPolicy.reviewBoundary)
                    Text("Exact candidate revision, evidence digests, permission bindings, duplicate, conflict, replay, quarantine, schema, and integrity fingerprint checks remain fail-closed.")
                    if let message = state.preparationTechnicalMessage {
                        Text("File preparation: \(message)")
                    }
                    if let message = state.inspectionTechnicalMessage {
                        Text("File inspection: \(message)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .forzAdvisorRowBackground()
        }
        .navigationTitle("Independent Review Files")
        .navigationBarTitleDisplayMode(.inline)
        .forzAdvisorScreenChrome()
        .onChange(of: preparedInputStateFingerprint) {
            state.clearPreparedFile()
        }
        .onChange(of: candidateRevisionFingerprint) {
            state.clearInspection()
        }
    }

    @ViewBuilder
    private func prepareSection(onPrepare: @escaping () throws -> String) -> some View {
        Section("Create a review file") {
            Text("Uses the currently eligible, permission-bound evidence for this exact saved setup.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Prepare Review File") {
                do {
                    state.preparedPacket = try onPrepare()
                    state.preparationMessage = "Review-only file prepared from the current eligible evidence."
                    state.preparationTechnicalMessage = nil
                } catch {
                    state.preparedPacket = nil
                    state.preparationMessage = "A review file could not be prepared from the current eligible evidence."
                    state.preparationTechnicalMessage = error.localizedDescription
                }
            }
            .accessibilityIdentifier("prepareFH6IndependentValidationReviewPacketButton")

            if let preparedPacket = state.preparedPacket {
                ShareLink(item: preparedPacket) {
                    Label("Share Review File", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("shareFH6IndependentValidationReviewPacketButton")
            }

            if let message = state.preparationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .forzAdvisorRowBackground()
    }

    @ViewBuilder
    private func inspectSection(
        onValidate: @escaping (Data) throws -> FH6IndependentValidationReviewPacket
    ) -> some View {
        Section("Inspect a shared review file") {
            TextEditor(text: $state.pastedPacketJSON)
                .font(.caption.monospaced())
                .frame(minHeight: 170)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: state.pastedPacketJSON) {
                    state.pastedPacketChanged()
                }
                .accessibilityLabel("Shared independent review file text")
                .accessibilityHint("Paste the complete review file shared from ForzAdvisor.")
                .accessibilityIdentifier("fh6IndependentValidationReviewPacketJSON")

            Button("Check Review File") {
                validatePaste(using: onValidate)
            }
            .disabled(!state.hasPastedPacketText)
            .accessibilityIdentifier("validateFH6IndependentValidationReviewPacketButton")

            if let packet = state.validatedPacket {
                Label("Review file accepted for inspection", systemImage: "checkmark.seal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ForzAdvisorTheme.success)
                    .accessibilityIdentifier("fh6IndependentValidationReviewPacketAccepted")
                FH6IndependentReviewFileSummary(
                    carDisplayName: tune.request.car.displayName,
                    packet: packet
                )
            }

            if let message = state.inspectionMessage {
                Label(
                    message,
                    systemImage: state.inspectionIsError
                        ? "exclamationmark.triangle" : "checkmark.circle"
                )
                .font(.caption)
                .foregroundStyle(
                    state.inspectionIsError ? ForzAdvisorTheme.warning : .secondary
                )
                .accessibilityIdentifier("fh6IndependentValidationReviewPacketStatus")
            }

            Button("Clear Pasted File") { state.clearInspection() }
                .disabled(
                    !state.hasPastedPacketText
                        && state.validatedPacket == nil
                        && state.inspectionMessage == nil
                )
                .accessibilityIdentifier("clearFH6IndependentValidationReviewPacketButton")
        }
        .forzAdvisorRowBackground()
    }

    private func validatePaste(
        using onValidate: (Data) throws -> FH6IndependentValidationReviewPacket
    ) {
        do {
            state.validatedPacket = try onValidate(Data(state.pastedPacketJSON.utf8))
            state.inspectionMessage = "Checked against the exact current saved FH6 setup. Nothing was imported or saved."
            state.inspectionTechnicalMessage = nil
            state.inspectionIsError = false
        } catch {
            state.validatedPacket = nil
            state.inspectionMessage = "This file could not be accepted. Nothing was imported or saved."
            state.inspectionTechnicalMessage = error.localizedDescription
            state.inspectionIsError = true
        }
    }
}
