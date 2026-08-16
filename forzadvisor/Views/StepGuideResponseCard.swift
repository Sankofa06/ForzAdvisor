import SwiftUI

struct StepGuideResponseCard: View {
    let response: StepGuideResponse
    let hiddenAction: StepGuideAction?
    let rejection: StepGuideActionRejection?
    let onAction: (StepGuideAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(response.title)
                .font(.headline)
            Text(response.message)
                .fixedSize(horizontal: false, vertical: true)
            if let action = response.action, action != hiddenAction {
                Button {
                    onAction(action)
                } label: {
                    Text(action.title)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("copilotResponseActionButton")
            }
            if let rejection {
                Label(
                    rejection.message,
                    systemImage: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90"
                )
                .font(.subheadline)
                .foregroundStyle(ForzAdvisorTheme.warning)
                .accessibilityIdentifier("stepGuideActionRejection")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            ForzAdvisorTheme.mutedSurface,
            in: RoundedRectangle(cornerRadius: 14)
        )
        .accessibilityIdentifier("copilotResponse")
    }
}
