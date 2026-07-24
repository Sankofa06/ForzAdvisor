//
//  BetaValidationMission.swift
//  forzadvisor
//
//  Derives local beta-testing missions from existing saved-tune eligibility.
//  Missions never create evidence or tuning claims; they route players into
//  the app's existing verified capture workflows.
//

import Foundation

enum BetaValidationMissionKind: String, CaseIterable, Sendable {
    case startFH5Plan
    case startFH6Tune
    case recordFH5Research
    case runFH5Experiment
    case verifyTireRanges
    case verifyUpgradeParts
    case recordTestDrive

    var title: String {
        switch self {
        case .startFH5Plan: "Create an FH5 build plan"
        case .startFH6Tune: "Create an FH6 tune"
        case .recordFH5Research: "Record FH5 stock controls"
        case .runFH5Experiment: "Run an FH5 paired experiment"
        case .verifyTireRanges: "Verify FH6 tire ranges"
        case .verifyUpgradeParts: "Verify offered tuning parts"
        case .recordTestDrive: "Record an FH6 test drive"
        }
    }

    var systemImage: String {
        switch self {
        case .startFH5Plan, .startFH6Tune: "car.2"
        case .recordFH5Research: "list.clipboard"
        case .runFH5Experiment: "testtube.2"
        case .verifyTireRanges: "gauge.with.dots.needle.50percent"
        case .verifyUpgradeParts: "wrench.and.screwdriver"
        case .recordTestDrive: "flag.checkered"
        }
    }

    fileprivate var priority: Int {
        switch self {
        case .startFH5Plan: 0
        case .startFH6Tune: 1
        case .recordFH5Research: 10
        case .runFH5Experiment: 15
        case .verifyTireRanges: 20
        case .verifyUpgradeParts: 30
        case .recordTestDrive: 40
        }
    }
}

enum BetaValidationMissionDestination: Equatable, Sendable {
    case catalog(ForzaGame)
    case savedTune(UUID, BetaValidationMissionKind)
}

struct BetaValidationMission: Equatable, Identifiable, Sendable {
    let kind: BetaValidationMissionKind
    let game: ForzaGame
    let savedTuneID: UUID?
    let carDisplayName: String?
    let disciplineTitle: String?
    var isExperimentalCandidateTrial = false

    var title: String {
        isExperimentalCandidateTrial
            ? "Run an FH5 experimental candidate trial"
            : kind.title
    }

    var id: String {
        if let savedTuneID {
            return "\(kind.rawValue).\(savedTuneID.uuidString.lowercased())"
        }
        return kind.rawValue
    }

    var destination: BetaValidationMissionDestination {
        if let savedTuneID {
            return .savedTune(savedTuneID, kind)
        }
        return .catalog(game)
    }

    var detail: String {
        guard let carDisplayName else {
            return game == .fh5
                ? "Choose a reviewed FH5 catalog car and save its local plan."
                : "Choose a reviewed FH6 catalog car and save its generated tune."
        }
        let setup = disciplineTitle.map { "\(carDisplayName) · \($0)" } ?? carDisplayName
        switch kind {
        case .recordFH5Research:
            return "\(setup): capture the untouched stock tuning menu as raw evidence."
        case .runFH5Experiment:
            return isExperimentalCandidateTrial
                ? "\(setup): test one generated hypothesis from replicated menu evidence using a fixed A-B-B-A protocol. This is not a tune."
                : "\(setup): compare stock with one slider step using a fixed A-B-B-A test."
        case .verifyTireRanges:
            return "\(setup): confirm exact stock tire-pressure bounds and game build."
        case .verifyUpgradeParts:
            return "\(setup): confirm every tuning-control part offered by the stock car."
        case .recordTestDrive:
            return "\(setup): record one controlled first-party validation session."
        case .startFH5Plan, .startFH6Tune:
            return setup
        }
    }
}

struct BetaValidationProgress: Equatable, Sendable {
    let savedSetupCount: Int
    let evidenceRecordCount: Int
    let exactUpgradePathSetupCount: Int
    let availableMissionCount: Int
}

struct BetaValidationProgressShare: Equatable, Sendable {
    let subject: String
    let text: String
}

struct BetaValidationMissionBoard: Equatable, Sendable {
    let missions: [BetaValidationMission]
    let progress: BetaValidationProgress

    var progressShare: BetaValidationProgressShare {
        BetaValidationProgressShareFactory().make(progress: progress)
    }
}

