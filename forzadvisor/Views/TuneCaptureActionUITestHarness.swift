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

struct LegacyTuneSettingsUITestHarness: View {
    private var tune: TuneResult {
        var car = SampleTuningData.starterCar
        car.game = .fh6
        return TuneResult(
            request: TuneRequest(car: car, discipline: .road),
            sections: [TuneSection(
                title: "Legacy sentinel",
                symbolName: "slider.horizontal.3",
                lines: [TuneLine(label: "Front pressure", value: "37.125", unit: "PSI", fieldID: .frontTirePressure)]
            )],
            notes: TuneNotes(bias: "Legacy", ifPushesWide: "Legacy", ifSnapsOnLift: "Legacy", retuneTrigger: "Legacy"),
            projectionReport: nil
        )
    }

    var body: some View {
        NavigationStack {
            List {
                TuneAvailableSettingsSection(
                    tune: tune,
                    presentation: TuneResultPresentation(tune: tune, isSaved: true, isStreaming: false),
                    expandedSectionTitles: .constant(["Legacy sentinel"]),
                    copiedLineID: .constant(nil)
                )
                Text("Stored fixture lines: \(tune.sections.flatMap(\.lines).count)")
            }
            .navigationTitle("Legacy Result Test")
        }
    }
}
#endif
