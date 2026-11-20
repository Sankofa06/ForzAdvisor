import SwiftUI

struct PrimaryStartCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.title3.weight(.bold))
            Text(subtitle)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

struct CaptureGuideSection: View {
    private let fields = [
        ("Weight", "lb or kg"),
        ("Front weight", "%"),
        ("PI / Class", "A 750, S1 900"),
        ("Drivetrain", "FWD, RWD, AWD"),
        ("Power / Torque", "optional")
    ]

    var body: some View {
        Section("Capture Guide") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(fields, id: \.0) { field, hint in
                    HStack(spacing: 10) {
                        ForzAdvisorIcon(
                            systemName: "checkmark",
                            tint: ForzAdvisorTheme.success,
                            size: 28
                        )
                        Text(field)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(hint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .forzAdvisorRowBackground()
    }
}

struct StartRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            ForzAdvisorIcon(systemName: systemImage)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