struct BetaValidationSetupFacts: Equatable, Sendable {
    let savedTuneID: UUID
    let game: ForzaGame
    let carDisplayName: String
    let disciplineTitle: String
    let canRecordFH5Research: Bool
    let canRunFH5Experiment: Bool
    let canVerifyTireRanges: Bool
    let canVerifyUpgradeParts: Bool
    let canRecordTestDrive: Bool
    let evidenceRecordCount: Int
    let hasExactUpgradePaths: Bool
    let fh5CandidateTrialAvailable: Bool

    init(
        savedTuneID: UUID,
        game: ForzaGame,
        carDisplayName: String,
        disciplineTitle: String,
        canRecordFH5Research: Bool,
        canRunFH5Experiment: Bool,
        canVerifyTireRanges: Bool,
        canVerifyUpgradeParts: Bool,
        canRecordTestDrive: Bool,
        evidenceRecordCount: Int,
        hasExactUpgradePaths: Bool,
        fh5CandidateTrialAvailable: Bool = false
    ) {
        self.savedTuneID = savedTuneID
        self.game = game
        self.carDisplayName = carDisplayName
        self.disciplineTitle = disciplineTitle
        self.canRecordFH5Research = canRecordFH5Research
        self.canRunFH5Experiment = canRunFH5Experiment
        self.canVerifyTireRanges = canVerifyTireRanges
        self.canVerifyUpgradeParts = canVerifyUpgradeParts
        self.canRecordTestDrive = canRecordTestDrive
        self.evidenceRecordCount = evidenceRecordCount
        self.hasExactUpgradePaths = hasExactUpgradePaths
        self.fh5CandidateTrialAvailable =
            fh5CandidateTrialAvailable
    }
}

struct BetaValidationMissionPlanner {
    @MainActor
    func makeBoard(savedTunes: [SavedTune]) -> BetaValidationMissionBoard {
        makeBoard(setups: savedTunes.compactMap(setupFacts))
    }

    func makeBoard(setups: [BetaValidationSetupFacts]) -> BetaValidationMissionBoard {
        var missions: [BetaValidationMission] = []
        let games = Set(setups.map(\.game))
        if !games.contains(.fh5) {
            missions.append(starterMission(game: .fh5))
        }
        if !games.contains(.fh6) {
            missions.append(starterMission(game: .fh6))
        }

        for setup in setups {
            if setup.canRecordFH5Research {
                missions.append(mission(.recordFH5Research, setup: setup))
            }
            if setup.canRunFH5Experiment {
                missions.append(mission(.runFH5Experiment, setup: setup))
            }
            if setup.canVerifyTireRanges {
                missions.append(mission(.verifyTireRanges, setup: setup))
            }
            if setup.canVerifyUpgradeParts {
                missions.append(mission(.verifyUpgradeParts, setup: setup))
            }
            if setup.canRecordTestDrive {
                missions.append(mission(.recordTestDrive, setup: setup))
            }
        }
        missions.sort(by: missionPrecedes)

        return BetaValidationMissionBoard(
            missions: missions,
            progress: BetaValidationProgress(
                savedSetupCount: setups.count,
                evidenceRecordCount: setups.reduce(0) { $0 + $1.evidenceRecordCount },
                exactUpgradePathSetupCount: setups.filter(\.hasExactUpgradePaths).count,
                availableMissionCount: missions.count
            )
        )
    }

