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

    func testFailureRecoveryKeepsExactSessionAndSelectedDiscipline() {
        let input = SampleTuningData.starterCar
        let draft = TuneDraftSession(stage: .discipline(
            car: input,
            origin: .manual(input),
            thumbnailData: Data("photo".utf8),
            selection: .dirt
        ))
        let session = makeSession(
            request: .init(car: input, discipline: .dirt),
            returnContext: .newTune(draft)
        )
        let recovery = TuneGenerationFailureRecovery(session: session)

        XCTAssertEqual(recovery.session, session)
        XCTAssertEqual(
            recovery.changeDisciplineContext,
            TuneGenerationReturnContext.newTune(draft)
        )
        XCTAssertEqual(
            recovery.backTarget,
            TuneGenerationFailureRecovery.BackTarget.source(
                .manual(input),
                thumbnailData: Data("photo".utf8)
            )
        )
    }

    func testSavedFailureBackRestoresExactEditDraft() {
        let baseline = TuneResult(
            request: .init(
                car: SampleTuningData.starterCar,
                discipline: .road
            ),
            sections: [],
            notes: .init(
                bias: "", ifPushesWide: "", ifSnapsOnLift: "",
                retuneTrigger: ""
            )
        )
        var draft = SavedTuneEditDraft(tune: baseline, playerNotes: "kept")
        draft.car.weightPounds += 10
        let retune = SavedTuneRetuneSession(
            savedTuneID: baseline.id,
            baseline: baseline,
            draft: draft,
            thumbnailData: nil
        )
        let session = makeSession(
            request: .init(car: draft.car, discipline: .road),
            returnContext: .savedEdit(retune)
        )

        XCTAssertEqual(
            TuneGenerationFailureRecovery(session: session).backTarget,
            .savedEdit(retune)
        )
    }

    func testGenerationSessionPreservesMissionOrigin() {
        let input = SampleTuningData.starterCar
        let mission = BetaValidationMission(
            kind: .startFH6Tune,
            game: .fh6,
            savedTuneID: nil,
            carDisplayName: nil,
            disciplineTitle: nil
        )
        let context = ValidationMissionReturnContext(mission: mission)
        let base = makeSession(
            request: .init(car: input, discipline: .road),
            returnContext: .newTune(.init(stage: .discipline(
                car: input,
                origin: .manual(input),
                thumbnailData: nil,
                selection: .road
            )))
        )
        let session = TuneGenerationSession(
            request: base.request,
            origin: base.origin,
            thumbnailData: base.thumbnailData,
            preferredProviderMode: base.preferredProviderMode,
            providerDisclosure: base.providerDisclosure,
            returnContext: base.returnContext,
            validationMissionReturnContext: context
        )

        XCTAssertEqual(session.validationMissionReturnContext, context)
    }

    private func makeSession(
        request: TuneRequest,
        returnContext: TuneGenerationReturnContext
    ) -> TuneGenerationSession {
        .init(
            request: request,
            origin: .manual(request.car),
            thumbnailData: nil,
            preferredProviderMode: .offlineFormula,
            providerDisclosure: .init(
                preferredMode: .offlineFormula,
                capabilities: .init(
                    onDeviceModel: .unavailable(.modelNotReady),
                    anthropicAPI: .setupRequired(.apiKey)
                )
            ),
            returnContext: returnContext
        )
    }
}
