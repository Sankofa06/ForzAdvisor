//
//  ForzaOCRKnowledgeBase+Draft.swift
//  forzadvisor
//
//  Applies parsed OCR candidates to confirmation drafts and records evidence
//  used by the review screen.
//

import Foundation

extension ForzaOCRKnowledgeBase {
    func applyBestIntegerCandidate(
        field: OCRInputField,
        to draft: inout OCRConfirmationDraft,
        candidates: [ParsedCandidate<Int>],
        assign: (inout OCRConfirmationDraft, Int) -> Void
    ) {
        guard let best = bestCandidate(candidates) else { return }
        assign(&draft, best.value)
        draft.evidence[field] = evidence(from: best)
        draft.fieldCandidates[field] = candidates.map { fieldCandidate(field: field, from: $0) }
    }

    func applyBestDoubleCandidate(
        field: OCRInputField,
        to draft: inout OCRConfirmationDraft,
        candidates: [ParsedCandidate<Double>],
        assign: (inout OCRConfirmationDraft, Double) -> Void
    ) {
        guard let best = bestCandidate(candidates) else { return }
        assign(&draft, best.value)
        draft.evidence[field] = evidence(from: best)
        draft.fieldCandidates[field] = candidates.map { fieldCandidate(field: field, from: $0) }
    }

    func applyBestClassCandidate(
        to draft: inout OCRConfirmationDraft,
        candidates: [ParsedCandidate<PerformanceClass>]
    ) {
        guard let best = bestCandidate(candidates) else { return }
        draft.performanceClass = best.value
        draft.evidence[.performanceClass] = evidence(from: best)
        draft.fieldCandidates[.performanceClass] = candidates.map { fieldCandidate(field: .performanceClass, from: $0) }
    }

    func applyBestDrivetrainCandidate(
        to draft: inout OCRConfirmationDraft,
        candidates: [ParsedCandidate<Drivetrain>]
    ) {
        guard let best = bestCandidate(candidates) else { return }
        draft.drivetrain = best.value
        draft.evidence[.drivetrain] = evidence(from: best)
        draft.fieldCandidates[.drivetrain] = candidates.map { fieldCandidate(field: .drivetrain, from: $0) }
    }

    func bestCandidate<Value>(_ candidates: [ParsedCandidate<Value>]) -> ParsedCandidate<Value>? {
        candidates.max { lhs, rhs in
            if abs(lhs.confidence - rhs.confidence) > 0.001 {
                return lhs.confidence < rhs.confidence
            }
            return lhs.rawText.count > rhs.rawText.count
        }
    }

    func evidence<Value>(from candidate: ParsedCandidate<Value>) -> OCRFieldEvidence {
        OCRFieldEvidence(
            rawText: candidate.rawText,
            confidence: candidate.confidence,
            candidates: candidate.candidates,
            boundingBox: candidate.boundingBox
        )
    }

    func fieldCandidate<Value>(
        field: OCRInputField,
        from candidate: ParsedCandidate<Value>
    ) -> OCRFieldCandidate {
        OCRFieldCandidate(
            field: field,
            value: candidate.textValue,
            confidence: candidate.confidence,
            rawText: candidate.rawText
        )
    }
}
