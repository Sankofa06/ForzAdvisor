import SwiftUI

struct GarageFirstTuneView: View {
    let action: () -> Void

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 18) {
                ForzAdvisorScreenHeader(
                    title: "Create your first tune",
                    subtitle: "Bring your car. Find your driving style.",
                    systemImage: "car.side",
                    tint: ForzAdvisorTheme.warmAccent
                )
                Button(action: action) {
                    Label("Start First Tune", systemImage: "arrow.right")
                }
                .buttonStyle(ForzAdvisorActionButtonStyle())
                .accessibilityLabel("Start First Tune")
                .accessibilityHint("Shows photo, screenshot, and manual entry options")
                .accessibilityIdentifier("newTuneButton")
                Text("Start with a photo, screenshot, or the values from your game. You stay in control of every detail.")
                    .font(.subheadline)
                    .foregroundStyle(ForzAdvisorTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 12) {
                    firstTuneStep("1", title: "Add your car")
                    firstTuneStep("2", title: "Check car details")
                    firstTuneStep("3", title: "Choose your driving style")
                    firstTuneStep("4", title: "Review and save your setup")
                }
            }
            .padding(.vertical, 8)
            .listRowBackground(ForzAdvisorTheme.heroRowBackground)
        }
    }

    private func firstTuneStep(_ number: String, title: String) -> some View {
        HStack(spacing: 10) {
            Text(number)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(ForzAdvisorTheme.accent)
                .frame(width: 26, height: 26)
                .background(ForzAdvisorTheme.accent.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
            Text(title)
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

struct GarageNewTuneRow: View {
    let action: () -> Void

    var body: some View {
        Section {
            Button(action: action) {
                HStack(spacing: 12) {
                    ForzAdvisorIcon(systemName: "plus", tint: ForzAdvisorTheme.warmAccent, size: 42)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("New Tune").font(.headline)
                        Text("Photo, screenshot, or manual entry")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(ForzAdvisorTheme.accent)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
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
