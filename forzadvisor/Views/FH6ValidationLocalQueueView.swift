//
//  FH6ValidationLocalQueueView.swift
//  forzadvisor
//

import SwiftUI

struct FH6ValidationLocalQueueView: View {
    let entries: [FH6ValidationReviewEntry]
    @Binding var packetState: FH6IndependentReviewPresentationState
    let onDelete: (FH6ValidationReviewEntry) -> Void

    @State private var pendingDeletion: FH6ValidationReviewEntry?

    var body: some View {
        List {
            Section {
                Text("These are reviewed copies stored only with this saved tune on this device.")
                    .font(.subheadline)
                Text("Removing a copy does not delete the sender's file or change the tune.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .forzAdvisorRowBackground()

            Section("Local reviewed copies") {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "Queue Empty",
                        systemImage: "tray",
                        description: Text("Imported reviewed copies will appear here.")
                    )
                } else {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            Label {
                                Text(entry.importedAt, format: .dateTime)
                            } icon: {
                                Image(systemName: "doc.text")
                            }
                            .font(.subheadline.weight(.semibold))

                            DisclosureGroup("Technical details") {
                                Text("Content fingerprint prefix: \(entry.permission.contentFingerprint.prefix(12))")
                                    .font(.caption.monospaced())
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            Button("Remove Local Reviewed Copy", role: .destructive) {
                                pendingDeletion = entry
                            }
                            .frame(minHeight: ForzAdvisorTheme.minimumTouchTarget)
                            .accessibilityIdentifier("deleteFH6ValidationReviewEntryButton")
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
            .forzAdvisorRowBackground()
        }
        .navigationTitle("Local Review Queue")
        .navigationBarTitleDisplayMode(.inline)
        .forzAdvisorScreenChrome()
        .alert(
            "Remove local reviewed copy?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            presenting: pendingDeletion
        ) { entry in
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
            Button("Remove Local Copy", role: .destructive) {
                packetState.clearPreparedFile()
                onDelete(entry)
                pendingDeletion = nil
            }
        } message: { _ in
            Text("Only the local reviewed copy is removed. The saved tune, sender's shared file, and any source session are not changed.")
        }
    }
}
