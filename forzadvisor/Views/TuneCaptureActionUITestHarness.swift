#if DEBUG
import SwiftUI

struct TuneCaptureActionUITestHarness: View {
    @State private var dispatchOutcome = "No capture action dispatched"
    private let summary = TuneEvidenceSummary.empty(savedTuneID: UUID())

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack {
                List {
                    TuneEvidenceHubSection(
                        summary: summary,
                        isSaved: true,
                        isStreaming: false,
                        captureActions: TuneResultCaptureActions(
                            onVerifyTirePressures: {
                                dispatchOutcome =
                                    "Result: Verify Tire Pressures"
                            }
                        ),
                        destination: hubDestination,
                        availabilityNote: nil
                    )
                }
                .navigationTitle("Capture Action Test")
            }

            Text(dispatchOutcome)
                .font(.caption)
                .accessibilityIdentifier("captureActionDispatchOutcome")
                .frame(maxWidth: .infinity)
                .padding()
        }
    }

    private var hubDestination: AnyView {
        AnyView(TuneEvidenceHubView(adapter: .init(
            summary: summary,
            evidenceRecords: [],
            captureActions: TuneResultCaptureActions(
                onVerifyTirePressures: {
                    dispatchOutcome = "Hub: Verify Tire Pressures"
                }
            ),
            onRecordTestDrive: nil,
            onOpenFH5Research: nil,
            onOpenFH5Experiment: nil,
            onRunFH6CommunityTrial: nil,
            fh5ResearchReview: nil,
            fh5CandidateReview: nil,
            fh6ValidationReview: nil,
            fh6CommunityReview: nil,
            authorization: { _ in .localOnly },
            onGrant: { _ in .localOnly },
            onRevoke: { _ in .localOnly },
            onDelete: { _ in .deleted }
        )))
    }
}
#endif
