//
//  Root workflow actions split by bounded ownership.
//

import Foundation
import SwiftData

extension ContentView {
    func eligibleTireCaptureSnapshot(
        for tune: TuneResult
    ) -> VehicleBuildSnapshot? {
        TirePressureCaptureEligibility().snapshot(for: tune)
    }

    func eligibleFH6TuneMenuCaptureSnapshot(
        for tune: TuneResult
    ) -> VehicleBuildSnapshot? {
        FH6TuneMenuCaptureEligibility().snapshot(for: tune)
    }

    func eligibleUpgradeCaptureSnapshot(for tune: TuneResult) -> VehicleBuildSnapshot? {
        UpgradePartCaptureEligibility().snapshot(for: tune)
    }

    func applyFH6TuneMenuCapture(
        _ capture: FH6TuneMenuCapture,
        to tune: TuneResult,
        savedTuneID: UUID?,
        thumbnailData: Data?,
        playerNotes: String
    ) {
        guard let snapshot = eligibleFH6TuneMenuCaptureSnapshot(for: tune) else {
            errorMessage = "This tune is no longer eligible for exact FH6 menu verification."
            return
        }

        do {
            let exactSnapshot = try capture.exactBuildSnapshot(upgrading: snapshot)
            generateTune(
                for: tune.request.car,
                discipline: tune.request.discipline,
                origin: .manual(tune.request.car),
                thumbnailData: thumbnailData,
                saveTo: savedTuneID,
                playerNotes: playerNotes,
                preserving: exactSnapshot
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applyTirePressureCapture(
        _ capture: TirePressureCapture,
        to tune: TuneResult,
        savedTuneID: UUID?,
        thumbnailData: Data?,
        playerNotes: String
    ) {
        guard let snapshot = eligibleTireCaptureSnapshot(for: tune) else {
            errorMessage = "This tune is no longer eligible for stock tire verification."
            return
        }

        do {
            let exactSnapshot = try capture.exactBuildSnapshot(upgrading: snapshot)
            generateTune(
                for: tune.request.car,
                discipline: tune.request.discipline,
                origin: .manual(tune.request.car),
                thumbnailData: thumbnailData,
                saveTo: savedTuneID,
                playerNotes: playerNotes,
                preserving: exactSnapshot
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applyUpgradePartCapture(
        _ capture: UpgradePartCapture,
        to tune: TuneResult,
        savedTuneID: UUID?,
        thumbnailData: Data?,
        playerNotes: String
    ) {
        guard let snapshot = eligibleUpgradeCaptureSnapshot(for: tune) else {
            errorMessage = "This tune is no longer eligible for stock upgrade verification."
            return
        }

        do {
            let verifiedSnapshot = try capture.verifiedSnapshot(upgrading: snapshot)
            generateTune(
                for: tune.request.car,
                discipline: tune.request.discipline,
                origin: .manual(tune.request.car),
                thumbnailData: thumbnailData,
                saveTo: savedTuneID,
                playerNotes: playerNotes,
                preserving: verifiedSnapshot
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

}
