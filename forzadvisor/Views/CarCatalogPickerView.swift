//
//  CarCatalogPickerView.swift
//  forzadvisor
//
//  Game-scoped browsing for the bundled, source-attributed starter catalog.
//

import SwiftUI

struct CarCatalogPickerView: View {
    let catalogResult: Result<CarCatalogSnapshot, CatalogLoadError>
    let onBack: () -> Void
    let onManualEntry: () -> Void
    let onSelect: (CatalogCarSelection) -> Void

    @State private var selectedGame: ForzaGame
    @State private var searchText = ""

    init(
        catalogResult: Result<CarCatalogSnapshot, CatalogLoadError>,
        initialGame: ForzaGame = .fh6,
        onBack: @escaping () -> Void,
        onManualEntry: @escaping () -> Void,
        onSelect: @escaping (CatalogCarSelection) -> Void
    ) {
        self.catalogResult = catalogResult
        self.onBack = onBack
        self.onManualEntry = onManualEntry
        self.onSelect = onSelect
        self._selectedGame = State(initialValue: initialGame)
    }

    var body: some View {
        List {
            Section {
                ForzAdvisorScreenHeader(
                    title: "Choose a Car",
                    subtitle: "Start with reviewed stock values, then confirm them before tuning.",
                    systemImage: "car.2",
                    tint: ForzAdvisorTheme.warmAccent
                )
            }
            .listRowBackground(ForzAdvisorTheme.heroRowBackground)

            switch catalogResult {
            case .success(let snapshot):
                catalogControls(snapshot: snapshot)
                catalogResults(snapshot: snapshot)
            case .failure(let error):
                Section {
                    ContentUnavailableView(
                        "Catalog unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error.localizedDescription)
                    )
                    Button("Enter Manually", action: onManualEntry)
                        .buttonStyle(.borderedProminent)
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
    private func catalogControls(snapshot: CarCatalogSnapshot) -> some View {
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
    private func catalogResults(snapshot: CarCatalogSnapshot) -> some View {
        let entries = BundledCarCatalog.search(snapshot, game: selectedGame, query: searchText)

        Section("Cars") {
            if entries.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ForEach(entries) { entry in
                    Button {
                        onSelect(snapshot.selection(for: entry))
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
}

private struct CatalogCarRow: View {
    let entry: CatalogCarEntry

    var body: some View {
        HStack(spacing: 12) {
            ForzAdvisorIcon(systemName: "car.side", tint: ForzAdvisorTheme.warmAccent)

            VStack(alignment: .leading, spacing: 5) {
                Text(entry.displayName)
                    .font(.headline)
                Text("\(entry.game.shortTitle) · \(entry.stock.performanceClass.rawValue) \(entry.stock.performanceIndex) · \(entry.stock.drivetrain.rawValue) · \(entry.stock.weightPounds) lb")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.verificationStatus.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(ForzAdvisorTheme.accent)
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
