import SwiftUI

struct ProviderPreflightView: View {
    let game: ForzaGame
    let disclosure: TuneProviderDisclosure

    var body: some View {
        LabeledContent("Preferred method") {
            Text(disclosure.preferredMode.title)
        }
        LabeledContent("Readiness") {
            Text(disclosure.readiness.readinessTitle)
        }
        VStack(alignment: .leading, spacing: 5) {
            Text("Expected route")
                .font(.subheadline.weight(.semibold))
            Text(DisciplineGenerationCopy.routeSummary(disclosure))
                .font(.subheadline)
                .foregroundStyle(ForzAdvisorTheme.secondaryText)
        }
        .accessibilityElement(children: .combine)

        VStack(alignment: .leading, spacing: 5) {
            Text("Data boundary")
                .font(.subheadline.weight(.semibold))
            Text(DisciplineGenerationCopy.dataBoundary(
                for: game,
                disclosure: disclosure
            ))
                .font(.subheadline)
                .foregroundStyle(ForzAdvisorTheme.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }
}
