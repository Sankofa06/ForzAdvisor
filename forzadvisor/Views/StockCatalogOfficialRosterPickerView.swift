//
//  StockCatalogOfficialRosterPickerView.swift
//  forzadvisor
//
//  Official identity selection for a pristine stock contribution draft.
//

import SwiftUI

struct StockCatalogOfficialRosterPickerView: View {
    @Environment(\.dismiss) private var dismiss

    private let snapshot: StockCatalogOfficialRosterPickerSnapshot
    private let onSelect: (OfficialRosterCarIdentity) -> Bool

    @State private var selectedGame: ForzaGame
    @State private var query = ""
    @State private var coverageFilter:
        StockCatalogOfficialRosterCoverageFilter = .all
    @State private var rejectionMessage: String?

    init(
        initialGame: ForzaGame,
        fh5Result: Result<
            FH5OfficialRosterSnapshot,
            FH5OfficialRosterLoadError
        > = BundledFH5OfficialRoster.load(),
        fh6Result: Result<
            FH6OfficialRosterSnapshot,
            FH6OfficialRosterLoadError
        > = BundledFH6OfficialRoster.load(),
        capturedRecords: [StockCatalogContributionRecord],
        onSelect: @escaping (OfficialRosterCarIdentity) -> Bool
    ) {
        snapshot = StockCatalogOfficialRosterPickerSnapshot(
            fh5Result: fh5Result,
            fh6Result: fh6Result,
            capturedRecords: capturedRecords
        )
        self.onSelect = onSelect
        _selectedGame = State(initialValue: initialGame)
    }

    var body: some View {
        List {
            Section {
                Picker("Game", selection: $selectedGame) {
                    ForEach(ForzaGame.allCases) {
                        Text($0.shortTitle).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier(
                    "stockCatalogOfficialRosterGamePicker"
                )

                TextField("Search official car designation", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(!selectedRoster.isAvailable)
                    .accessibilityIdentifier(
                        "stockCatalogOfficialRosterSearch"
                    )

                Picker("Capture Coverage", selection: $coverageFilter) {
                    ForEach(
                        StockCatalogOfficialRosterCoverageFilter.allCases
                    ) {
                        Text($0.title).tag($0)
                    }
                }
                .accessibilityIdentifier(
                    "stockCatalogOfficialRosterNeedsCaptureFilter"
                )
            } footer: {
                Text(
                    "Local capture counts are collection-only. They do not establish verification, approval, permission completeness, or catalog readiness. Selection copies only official game, year, make, and model identity; check every stock specification directly in-game."
                )
            }

            if let issue = selectedRoster.localizedIssue {
                Section("Official \(selectedGame.shortTitle) Roster Unavailable") {
                    Text(issue)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(
                            "stockCatalogOfficialRosterIssue-\(selectedGame.rawValue)"
                        )
                }
            } else if visibleEntries.isEmpty {
                Section {
                    if coverageFilter == .needsLocalCapture {
                        ContentUnavailableView(
                            "No Cars Need Local Capture",
                            systemImage: "tray.full",
                            description: Text(
                                query.isEmpty
                                    ? "Every official car shown for this game has one or more counted local capture records."
                                    : "No official cars with zero local captures match this search."
                            )
                        )
                    } else {
                        ContentUnavailableView.search(text: query)
                    }
                }
                .accessibilityIdentifier(
                    coverageFilter == .needsLocalCapture
                        ? "stockCatalogOfficialRosterNoCaptureNeeds"
                        : "stockCatalogOfficialRosterNoResults"
                )
            } else {
                Section("\(visibleEntries.count) Official Cars") {
                    ForEach(visibleEntries) { entry in
                        Button {
                            select(entry.identity)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.displayName)
                                    .foregroundStyle(.primary)
                                Text(
                                    "Identity only — verify stock facts in-game"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                Text(entry.localCaptureStatus)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel(
                                        "\(entry.displayName): \(entry.localCaptureStatus), collection-only"
                                    )
                            }
                        }
                        .accessibilityLabel(
                            "\(entry.displayName), \(entry.localCaptureStatus), collection-only; does not establish verification, approval, permission completeness, or catalog readiness. Official identity only; check stock specifications directly in-game."
                        )
                        .accessibilityIdentifier(
                            "stockCatalogOfficialRosterRow-\(entry.id)"
                        )
                    }
                }
            }

            if let rejectionMessage {
                Section {
                    Text(rejectionMessage)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(
                            "stockCatalogOfficialRosterRejection"
                        )
                }
            }
        }
        .navigationTitle("Choose Official Identity")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .accessibilityIdentifier(
                    "stockCatalogOfficialRosterCancel"
                )
            }
        }
        .accessibilityIdentifier("stockCatalogOfficialRosterPicker")
        .onChange(of: selectedGame) {
            query = ""
            rejectionMessage = nil
        }
    }

    private var selectedRoster:
        StockCatalogOfficialRosterPickerSnapshot.GameRoster {
        snapshot.roster(for: selectedGame)
    }

    private var visibleEntries:
        [StockCatalogOfficialRosterPickerEntry] {
        snapshot.entries(
            for: selectedGame,
            matching: query,
            coverageFilter: coverageFilter
        )
    }

    private func select(_ identity: OfficialRosterCarIdentity) {
        if onSelect(identity) {
            dismiss()
        } else {
            rejectionMessage =
                "The contribution draft changed after this picker opened. Nothing was replaced. Cancel and start with a fresh identity-only draft to choose an official roster car."
        }
    }
}