    @MainActor
    private func setupFacts(_ savedTune: SavedTune) -> BetaValidationSetupFacts? {
        guard let stored = savedTune.tuneResult,
              savedTune.id == stored.id else {
            return nil
        }
        let tune = TuneResultBoundarySanitizer().sanitize(stored)
        guard tune.request.car.isValid,
              tune.projectionReport != nil,
              (tune.request.car.game == .fh5 && tune.purpose == .fh5BuildPlan)
                || (tune.request.car.game == .fh6 && tune.purpose == .numericTune) else {
            return nil
        }

        guard let evidence = try? savedTune.betaValidationEvidenceSnapshot(
            matching: tune
        ) else {
            return nil
        }
        let researchEligible: Bool
        if tune.request.car.game == .fh5,
           evidence.fh5ResearchObservationCount == 0 {
            researchEligible = FH5ResearchEligibility().snapshot(
                for: tune,
                savedTune: tune,
                isStreaming: false
            ).isSuccess
        } else {
            researchEligible = false
        }
        let validationEligible: Bool
        if tune.request.car.game == .fh6,
           evidence.validationRecordCount == 0 {
            validationEligible = FirstPartyValidationRecordFactory().eligibility(
                for: tune,
                savedTune: tune,
                isStreaming: false
            ).isSuccess
        } else {
            validationEligible = false
        }
        let experimentEligibility: (eligible: Bool, candidate: Bool)
        if tune.request.car.game == .fh5,
           evidence.fh5ControlledExperimentCount == 0 {
            let researchRecords = savedTune
                .fh5ResearchObservationRecords(matching: tune)
            let eligible = FH5ControlledExperimentFactory().eligibility(
                tune: tune,
                savedTune: tune,
                isStreaming: false,
                researchRecords: researchRecords
            ).isSuccess
            let reviewInputs = savedTune
                .fh5ResearchReviewEntries(matching: tune)
                .map { FH5ResearchReviewInput(entry: $0) }
            let candidate = (try? FH5CandidateTrialCoordinator().generate(
                tune: tune,
                savedTune: tune,
                isStreaming: false,
                researchRecords: researchRecords,
                reviewInputs: reviewInputs,
                input: .controller,
                surface: .dry
            )) != nil
            experimentEligibility = (eligible, candidate)
        } else {
            experimentEligibility = (false, false)
        }

        return BetaValidationSetupFacts(
            savedTuneID: savedTune.id,
            game: tune.request.car.game,
            carDisplayName: tune.request.car.displayName,
            disciplineTitle: tune.request.discipline.title,
            canRecordFH5Research: researchEligible,
            canRunFH5Experiment: experimentEligibility.eligible,
            canVerifyTireRanges:
                TirePressureCaptureEligibility().snapshot(for: tune) != nil,
            canVerifyUpgradeParts:
                UpgradePartCaptureEligibility().snapshot(for: tune) != nil,
            canRecordTestDrive: validationEligible,
            evidenceRecordCount: evidence.totalRecordCount,
            hasExactUpgradePaths:
                !TuneControlUpgradePlanner().paths(for: tune).isEmpty,
            fh5CandidateTrialAvailable:
                experimentEligibility.candidate
        )
    }

    private func starterMission(game: ForzaGame) -> BetaValidationMission {
        BetaValidationMission(
            kind: game == .fh5 ? .startFH5Plan : .startFH6Tune,
            game: game,
            savedTuneID: nil,
            carDisplayName: nil,
            disciplineTitle: nil
        )
    }

    private func mission(
        _ kind: BetaValidationMissionKind,
        setup: BetaValidationSetupFacts
    ) -> BetaValidationMission {
        BetaValidationMission(
            kind: kind,
            game: setup.game,
            savedTuneID: setup.savedTuneID,
            carDisplayName: setup.carDisplayName,
            disciplineTitle: setup.disciplineTitle,
            isExperimentalCandidateTrial:
                kind == .runFH5Experiment
                    && setup.fh5CandidateTrialAvailable
        )
    }

    private func missionPrecedes(
        _ lhs: BetaValidationMission,
        _ rhs: BetaValidationMission
    ) -> Bool {
        if lhs.kind.priority != rhs.kind.priority {
            return lhs.kind.priority < rhs.kind.priority
        }
        if lhs.game.rawValue != rhs.game.rawValue {
            return lhs.game.rawValue < rhs.game.rawValue
        }
        let lhsName = lhs.carDisplayName ?? ""
        let rhsName = rhs.carDisplayName ?? ""
        if lhsName != rhsName {
            return lhsName < rhsName
        }
        if lhs.disciplineTitle != rhs.disciplineTitle {
            return (lhs.disciplineTitle ?? "") < (rhs.disciplineTitle ?? "")
        }
        return lhs.id < rhs.id
    }
}

struct BetaValidationProgressShareFactory {
    func make(progress: BetaValidationProgress) -> BetaValidationProgressShare {
        BetaValidationProgressShare(
            subject: "ForzAdvisor Beta Validation Progress",
            text: """
            ForzAdvisor Beta Validation Progress

            Saved setups: \(progress.savedSetupCount)
            Permission-bound evidence records: \(progress.evidenceRecordCount)
            Setups with exact upgrade paths: \(progress.exactUpgradePathSetupCount)
            Validation missions ready: \(progress.availableMissionCount)

            I am helping validate ForzAdvisor with local, first-party testing.
            This progress summary contains no car names, tune values, notes, identifiers, screenshots, or analytics.

            Learn more:
            https://Sankofa06.github.io/ForzAdvisor/
            """
        )
    }
}

private extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
