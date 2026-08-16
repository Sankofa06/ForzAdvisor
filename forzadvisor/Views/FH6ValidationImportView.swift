//
//  FH6ValidationImportView.swift
//  forzadvisor
//

import SwiftUI

struct FH6ValidationImportView: View {
    let tune: TuneResult
    let storageError: String?
    @Binding var state: FH6ValidationImportPresentationState
    @Binding var packetState: FH6IndependentReviewPresentationState
    let onImport: (FH6ValidationReviewEntry) -> String?

    var body: some View {
        Form {
            Section("How this works") {
                Text("Paste a session shared directly with you. ForzAdvisor checks that it belongs to this exact saved setup before anything can be added to your local review queue.")
                    .font(.subheadline)
                Text("Nothing is saved while you paste or check the text.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .forzAdvisorRowBackground()

            Section("Shared session text") {
                TextEditor(text: $state.pastedJSON)
                    .font(.caption.monospaced())
                    .frame(minHeight: 170)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: state.pastedJSON) { state.pastedTextChanged() }
                    .accessibilityLabel("Shared validation session text")
                    .accessibilityHint("Paste the complete text shared from ForzAdvisor.")
                    .accessibilityIdentifier("fh6ValidationReviewJSON")

                Button("Check Shared Session") { validatePaste() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!state.hasUnimportedText)
                    .accessibilityIdentifier("validateFH6ValidationReviewButton")
            }
            .forzAdvisorRowBackground()

            if state.validatedJSON != nil {
                Section("Permission") {
                    Label("This session matches the saved setup", systemImage: "checkmark.seal")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ForzAdvisorTheme.success)

                    Toggle(
                        "I received this session directly from the driver and confirmed permission for deidentified structured reuse.",
                        isOn: $state.directReceiptAndPermissionConfirmed
                    )
                    .accessibilityIdentifier("confirmFH6ValidationReviewPermission")

                    Text("Permission is separate from the file check. Both are required before import.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Import Shared Session") { importValidatedPaste() }
                        .buttonStyle(.borderedProminent)
                        .disabled(
                            !state.directReceiptAndPermissionConfirmed
                                || storageError != nil
                        )
                        .accessibilityIdentifier("importFH6ValidationReviewButton")
                }
                .forzAdvisorRowBackground()
            }

            if let message = state.statusMessage {
                Section("Status") {
                    Label(
                        message,
                        systemImage: state.statusIsError
                            ? "exclamationmark.triangle" : "checkmark.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        state.statusIsError ? ForzAdvisorTheme.warning : .secondary
                    )
                    .accessibilityIdentifier("fh6ValidationImportStatus")
                }
                .forzAdvisorRowBackground()
            }

            Section {
                DisclosureGroup("Technical details") {
                    Text("The check is fail-closed. It verifies canonical structure, integrity fingerprints, exact FH6 tune and build identity, ruleset revision, authorship and reuse declarations, applied settings, and replay or stale-data constraints.")
                    if let technicalMessage = state.technicalMessage {
                        Text(technicalMessage)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .forzAdvisorRowBackground()
        }
        .navigationTitle("Import Shared Session")
        .navigationBarTitleDisplayMode(.inline)
        .forzAdvisorScreenChrome()
    }

    private func validatePaste() {
        let data = Data(state.pastedJSON.utf8)
        do {
            let validated = try FH6ValidationReviewIngestor().validate(data)
            guard FH6ValidationReviewIngestor().matchesSavedTune(
                validated,
                tune: tune
            ) else {
                throw FH6ValidationReviewError.tuneMismatch
            }
            state.validatedJSON = data
            state.statusMessage = "This shared session matches the exact saved FH6 setup. Confirm permission to import it."
            state.technicalMessage = "Canonical structure, integrity, build, ruleset, authorship, applied-settings, and tune-revision checks passed."
            state.statusIsError = false
        } catch {
            state.validatedJSON = nil
            state.directReceiptAndPermissionConfirmed = false
            state.statusMessage = "This session could not be accepted. Nothing was imported."
            state.technicalMessage = error.localizedDescription
            state.statusIsError = true
        }
    }

    private func importValidatedPaste() {
        guard let data = state.validatedJSON else { return }
        do {
            let entry = try FH6ValidationReviewEntry.locallyReviewed(
                canonicalExportJSON: data,
                reviewerConfirmedDirectReceiptAndReusePermission:
                    state.directReceiptAndPermissionConfirmed
            )
            if let errorMessage = onImport(entry) {
                state.statusMessage = "This session could not be saved locally."
                state.technicalMessage = errorMessage
                state.statusIsError = true
                return
            }
            state.clear()
            packetState.clearPreparedFile()
            state.statusMessage = "Session imported to the local review queue."
        } catch {
            state.statusMessage = "This session could not be imported."
            state.technicalMessage = error.localizedDescription
            state.statusIsError = true
        }
    }
}
