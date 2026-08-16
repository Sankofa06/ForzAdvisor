//
//  ValidationMissionSummary.swift
//  forzadvisor
//
//  Groups optional validation work by saved setup without ranking users.
//

import Foundation

struct GroupedValidationMission: Equatable, Sendable {
    let mission: BetaValidationMission
    let isRecommended: Bool

    var kind: BetaValidationMissionKind { mission.kind }
    var isOptional: Bool { true }
}

struct GroupedValidationMissionSummary:
    Equatable,
    Identifiable,
    Sendable {
    let savedTuneID: UUID
    let carDisplayName: String
    let disciplineTitle: String?
    let evidence: TuneEvidenceSummary
    let missions: [GroupedValidationMission]

    var id: UUID { savedTuneID }

    var recommendedMission: BetaValidationMission? {
        missions.first(where: \.isRecommended)?.mission
    }

    static func make(
        missions: [BetaValidationMission],
        evidenceBySavedTuneID: [UUID: TuneEvidenceSummary]
    ) -> [Self] {
        let setupMissions = missions.compactMap { mission in
            mission.savedTuneID.map { ($0, mission) }
        }
        let grouped = Dictionary(grouping: setupMissions, by: \.0)

        return grouped.compactMap { savedTuneID, entries in
            guard let first = entries.first else { return nil }
            let missions = entries.map(\.1)
            let evidence: TuneEvidenceSummary
            if let supplied = evidenceBySavedTuneID[savedTuneID],
               supplied.savedTuneID == savedTuneID,
               supplied.isValid {
                evidence = supplied
            } else {
                evidence = .empty(savedTuneID: savedTuneID)
            }
            return Self(
                savedTuneID: savedTuneID,
                carDisplayName: first.1.carDisplayName ?? "Saved setup",
                disciplineTitle: first.1.disciplineTitle,
                evidence: evidence,
                missions: missions.enumerated().map { index, mission in
                    GroupedValidationMission(
                        mission: mission,
                        isRecommended: index == 0
                    )
                }
            )
        }
        .sorted { lhs, rhs in
            if lhs.carDisplayName != rhs.carDisplayName {
                return lhs.carDisplayName < rhs.carDisplayName
            }
            if lhs.disciplineTitle != rhs.disciplineTitle {
                return (lhs.disciplineTitle ?? "")
                    < (rhs.disciplineTitle ?? "")
            }
            return lhs.savedTuneID.uuidString
                < rhs.savedTuneID.uuidString
        }
    }
}
