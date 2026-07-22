//
//  FH6LocalTirePressureQuantizer.swift
//  forzadvisor
//
//  Adapts deterministic FH6 formula candidates to a user-observed tire slider
//  step. This is intentionally applied only by LocalSampleTuneProvider.
//

import Foundation

enum FH6LocalTirePressureRuleset {
    static let id = "forzadvisor.fh6.local-tire-pressure-quantization"
    static let schemaVersion = 1
    static let algorithmVersion = "1.0.0"
    static let knowledgeRevision = "tire-pressure-capture-v1"

    static func reference(provenanceIDs: [String]) -> TuneRulesetReference? {
        TuneRulesetReference(descriptor: TuneRulesetDescriptor(
            id: id,
            game: .fh6,
            schemaVersion: schemaVersion,
            algorithmVersion: algorithmVersion,
            knowledgeRevision: knowledgeRevision,
            validationStatus: .experimental,
            provenanceIDs: provenanceIDs
        ))
    }
}

struct FH6LocalTirePressureQuantizer {
    func quantize(_ candidate: TuneResult) -> TuneResult {
        guard candidate.request.car.game == .fh6,
              let snapshot = candidate.request.buildSnapshot,
              snapshot.kind == .exactBuildObservation,
              snapshot.isValid,
              snapshot.matches(car: candidate.request.car) else {
            return candidate
        }

        var result = candidate
        var rulesetEvidenceIDs = Set<String>()
        result.sections = candidate.sections.map { section in
            var section = section
            section.lines = section.lines.map { line in
                guard let field = line.fieldID,
                      field == .frontTirePressure || field == .rearTirePressure,
                      let rawValue = LocalizedNumberText.parse(line.value),
                      let constraint = snapshot.constraints.first(where: { $0.field == field }),
                      let evidenceIDs = acceptedEvidenceIDs(
                          for: constraint,
                          in: snapshot
                      ),
                      let quantized = quantizedValue(rawValue, using: constraint) else {
                    return line
                }

                rulesetEvidenceIDs.formUnion(evidenceIDs)
                var line = line
                line.value = LocalizedNumberText.format(
                    quantized,
                    fractionDigits: fractionDigits(for: constraint.step)
                )
                let capturedDetail = "Rounded to the captured in-game tire-pressure step."
                line.detail = [line.detail, capturedDetail]
                    .compactMap { $0 }
                    .joined(separator: " ")
                return line
            }
            return section
        }

        if let reference = FH6LocalTirePressureRuleset.reference(
            provenanceIDs: rulesetEvidenceIDs.sorted()
        ) {
            result.rulesetReference = reference
        }
        return result
    }

    private func acceptedEvidenceIDs(
        for constraint: TuneFieldConstraint,
        in snapshot: VehicleBuildSnapshot
    ) -> [String]? {
        guard !constraint.evidenceIDs.isEmpty else { return nil }
        let evidenceByID = Dictionary(uniqueKeysWithValues: snapshot.evidenceSources.map { ($0.id, $0) })
        let evidence = constraint.evidenceIDs.compactMap { evidenceByID[$0] }
        guard evidence.count == constraint.evidenceIDs.count,
              evidence.allSatisfy({ item in
                  item.game == .fh6
                      && item.gameBuildVersion == snapshot.gameBuild.version
                      && item.scope == .exactVehicleBuild
                      && item.source == TirePressureCapture.provenanceSource
                      && item.version == TirePressureCapture.provenanceVersion
                      && item.confidence != .low
                      && item.usagePermission == .permitted
              }) else {
            return nil
        }
        return constraint.evidenceIDs
    }

    private func quantizedValue(
        _ candidate: Double,
        using constraint: TuneFieldConstraint
    ) -> Double? {
        guard constraint.scope == .exactVehicleBuild,
              constraint.verification == .productionEligible,
              constraint.unit == .psi,
              constraint.validationIssues.isEmpty,
              candidate.isFinite,
              candidate >= constraint.minimum,
              candidate <= constraint.maximum else {
            return nil
        }

        let stepIndex = ((candidate - constraint.minimum) / constraint.step)
            .rounded(.toNearestOrAwayFromZero)
        let quantized = constraint.minimum + (stepIndex * constraint.step)
        guard constraint.accepts(quantized) else { return nil }
        return quantized
    }

    private func fractionDigits(for step: Double) -> Int {
        for digits in 0...6 {
            let scale = pow(10.0, Double(digits))
            let scaledStep = step * scale
            if abs(scaledStep - scaledStep.rounded()) <= 1e-8 {
                return digits
            }
        }
        return 6
    }
}
