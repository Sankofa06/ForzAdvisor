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
        onSelect: @escaping (OfficialRosterCarIdentity) -> Bool
    ) {
        snapshot = StockCatalogOfficialRosterPickerSnapshot(
            fh5Result: fh5Result,
            fh6Result: fh6Result
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
            } footer: {
                Text(
                    "Only official game, year, make, and model identity is copied. Verify every stock specification directly in-game."
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
                    ContentUnavailableView.search(text: query)
                        .accessibilityIdentifier(
                            "stockCatalogOfficialRosterNoResults"
                        )
                }
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
                            }
                        }
                        .accessibilityLabel(
                            "\(entry.displayName), official identity only. Verify stock specifications directly in-game."
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
        snapshot.entries(for: selectedGame, matching: query)
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
