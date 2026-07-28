//
//  CarCatalogPickerView.swift
//  forzadvisor
//
//  Game-scoped browsing for the bundled, source-attributed starter catalog.
//

import SwiftUI

struct CarCatalogPickerView: View {
    let catalogResult: Result<CarCatalogSnapshot, CatalogLoadError>
    let fh5RosterResult: Result<
        FH5OfficialRosterSnapshot,
        FH5OfficialRosterLoadError
    >
    let fh6RosterResult: Result<
        FH6OfficialRosterSnapshot,
        FH6OfficialRosterLoadError
    >
    let onBack: () -> Void
    let onManualEntry: (ForzaGame) -> Void
    let onSelect: (CatalogCarSelection) -> Void
    let onIdentityOnly: (OfficialRosterCarIdentity) -> Void

    @State private var selectedGame: ForzaGame
    @State private var searchText = ""

    init(
        catalogResult: Result<CarCatalogSnapshot, CatalogLoadError>,
        fh5RosterResult: Result<
            FH5OfficialRosterSnapshot,
            FH5OfficialRosterLoadError
        > = BundledFH5OfficialRoster.load(),
        fh6RosterResult: Result<
            FH6OfficialRosterSnapshot,
            FH6OfficialRosterLoadError
        > = BundledFH6OfficialRoster.load(),
        initialGame: ForzaGame = .fh6,
        onBack: @escaping () -> Void,
        onManualEntry: @escaping (ForzaGame) -> Void,
        onSelect: @escaping (CatalogCarSelection) -> Void,
        onIdentityOnly: @escaping (
            OfficialRosterCarIdentity
        ) -> Void = { _ in }
    ) {
        self.catalogResult = catalogResult
        self.fh5RosterResult = fh5RosterResult
        self.fh6RosterResult = fh6RosterResult
        self.onBack = onBack
        self.onManualEntry = onManualEntry
        self.onSelect = onSelect
        self.onIdentityOnly = onIdentityOnly
        self._selectedGame = State(initialValue: initialGame)
    }

    var body: some View {
        List {
            Section {
                ForzAdvisorScreenHeader(
                    title: "Choose a Car",
                    subtitle:
                        "Choose from the official FH5 and FH6 rosters. Only reviewed stock cars include complete values.",
                    systemImage: "car.2",
                    tint: ForzAdvisorTheme.warmAccent
                )
            }
            .listRowBackground(ForzAdvisorTheme.heroRowBackground)

            switch catalogResult {
            case .success(let snapshot):
                let browseSnapshot = CarCatalogBrowseOverlay.resolve(
                    catalog: snapshot,
                    fh5RosterResult: fh5RosterResult,
                    fh6RosterResult: fh6RosterResult
                )
                catalogControls
                if let issue = browseSnapshot
                    .rosterIssueDescription(for: selectedGame) {
                    rosterIssueSection(
                        issue,
                        game: selectedGame
                    )
                }
                catalogResults(snapshot: browseSnapshot)
                manualEntrySection
            case .failure(let error):
                Section {
                    ContentUnavailableView(
                        "Catalog unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error.localizedDescription)
                    )
                    Button("Enter Manually") {
                        onManualEntry(selectedGame)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("catalogManualEntryButton")
                }
                .forzAdvisorRowBackground()
            }
        }
        .navigationTitle("Car Catalog")
        .accessibilityIdentifier("catalogPicker")
        .forzAdvisorScreenChrome()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back", action: onBack)
            }
        }
    }

    @ViewBuilder
    private var catalogControls: some View {
        Section("Game") {
            Picker("Game", selection: $selectedGame) {
                ForEach(ForzaGame.allCases) { game in
                    Text(game.shortTitle).tag(game)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("catalogGamePicker")

            TextField("Search make or model", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("catalogSearchField")
        }
        .forzAdvisorRowBackground()
    }

    @ViewBuilder
    private func catalogResults(
        snapshot: CarCatalogBrowseSnapshot
    ) -> some View {
        let entries = CarCatalogBrowseOverlay.search(
            snapshot,
            game: selectedGame,
            query: searchText
        )

        Section("Cars") {
            if entries.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ForEach(entries) { entry in
                    Button {
                        if let selection =
                            entry.reviewedSelection {
                            onSelect(selection)
                        } else {
                            onIdentityOnly(entry.identity)
                        }
                    } label: {
                        CatalogCarRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("catalogCarRow-\(entry.id)")
                }
            }
        }
        .forzAdvisorRowBackground()
    }

    private func rosterIssueSection(
        _ issue: String,
        game: ForzaGame
    ) -> some View {
        Section {
            Label(
                "The full \(game.shortTitle) roster is unavailable. Showing reviewed cars only.",
                systemImage: "exclamationmark.triangle"
            )
            .font(.subheadline.weight(.semibold))
            Text(issue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .forzAdvisorRowBackground()
    }

    private var manualEntrySection: some View {
        Section("Car not listed?") {
            Text("Enter and confirm the car's stock values manually. Manual values are not verified by the reviewed catalog.")
                .foregroundStyle(.secondary)
            Button("Enter Manually") {
                onManualEntry(selectedGame)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("catalogManualEntryButton")
            NavigationLink {
                StockCatalogContributionView(
                    initialGame: selectedGame
                )
            } label: {
                Label(
                    "Help Expand the Catalog",
                    systemImage: "car.badge.plus"
                )
            }
            .accessibilityIdentifier(
                "openStockCatalogContributionFromCatalog"
            )
            Text(
                "This opens a separate first-party research workspace. It does not submit Manual Entry values or create a tune."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .forzAdvisorRowBackground()
    }
}

private struct CatalogCarRow: View {
    let entry: CatalogBrowseEntry

    var body: some View {
        HStack(spacing: 12) {
            ForzAdvisorIcon(systemName: "car.side", tint: ForzAdvisorTheme.warmAccent)

            VStack(alignment: .leading, spacing: 5) {
                Text(entry.displayName)
                    .font(.headline)
                if let selection = entry.reviewedSelection {
                    let stock = selection.entry.stock
                    Text(
                        "\(entry.game.shortTitle) · \(stock.performanceClass.rawValue) \(stock.performanceIndex) · \(stock.drivetrain.rawValue) · \(stock.weightPounds) lb"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Text(selection.entry.verificationStatus.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(ForzAdvisorTheme.accent)
                } else {
                    if let performanceClass =
                        entry.officialPerformanceClass,
                       let performanceIndex =
                        entry.officialPerformanceIndex {
                        Text(
                            "\(entry.game.shortTitle) · Official \(performanceClass.rawValue) \(performanceIndex)"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    } else {
                        Text(
                            "\(entry.game.shortTitle) · Official roster identity"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Text("Stock specs needed")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(ForzAdvisorTheme.warning)
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}
