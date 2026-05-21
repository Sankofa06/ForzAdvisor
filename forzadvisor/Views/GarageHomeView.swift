//
//  GarageHomeView.swift
//  forzadvisor
//
//  First screen for the app. Shows the local in-memory garage placeholder and
//  starts the manual tune flow.
//

import SwiftUI

struct GarageHomeView: View {
    let savedTunes: [SavedTune]
    let onNewTune: () -> Void
    let onOpenTune: (SavedTune) -> Void
    let onDeleteTune: (SavedTune) -> Void
    let onSettings: () -> Void

    @State private var searchText = ""
    @State private var disciplineFilter: DrivingDiscipline?

    private var filteredTunes: [SavedTune] {
        savedTunes.filter { tune in
            let matchesText = searchText.isEmpty
                || tune.carName.localizedCaseInsensitiveContains(searchText)
            let matchesDiscipline = disciplineFilter == nil
                || tune.discipline == disciplineFilter
            return matchesText && matchesDiscipline
        }
    }

    var body: some View {
        List {
            Section {
                Button(action: onNewTune) {
                    HStack(spacing: 14) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.tint)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("New Tune")
                                .font(.headline)
                            Text("Photo, screenshot, or manual entry")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 10)
                }
                .accessibilityIdentifier("newTuneButton")
                .buttonStyle(.plain)
            }

            Section("Garage") {
                if savedTunes.isEmpty {
                    ContentUnavailableView(
                        "No saved tunes",
                        systemImage: "wrench.adjustable",
                        description: Text("Create a manual tune to start filling the garage.")
                    )
                    .listRowBackground(Color.clear)
                } else if filteredTunes.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredTunes) { tune in
                        Button {
                            onOpenTune(tune)
                        } label: {
                            GarageTuneRow(tune: tune)
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                onDeleteTune(tune)
                            }
                        }
                    }
                }
            }

            if let recentTune = savedTunes.first {
                Section("Recent") {
                    Button {
                        onOpenTune(recentTune)
                    } label: {
                        GarageTuneRow(tune: recentTune)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("ForzAdvisor")
        .searchable(text: $searchText, prompt: "Search garage")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !savedTunes.isEmpty {
                DisciplineFilterBar(selection: $disciplineFilter)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(.bar)
            }
        }
    }
}

private struct GarageTuneRow: View {
    let tune: SavedTune

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tune.disciplineSymbolName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(tune.carName)
                    .font(.headline)
                Text("\(tune.disciplineTitle) - \(tune.performanceClassRawValue) \(tune.performanceIndex) - \(tune.drivetrainRawValue)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

private struct DisciplineFilterBar: View {
    @Binding var selection: DrivingDiscipline?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterButton(title: "All", value: nil)
                ForEach(DrivingDiscipline.allCases) { discipline in
                    filterButton(title: discipline.title, value: discipline)
                }
            }
        }
    }

    private func filterButton(title: String, value: DrivingDiscipline?) -> some View {
        Button {
            selection = value
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(selection == value ? Color.accentColor : Color.gray.opacity(0.14))
                .foregroundColor(selection == value ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
