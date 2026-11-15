import SwiftUI

enum ForzAdvisorTuneStep: Int, CaseIterable {
    case source = 1
    case details
    case discipline
    case result

    var title: String {
        switch self {
        case .source: "Add your car"
        case .details: "Check car details"
        case .discipline: "Choose your driving style"
        case .result: "Your setup"
        }
    }
}

/// Describes the workflow position, never provider progress or an estimated duration.
struct ForzAdvisorWorkflowProgress: View {
    let step: ForzAdvisorTuneStep

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Step \(step.rawValue) of \(ForzAdvisorTuneStep.allCases.count) · \(step.title)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ForzAdvisorTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 5) {
                ForEach(ForzAdvisorTuneStep.allCases, id: \.rawValue) { item in
                    Capsule()
                        .fill(item.rawValue <= step.rawValue
                            ? ForzAdvisorTheme.accent
                            : ForzAdvisorTheme.separator.opacity(0.35))
                        .frame(height: item == step ? 4 : 2)
                }
            }
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("tuneWorkflowProgress-\(step.rawValue)")
    }
}
