import SwiftUI
import UIKit

struct GarageHomeView: View {
    let savedTunes: [SavedTune]
    let onNewTune: () -> Void
    let onOpenCopilot: () -> Void
    let onOpenTune: (SavedTune) -> Void
    let onDeleteTune: (UUID, GarageRemovalCommitCallback?) -> Void
    let betaMissionCount: Int
    let onBetaMissions: () -> Void
    let onEmptyGarageFirstWin: (() -> Void)?
    let onSettings: () -> Void

    @State private var searchText = ""
    @State private var disciplineFilter: DrivingDiscipline?
    @State private var removalState = GarageRemovalState()

    private var uniqueTunes: [SavedTune] {
        var seen = Set<UUID>()
        return savedTunes.filter { seen.insert($0.id).inserted }
    }

    private var visibleTunes: [SavedTune] {
        uniqueTunes.filter { !removalState.hiddenTuneIDs.contains($0.id) }
    }

    private var filteredTunes: [SavedTune] {
        visibleTunes.filter { tune in
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesText = query.isEmpty
                || tune.carName.localizedCaseInsensitiveContains(query)
            let matchesDiscipline = disciplineFilter == nil
                || tune.discipline == disciplineFilter
            return matchesText && matchesDiscipline
        }
    }

    var body: some View {
        searchableContent
            .navigationTitle("ForzAdvisor")
            .accessibilityIdentifier("garageHome")
            .forzAdvisorScreenChrome()
            .toolbar { garageToolbar }
            .safeAreaInset(edge: .bottom) { undoBanner }
            .task(id: removalState.pending?.id) {
                guard let pendingID = removalState.pending?.id else { return }
                do {
                    try await Task.sleep(for: .seconds(6))
                    commitPendingRemoval(id: pendingID)
                } catch {
                    // A replacement removal or Undo cancels this timer.
                }
            }
            .onDisappear { commitPendingRemoval() }
    }

    @ViewBuilder
    private var searchableContent: some View {
        if uniqueTunes.isEmpty {
            garageList
        } else {
            garageList.searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search saved tunes"
            )
        }
    }

    private var garageList: some View {
        List {
            if uniqueTunes.isEmpty {
                GarageFirstTuneView(action: onEmptyGarageFirstWin ?? onNewTune)
            } else {
                GarageNewTuneRow(action: onNewTune)
                savedTuneSection
            }

            GarageOptionalTestingRow(
                missionCount: betaMissionCount,
                action: onBetaMissions
            )
        }
    }

    private var savedTuneSection: some View {
        Section("Garage") {
            GarageDisciplinePicker(selection: $disciplineFilter)

            if filteredTunes.isEmpty {
                GarageNoResultsView(
                    searchText: searchText,
                    discipline: disciplineFilter,
                    onClearSearch: { searchText = "" },
                    onShowAllDisciplines: { disciplineFilter = nil }
                )
            } else {
                ForEach(filteredTunes) { tune in
                    Button { onOpenTune(tune) } label: {
                        GarageTuneRow(tune: tune)
                    }
                    .accessibilityIdentifier("savedTuneRow")
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("Remove", role: .destructive) {
                            stageRemoval(of: tune)
                        }
                    }
                    .forzAdvisorRowBackground()
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var garageToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: onOpenCopilot) {
                Label("Step Guide", systemImage: "questionmark.circle")
            }
            .accessibilityLabel("Open Step Guide")
            .accessibilityHint("Opens local guidance for this screen")
            .accessibilityIdentifier("garageStepGuideButton")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onSettings) { Image(systemName: "gearshape") }
                .accessibilityLabel("Settings")
        }
    }

    @ViewBuilder
    private var undoBanner: some View {
        if let pending = removalState.pending {
            ForzAdvisorUndoBanner(
                message: "Removed \(pending.carName). Undo available for 6 seconds.",
                undo: undoRemoval
            )
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            .accessibilityIdentifier("garageRemovalUndo")
        }
    }

    private func stageRemoval(of tune: SavedTune) {
        if let priorID = removalState.stage(id: tune.id, carName: tune.carName) {
            commitRemoval(id: priorID)
        }
        announce("\(tune.carName) removed. Undo available for 6 seconds.")
    }

    private func undoRemoval() {
        guard let restored = removalState.undo() else { return }
        announce("Restored \(restored.carName).")
    }

    private func commitPendingRemoval(id: UUID? = nil) {
        guard let tuneID = removalState.beginPendingCommit(matching: id) else { return }
        commitRemoval(id: tuneID)
    }

    private func commitRemoval(id: UUID) {
        onDeleteTune(id) { result in
            guard removalState.resolve(result) else { return }
            if case .rolledBack(_, let message) = result { announce(message) }
        }
    }

    private func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}
