import SwiftUI

struct ProviderPreferenceCard: View {
    let mode: TuneProviderMode
    let disclosure: TuneProviderDisclosure
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Label(mode.title, systemImage: mode.resultSymbolName)
                        .font(.headline)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .accessibilityHidden(true)
                }
                Text(mode.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                detailRow("Readiness", disclosure.readiness.readinessTitle)
                detailRow("Expected route", expectedRoute)
                detailRow("Privacy", privacySummary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(12)
            .background(
                isSelected ? ForzAdvisorTheme.accent.opacity(0.10) : ForzAdvisorTheme.surface,
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? ForzAdvisorTheme.accent : ForzAdvisorTheme.separator,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint("Sets this as the preferred FH6 generation method")
        .accessibilityIdentifier("providerPreference-\(mode.rawValue)")
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var expectedRoute: String {
        let first = disclosure.route.expectedFirstMode.resultTitle
        guard disclosure.route.fallbackMode != nil else { return first }
        return disclosure.route.preferredModeWillBeAttempted
            ? "\(first), then offline formulas if needed"
            : "Offline formulas; preference is not currently ready"
    }

    private var privacySummary: String {
        disclosure.dataBoundary == .localOnly
            ? "Stays on this device"
            : "Confirmed facts may be sent remotely before local fallback"
    }
}
