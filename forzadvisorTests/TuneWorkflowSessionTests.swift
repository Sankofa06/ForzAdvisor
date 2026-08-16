import XCTest
@testable import forzadvisor

final class TuneWorkflowSessionTests: XCTestCase {
    func testGenerationSessionFreezesRequestProviderAndReturnContext() {
        let input = SampleTuningData.starterCar
        let request = TuneRequest(car: input, discipline: .road)
        let draft = TuneDraftSession(stage: .discipline(
            car: input,
            origin: .manual(input),
            thumbnailData: Data("image".utf8),
            selection: .road
        ))
        let capabilities = TuneProviderCapabilities(
            onDeviceModel: .ready,
            anthropicAPI: .storedOnDeviceNotTested
        )
        let session = TuneGenerationSession(
            request: request,
            origin: .manual(input),
            thumbnailData: Data("image".utf8),
            preferredProviderMode: .anthropicAPI,
            providerDisclosure: TuneProviderDisclosure(
                preferredMode: .anthropicAPI,
                capabilities: capabilities
            ),
            returnContext: .newTune(draft)
        )

        XCTAssertEqual(session.request, request)
        XCTAssertEqual(session.preferredProviderMode, .anthropicAPI)
        XCTAssertEqual(session.providerDisclosure.dataBoundary, .remoteGeneration)
        XCTAssertEqual(session.returnContext, .newTune(draft))
    }

    func testOnlySourceStageIsNotMeaningful() {
        XCTAssertFalse(TuneDraftSession().isMeaningful)
        XCTAssertTrue(TuneDraftSession(
            stage: .manual(.empty, thumbnailData: nil)
        ).isMeaningful)
    }

    func testSavedRetuneReturnContextKeepsFullDraftAndBaseline() {
        let baseline = TuneResult(
            request: TuneRequest(
                car: SampleTuningData.starterCar,
                discipline: .road
            ),
            sections: [],
            notes: TuneNotes(
                bias: "Baseline",
                ifPushesWide: "",
                ifSnapsOnLift: "",
                retuneTrigger: ""
            )
        )
        var draft = SavedTuneEditDraft(
            tune: baseline,
            playerNotes: "Unsaved note"
        )
        draft.car.weightPounds += 250
        let retune = SavedTuneRetuneSession(
            savedTuneID: baseline.id,
            baseline: baseline,
            draft: draft,
            thumbnailData: Data("thumbnail".utf8)
        )

        XCTAssertEqual(
            TuneGenerationReturnContext.savedEdit(retune),
            .savedEdit(retune)
        )
        XCTAssertNotEqual(retune.baseline.request.car, retune.draft.car)
        XCTAssertEqual(retune.draft.playerNotes, "Unsaved note")
    }
}
