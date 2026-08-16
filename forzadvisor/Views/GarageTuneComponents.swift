import SwiftUI

struct GarageDisciplinePicker: View {
    @Binding var selection: DrivingDiscipline?

    var body: some View {
        Picker("Filter by discipline", selection: $selection) {
            Text("All disciplines").tag(nil as DrivingDiscipline?)
            ForEach(DrivingDiscipline.allCases) { discipline in
                Label(discipline.title, systemImage: discipline.symbolName)
                    .tag(discipline as DrivingDiscipline?)
            }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("garageDisciplineFilter")
        .accessibilityValue(selection?.title ?? "All disciplines")
    }
}

struct GarageNoResultsView: View {
    let searchText: String
    let discipline: DrivingDiscipline?
    let onClearSearch: () -> Void
    let onShowAllDisciplines: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ContentUnavailableView(
                "No matching tunes",
                systemImage: "magnifyingglass",
                description: Text(description)
            )
            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button("Clear Search", action: onClearSearch)
                    .buttonStyle(.bordered)
                    .forzAdvisorMinimumTouchTarget()
            }
            if discipline != nil {
                Button("Show All Disciplines", action: onShowAllDisciplines)
                    .buttonStyle(.bordered)
                    .forzAdvisorMinimumTouchTarget()
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("garageNoResults")
    }

    private var description: String {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty, let discipline {
            return "No \(discipline.title) tunes match “\(query)”. Clear either filter to recover."
        }
        if let discipline { return "No saved tunes use the \(discipline.title) discipline." }
        return "No saved tunes match “\(query)”."
    }
}

struct GarageTuneRow: View {
    let tune: SavedTune

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForzAdvisorIcon(
                systemName: tune.disciplineSymbolName,
                tint: disciplineTint
            )
            VStack(alignment: .leading, spacing: 5) {
                Text(tune.carName).font(.headline)
                Text(metadata)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Updated \(tune.updatedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !tune.playerNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(tune.playerNotes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var metadata: String {
        var parts = [tune.disciplineTitle]
        if let game = tune.carInput?.game.shortTitle { parts.append(game) }
        parts.append("\(tune.performanceClassRawValue) \(tune.performanceIndex)")
        parts.append(tune.drivetrainRawValue)
        return parts.joined(separator: " · ")
    }

    private var disciplineTint: Color {
        guard let discipline = tune.discipline else { return ForzAdvisorTheme.accent }
        return ForzAdvisorTheme.disciplineColor(discipline)
    }
}
