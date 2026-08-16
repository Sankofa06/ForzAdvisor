import SwiftUI

struct GarageFirstTuneView: View {
    let action: () -> Void

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                Label("Create your first tune", systemImage: "wrench.and.screwdriver.fill")
                    .font(.title3.bold())
                Text("Start from a car photo, a screenshot, or manual entry. You will confirm the car facts before choosing how you drive.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: action) {
                    Text("Start First Tune")
                        .frame(maxWidth: .infinity)
                        .forzAdvisorMinimumTouchTarget()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Shows photo, screenshot, and manual entry options")
                .accessibilityIdentifier("newTuneButton")
            }
            .padding(.vertical, 8)
            .accessibilityIdentifier("emptyGarageFirstWin")
            .listRowBackground(ForzAdvisorTheme.heroRowBackground)
        }
    }
}

struct GarageNewTuneRow: View {
    let action: () -> Void

    var body: some View {
        Section {
            Button(action: action) {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("New Tune").font(.headline)
                        Text("Photo, screenshot, or manual entry")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    ForzAdvisorIcon(systemName: "plus", tint: ForzAdvisorTheme.warmAccent, size: 42)
                }
                .padding(.vertical, 8)
            }
            .accessibilityIdentifier("newTuneButton")
            .buttonStyle(.plain)
            .listRowBackground(ForzAdvisorTheme.heroRowBackground)
        }
    }
}

struct GarageOptionalTestingRow: View {
    let missionCount: Int
    let action: () -> Void

    var body: some View {
        Section("Optional") {
            Button(action: action) {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Optional Testing & Research").font(.headline)
                        Text(missionSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    ForzAdvisorIcon(systemName: "checklist", tint: ForzAdvisorTheme.accent, size: 42)
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("betaValidationMissionsButton")
            .accessibilityHint("Shows optional local testing and research tasks")
        }
    }

    private var missionSummary: String {
        if missionCount == 0 { return "No optional tasks are ready" }
        if missionCount == 1 { return "1 optional local task is ready" }
        return "\(missionCount) optional local tasks are ready"
    }
}
